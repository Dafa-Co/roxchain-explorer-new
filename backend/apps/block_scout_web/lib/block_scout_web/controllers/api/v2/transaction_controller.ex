defmodule BlockScoutWeb.API.V2.TransactionController do
  use BlockScoutWeb, :controller

  use OpenApiSpex.ControllerSpecs

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      next_page_params: 4,
      token_transfers_next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1,
      fetch_scam_token_toggle: 2,
      transaction_to_internal_transactions: 2
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      paging_options: 2,
      filter_options: 2,
      method_filter_options: 1,
      token_transfers_types_options: 1,
      type_filter_options: 1
    ]

  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1, maybe_preload_ens_to_transaction: 1]

  import Explorer.MicroserviceInterfaces.Metadata,
    only: [maybe_preload_metadata: 1, maybe_preload_metadata_to_transaction: 1]

  import Explorer.Chain.Address.Reputation, only: [reputation_association: 0]

  require Logger

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation, as: TransactionInterpretationService
  alias BlockScoutWeb.Models.TransactionStateHelper
  alias BlockScoutWeb.Schemas.API.V2.ErrorResponses.{ForbiddenResponse, NotFoundResponse}
  alias Explorer.Account.WatchlistAddress
  alias Explorer.Chain
  alias Explorer.Chain.Cache.Counters.{NewPendingTransactionsCount, Transactions24hCount}
  alias Explorer.Chain.{Hash, Transaction}
  alias Explorer.Chain.Token.Instance
  alias Indexer.Fetcher.OnDemand.FirstTrace, as: FirstTraceOnDemand

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["transactions"])

  @chain_type_transaction_necessity_by_association %{}

  # TODO might be redundant to preload blob fields in some of the endpoints
  @transaction_necessity_by_association %{
                                          :block => :optional,
                                          [
                                            created_contract_address: [
                                              :scam_badge,
                                              :names,
                                              :token,
                                              :smart_contract,
                                              proxy_implementations_association()
                                            ]
                                          ] => :optional,
                                          [
                                            from_address: [
                                              :scam_badge,
                                              :names,
                                              :smart_contract,
                                              proxy_implementations_association()
                                            ]
                                          ] => :optional,
                                          [
                                            to_address: [
                                              :scam_badge,
                                              :names,
                                              :smart_contract,
                                              proxy_implementations_association()
                                            ]
                                          ] => :optional
                                        }
                                        |> Map.merge(@chain_type_transaction_necessity_by_association)

  @token_transfers_necessity_by_association %{
    [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
    [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
    [token: reputation_association()] => :optional
  }

  @token_transfers_in_transaction_necessity_by_association %{
    [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
    [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
    [token: reputation_association()] => :optional
  }

  @internal_transaction_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] =>
        :optional,
      [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
      [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional
    }
  ]

  @api_true [api?: true]

  operation(:transaction,
    summary: "Retrieve detailed information about a specific transaction",
    description: "Retrieves detailed information for a specific transaction identified by its hash.",
    parameters: [transaction_hash_param() | base_params()],
    responses: [
      ok: {"Detailed information about the specified transaction.", "application/json", Schemas.Transaction.Response},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]
  )

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param` endpoint.
  """
  @spec transaction(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def transaction(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    necessity_by_association_with_actions =
      @transaction_necessity_by_association
      |> Map.put(:transaction_actions, :optional)
      |> Map.put(:signed_authorizations, :optional)

    necessity_by_association =
      necessity_by_association_with_actions

    options =
      [necessity_by_association: necessity_by_association]
      |> Keyword.merge(@api_true)

    with {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params, options),
         preloaded <-
           Chain.preload_token_transfers(
             transaction,
             @token_transfers_in_transaction_necessity_by_association,
             @api_true |> fetch_scam_token_toggle(conn)
           ) do
      conn
      |> put_status(200)
      |> render(:transaction, %{
        transaction:
          preloaded
          |> Instance.preload_nft(@api_true)
          |> maybe_preload_ens_to_transaction()
          |> maybe_preload_metadata_to_transaction()
      })
    end
  end

  operation(:transactions,
    summary: "List blockchain transactions with filtering options for status, type, and method",
    description: "Retrieves a paginated list of transactions with optional filtering by status, type, and method.",
    parameters:
      base_params() ++
        [transaction_filter_param(), transaction_type_param()] ++
        define_paging_params(["block_number", "index", "items_count", "hash", "inserted_at"]),
    responses: [
      ok:
        {"List of transactions with pagination information.", "application/json",
         paginated_response(
           items: Schemas.Transaction.Response,
           next_page_params_example: %{
             "block_number" => 23_532_302,
             "index" => 375,
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]
  )

  @doc """
    Function to handle GET requests to `/api/v2/transactions` endpoint.
  """
  @spec transactions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transactions(conn, params) do
    filter_options = filter_options(params, :validated)

    full_options =
      [
        necessity_by_association: @transaction_necessity_by_association
      ]
      |> Keyword.merge(paging_options(params, filter_options))
      |> Keyword.merge(method_filter_options(params))
      |> Keyword.merge(type_filter_options(params))
      |> Keyword.merge(@api_true)

    transactions_plus_one = Chain.recent_transactions(full_options, filter_options)

    {transactions, next_page} = split_list_by_page(transactions_plus_one)

    next_page_params = next_page |> next_page_params(transactions, params)

    conn
    |> put_status(200)
    |> render(:transactions, %{
      transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
      next_page_params: next_page_params
    })
  end

  operation(:raw_trace,
    summary: "Get step-by-step execution trace for a specific transaction",
    description:
      "Retrieves the raw execution trace for a transaction, showing the step-by-step execution path and all contract interactions.",
    parameters: [transaction_hash_param() | base_params()],
    responses: [
      ok: {"Raw execution trace for the specified transaction.", "application/json", Schemas.Transaction.RawTrace},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]
  )

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/raw-trace` endpoint.
  """
  @spec raw_trace(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def raw_trace(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    with {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      if is_nil(transaction.block_number) do
        conn
        |> put_status(200)
        |> render(:raw_trace, %{internal_transactions: []})
      else
        FirstTraceOnDemand.maybe_trigger_fetch(transaction, @api_true)

        case Chain.fetch_transaction_raw_traces(transaction) do
          {:ok, raw_traces} ->
            conn
            |> put_status(200)
            |> render(:raw_trace, %{raw_traces: raw_traces})

          {:error, error} ->
            Logger.error("Raw trace fetching failed: #{inspect(error)}")
            {500, "Error while raw trace fetching"}
        end
      end
    end
  end

  operation(:token_transfers,
    summary: "List token transfers within a specific transaction",
    description:
      "Retrieves token transfers that occurred within a specific transaction, with optional filtering by token type.",
    parameters:
      base_params() ++
        [transaction_hash_param(), token_type_param()] ++
        define_paging_params([
          "index",
          "block_number",
          "batch_log_index",
          "batch_block_hash",
          "batch_transaction_hash",
          "index_in_batch"
        ]),
    responses: [
      ok:
        {"Token transfers within the specified transaction, with pagination.", "application/json",
         paginated_response(
           items: Schemas.TokenTransfer,
           next_page_params_example: %{
             "index" => 442,
             "block_number" => 21_307_214
           }
         )},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]
  )

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/token-transfers` endpoint.
  """
  @spec token_transfers(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def token_transfers(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    with {:ok, _transaction, transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      paging_options = paging_options(params)

      full_options =
        [necessity_by_association: @token_transfers_necessity_by_association]
        |> Keyword.merge(paging_options)
        |> Keyword.merge(token_transfers_types_options(params))
        |> Keyword.merge(@api_true)
        |> fetch_scam_token_toggle(conn)

      results =
        transaction_hash
        |> Chain.transaction_to_token_transfers(full_options)
        |> Chain.flat_1155_batch_token_transfers()
        |> Chain.paginate_1155_batch_token_transfers(paging_options)

      {token_transfers, next_page} = split_list_by_page(results)

      next_page_params =
        next_page
        |> token_transfers_next_page_params(token_transfers, params)

      conn
      |> put_status(200)
      |> render(:token_transfers, %{
        token_transfers:
          token_transfers |> Instance.preload_nft(@api_true) |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  operation(:internal_transactions,
    summary: "List internal transactions triggered during a specific transaction",
    description:
      "Retrieves internal transactions generated during the execution of a specific transaction. Useful for analyzing contract interactions and debugging failed transactions.",
    parameters:
      [transaction_hash_param() | base_params()] ++
        define_paging_params(["index", "block_number", "transaction_index", "items_count"]),
    responses: [
      ok:
        {"Internal transactions for the specified transaction, with pagination.", "application/json",
         paginated_response(
           items: Schemas.InternalTransaction,
           next_page_params_example: %{
             "index" => 50,
             "block_number" => 22_133_247,
             "transaction_index" => 68,
             "items_count" => 50
           }
         )},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]
  )

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/internal-transactions` endpoint.
  """
  @spec internal_transactions(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def internal_transactions(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    with {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      full_options =
        @internal_transaction_necessity_by_association
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(@api_true)

      internal_transactions_plus_one = transaction_to_internal_transactions(transaction, full_options)

      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      next_page_params =
        next_page
        |> next_page_params(internal_transactions, params)

      conn
      |> put_status(200)
      |> render(:internal_transactions, %{
        internal_transactions: internal_transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  operation(:logs,
    summary: "List event logs emitted during a specific transaction",
    description:
      "Retrieves event logs emitted during the execution of a specific transaction. Logs contain information about contract events and state changes.",
    parameters:
      [transaction_hash_param() | base_params()] ++
        define_paging_params(["index", "block_number", "items_count"]),
    responses: [
      ok:
        {"Event logs for the specified transaction, with pagination.", "application/json",
         paginated_response(
           items: Schemas.Log,
           next_page_params_example: %{
             "index" => 124,
             "block_number" => 21_925_703,
             "items_count" => 50
           }
         )},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]
  )

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/logs` endpoint.
  """
  @spec logs(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def logs(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    with {:ok, _transaction, transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      full_options =
        [
          necessity_by_association: %{
            [address: [:names, :smart_contract, proxy_implementations_smart_contracts_association()]] => :optional,
            :block => :optional
          }
        ]
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(@api_true)

      logs_plus_one = Chain.transaction_to_logs(transaction_hash, full_options)

      {logs, next_page} = split_list_by_page(logs_plus_one)

      next_page_params =
        next_page
        |> next_page_params(logs, params)

      conn
      |> put_status(200)
      |> render(:logs, %{
        transaction_hash: transaction_hash,
        logs: logs |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  operation(:state_changes,
    summary: "Get on-chain state changes caused by a specific transaction",
    description: "Retrieves state changes (balance changes, token transfers) caused by a specific transaction.",
    parameters:
      [transaction_hash_param() | base_params()] ++ define_state_changes_paging_params(["state_changes", "items_count"]),
    responses: [
      ok: {
        "State changes caused by the specified transaction, with pagination.",
        "application/json",
        paginated_response(
          items: Schemas.Transaction.StateChange,
          next_page_params_example: %{
            "state_changes" => nil,
            "items_count" => 50
          }
        )
      },
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]
  )

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/state-changes` endpoint.
  """
  @spec state_changes(Plug.Conn.t(), map()) :: Plug.Conn.t() | {atom(), any()}
  def state_changes(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    with {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params) do
      state_changes_plus_next_page =
        transaction
        |> TransactionStateHelper.state_changes(
          params
          |> paging_options()
          |> Keyword.merge(@api_true)
          |> Keyword.put(:ip, AccessHelper.conn_to_ip_string(conn))
        )

      {state_changes, next_page} = split_list_by_page(state_changes_plus_next_page)

      next_page_params =
        next_page
        |> next_page_params(state_changes, params, true)

      conn
      |> put_status(200)
      |> render(:state_changes, %{state_changes: state_changes, next_page_params: next_page_params})
    end
  end

  operation(:watchlist_transactions,
    summary: "List transactions in a user's watchlist",
    description: "Retrieves transactions in the authenticated user's watchlist.",
    parameters: base_params() ++ define_paging_params(["block_number", "index", "items_count"]),
    responses: [
      ok:
        {"Watchlist transactions.", "application/json",
         paginated_response(
           items: Schemas.Transaction.Response,
           next_page_params_example: %{
             "block_number" => 23_617_990,
             "index" => 128,
             "items_count" => 50
           }
         )},
      forbidden: ForbiddenResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]
  )

  @doc """
    Function to handle GET requests to `/api/v2/transactions/watchlist` endpoint.
  """
  @spec watchlist_transactions(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:auth, any()}
  def watchlist_transactions(conn, params) do
    with {:auth, %{watchlist_id: watchlist_id}} <- {:auth, current_user(conn)} do
      full_options =
        [
          necessity_by_association: @transaction_necessity_by_association
        ]
        |> Keyword.merge(paging_options(params, [:validated]))
        |> Keyword.merge(@api_true)

      {watchlist_names, transactions_plus_one} =
        WatchlistAddress.fetch_watchlist_transactions(watchlist_id, full_options)

      {transactions, next_page} = split_list_by_page(transactions_plus_one)

      next_page_params = next_page |> next_page_params(transactions, params)

      conn
      |> put_status(200)
      |> render(:transactions_watchlist, %{
        transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params,
        watchlist_names: watchlist_names
      })
    end
  end

  operation(:summary,
    summary: "Get a human-readable, LLM-based transaction summary",
    description: "Retrieves a human-readable summary of what a transaction did, presented in natural language.",
    parameters: base_params() ++ [transaction_hash_param(), just_request_body_param()],
    responses: [
      ok:
        {"Human-readable summary of the specified transaction.", "application/json",
         %Schema{
           anyOf: [
             Schemas.Transaction.Summary,
             Schemas.Transaction.SummaryJustRequestBody
           ]
         }},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]
  )

  @doc """
    Function to handle GET requests to `/api/v2/transactions/:transaction_hash_param/summary` endpoint.
  """
  @spec summary(Plug.Conn.t(), map()) ::
          {:format, :error}
          | {:not_found, {:error, :not_found}}
          | {:restricted_access, true}
          | {:transaction_interpreter_enabled, boolean}
          | Plug.Conn.t()
  def summary(conn, %{transaction_hash_param: transaction_hash_string, just_request_body: true} = params) do
    options =
      [
        necessity_by_association: %{
          [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
          [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional
        }
      ]
      |> Keyword.merge(@api_true)

    with {:transaction_interpreter_enabled, true} <-
           {:transaction_interpreter_enabled, TransactionInterpretationService.enabled?()},
         {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params, options) do
      conn
      |> json(TransactionInterpretationService.get_request_body(transaction))
    end
  end

  def summary(conn, %{transaction_hash_param: transaction_hash_string} = params) do
    options =
      [
        necessity_by_association: %{
          [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
          [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional
        }
      ]
      |> Keyword.merge(@api_true)

    with {:transaction_interpreter_enabled, true} <-
           {:transaction_interpreter_enabled, TransactionInterpretationService.enabled?()},
         {:ok, transaction, _transaction_hash} <- validate_transaction(transaction_hash_string, params, options) do
      {response, code} =
        case TransactionInterpretationService.interpret(transaction) do
          {:ok, response} -> {response, 200}
          {:error, %Jason.DecodeError{}} -> {%{error: "Error while transaction interpreter response decoding"}, 500}
          {{:error, error}, code} -> {%{error: error}, code}
        end

      conn
      |> put_status(code)
      |> json(response)
    end
  end

  operation(:stats,
    summary: "Get transaction statistics",
    description: "Retrieves statistics for transactions, including counts and fee summaries for the last 24 hours.",
    responses: [
      ok:
        {"Transaction statistics.", "application/json",
         %Schema{
           type: :object,
           properties: %{
             transactions_count_24h: Schemas.General.IntegerString,
             pending_transactions_count: Schemas.General.IntegerString,
             transaction_fees_sum_24h: Schemas.General.IntegerString,
             transaction_fees_avg_24h: Schemas.General.IntegerString
           },
           required: [
             :transactions_count_24h,
             :pending_transactions_count,
             :transaction_fees_sum_24h,
             :transaction_fees_avg_24h
           ],
           additionalProperties: false
         }},
      unprocessable_entity: JsonErrorResponse.response()
    ]
  )

  @doc """
  Function to handle GET requests to `/api/v2/transactions/stats` endpoint.
  """
  @spec stats(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def stats(conn, _params) do
    transactions_count = Transactions24hCount.fetch_count(@api_true)
    pending_transactions_count = NewPendingTransactionsCount.fetch(@api_true)
    transaction_fees_sum = Transactions24hCount.fetch_fee_sum(@api_true)
    transaction_fees_avg = Transactions24hCount.fetch_fee_average(@api_true)

    conn
    |> put_status(200)
    |> render(
      :stats,
      %{
        transactions_count_24h: transactions_count,
        pending_transactions_count: pending_transactions_count,
        transaction_fees_sum_24h: transaction_fees_sum,
        transaction_fees_avg_24h: transaction_fees_avg
      }
    )
  end

  @doc """
  Checks if this valid transaction hash string, and this transaction doesn't belong to prohibited address
  """
  @spec validate_transaction(String.t(), any(), Keyword.t()) ::
          {:format, :error}
          | {:not_found, {:error, :not_found}}
          | {:restricted_access, true}
          | {:ok, Transaction.t(), Hash.t()}
  def validate_transaction(transaction_hash_string, params, options \\ @api_true) do
    with {:format, {:ok, transaction_hash}} <- {:format, Chain.string_to_full_hash(transaction_hash_string)},
         {:not_found, {:ok, transaction}} <-
           {:not_found, Chain.hash_to_transaction(transaction_hash, options)},
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.from_address_hash), params),
         {:ok, false} <- AccessHelper.restricted_access?(to_string(transaction.to_address_hash), params) do
      {:ok, transaction, transaction_hash}
    end
  end
end
