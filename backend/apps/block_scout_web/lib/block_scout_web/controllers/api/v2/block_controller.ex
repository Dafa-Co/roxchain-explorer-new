defmodule BlockScoutWeb.API.V2.BlockController do
  use BlockScoutWeb, :controller

  use OpenApiSpex.ControllerSpecs

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      next_page_params: 5,
      paging_options: 1,
      param_to_block_number: 1,
      put_key_value_to_paging_options: 3,
      split_list_by_page: 1,
      parse_block_hash_or_number_param: 1,
      block_to_internal_transactions: 2
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      select_block_type: 1,
      type_filter_options: 1,
      internal_transaction_type_options: 1,
      internal_transaction_call_type_options: 1
    ]

  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1]
  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]

  alias BlockScoutWeb.API.V2.{TransactionView, WithdrawalView}

  alias BlockScoutWeb.Schemas.API.V2.ErrorResponses.NotFoundResponse
  alias Explorer.Chain
  alias Explorer.Chain.{Block, InternalTransaction}
  alias Explorer.Chain.Cache.{BlockNumber, Counters.AverageBlockTime}
  alias Timex.Duration

  (
    @chain_type_transaction_necessity_by_association %{}
    @chain_type_block_necessity_by_association %{}
  )

  @transaction_necessity_by_association [
    necessity_by_association:
      %{
        [created_contract_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] =>
          :optional,
        [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
        [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
        :block => :optional
      }
      |> Map.merge(@chain_type_transaction_necessity_by_association)
  ]

  @internal_transaction_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] =>
        :optional,
      [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
      [to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional
    }
  ]

  @api_true [api?: true]

  @block_params [
    necessity_by_association:
      %{
        [miner: [:names, :smart_contract, proxy_implementations_association()]] => :optional,
        :uncles => :optional,
        :nephews => :optional,
        :rewards => :optional,
        :transactions => :optional,
        :withdrawals => :optional,
        :internal_transactions => :optional
      }
      |> Map.merge(@chain_type_block_necessity_by_association),
    api?: true
  ]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["blocks"])

  operation(:block,
    summary: "Retrieves detailed information for a specific block identified by its number or hash.",
    description:
      "Retrieves detailed information for a specific block, including transactions, internal transactions, and metadata.",
    parameters: [block_hash_or_number_param() | base_params()],
    responses: [
      ok: {"Detailed information about the specified block.", "application/json", Schemas.Block.Response},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]
  )

  @doc """
  Function to handle GET requests to `/api/v2/blocks/:block_hash_or_number_param` endpoint.
  """
  @spec block(Plug.Conn.t(), map()) ::
          {:error, :not_found | {:invalid, :hash | :number}}
          | {:lost_consensus, {:error, :not_found} | {:ok, Explorer.Chain.Block.t()}}
          | Plug.Conn.t()
  def block(conn, %{block_hash_or_number_param: block_hash_or_number}) do
    with {:ok, block} <- block_param_to_block(block_hash_or_number, @block_params) do
      conn
      |> put_status(200)
      |> render(:block, %{block: block})
    end
  end

  defp fetch_block(:hash, hash, params) do
    Chain.hash_to_block(hash, params)
  end

  defp fetch_block(:number, number, params) do
    case Chain.number_to_block(number, params) do
      {:ok, _block} = ok_response ->
        ok_response

      _ ->
        {:lost_consensus, Block.nonconsensus_block_by_number(number, @api_true)}
    end
  end

  operation(:blocks,
    summary: "List blocks with optional filtering by block type",
    description: "Retrieves a paginated list of blocks with optional filtering by block type.",
    parameters:
      base_params() ++
        [block_type_param()] ++
        define_paging_params(["block_number", "items_count"]),
    responses: [
      ok:
        {"List of blocks with pagination information.", "application/json",
         paginated_response(
           items: Schemas.Block,
           next_page_params_example: %{
             "block_number" => 22_566_361,
             "items_count" => 50
           }
         )}
    ]
  )

  @doc """
  Function to handle GET requests to `/api/v2/blocks` endpoint.
  """
  @spec blocks(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def blocks(conn, params) do
    full_options = select_block_type(params)

    blocks_plus_one =
      full_options
      |> Keyword.merge(paging_options(params))
      |> Keyword.merge(@api_true)
      |> Chain.list_blocks()

    {blocks, next_page} = split_list_by_page(blocks_plus_one)

    next_page_params = next_page |> next_page_params(blocks, params)

    conn
    |> put_status(200)
    |> render(:blocks, %{
      blocks: blocks |> maybe_preload_ens() |> maybe_preload_metadata(),
      next_page_params: next_page_params
    })
  end

  operation(:transactions,
    summary: "List transactions and tx details included in a specific block",
    description: "Retrieves transactions included in a specific block, ordered by transaction index.",
    parameters:
      base_params() ++
        [block_hash_or_number_param(), block_transaction_type_param()] ++
        define_paging_params(["block_number", "index", "items_count"]),
    responses: [
      ok:
        {"Transactions in the specified block, with pagination.", "application/json",
         paginated_response(
           items: Schemas.Transaction,
           next_page_params_example: %{
             "block_number" => 12_345_678,
             "index" => 103,
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]
  )

  @doc """
  Function to handle GET requests to `/api/v2/blocks/:block_hash_or_number_param/transactions` endpoint.
  """
  @spec transactions(Plug.Conn.t(), map()) ::
          {:error, :not_found | {:invalid, :hash | :number}}
          | {:lost_consensus, {:error, :not_found} | {:ok, Explorer.Chain.Block.t()}}
          | Plug.Conn.t()
  def transactions(conn, %{block_hash_or_number_param: block_hash_or_number} = params) do
    with {:ok, block} <- block_param_to_block(block_hash_or_number) do
      full_options =
        @transaction_necessity_by_association
        |> Keyword.merge(put_key_value_to_paging_options(paging_options(params), :is_index_in_asc_order, true))
        |> Keyword.merge(type_filter_options(params))
        |> Keyword.merge(@api_true)

      transactions_plus_one = Chain.block_to_transactions(block.hash, full_options, false)

      {transactions, next_page} = split_list_by_page(transactions_plus_one)

      next_page_params =
        next_page
        |> next_page_params(transactions, params)

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:transactions, %{
        transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  operation(:internal_transactions,
    summary: "List internal transactions in a specific block",
    description:
      "Retrieves internal transactions included in a specific block with optional filtering by type and call type.",
    parameters:
      base_params() ++
        [block_hash_or_number_param(), internal_transaction_type_param(), internal_transaction_call_type_param()] ++
        define_paging_params(["transaction_index", "index", "items_count"]),
    responses: [
      ok:
        {"Internal transactions in the specified block.", "application/json",
         paginated_response(
           items: Schemas.InternalTransaction,
           next_page_params_example: %{
             "transaction_index" => 3,
             "index" => 8,
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]
  )

  @doc """
  Function to handle GET requests to `/api/v2/blocks/:block_hash_or_number_param/internal-transactions` endpoint.
  Query params:
   - `type` - Filters internal transactions by type. Possible values: (#{Explorer.Chain.InternalTransaction.Type.values()})
   - `call_type` - Filters internal transactions by call type. Possible values: (#{Explorer.Chain.InternalTransaction.CallType.values()})
  These two filters are mutually exclusive. If both are set, call_type takes priority, and type will be ignored.
  """
  @spec internal_transactions(Plug.Conn.t(), map()) ::
          {:error, :not_found | {:invalid, :hash | :number}}
          | {:lost_consensus, {:error, :not_found} | {:ok, Explorer.Chain.Block.t()}}
          | Plug.Conn.t()
  def internal_transactions(conn, %{block_hash_or_number_param: block_hash_or_number} = params) do
    with {:ok, block} <- block_param_to_block(block_hash_or_number) do
      full_options =
        @internal_transaction_necessity_by_association
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(@api_true)
        |> Keyword.merge(internal_transaction_type_options(params))
        |> Keyword.merge(internal_transaction_call_type_options(params))

      internal_transactions_plus_one = block_to_internal_transactions(block, full_options)

      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      next_page_params =
        next_page
        |> next_page_params(
          internal_transactions,
          params,
          false,
          &InternalTransaction.internal_transaction_to_block_paging_options/1
        )

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:internal_transactions, %{
        internal_transactions: internal_transactions,
        next_page_params: next_page_params,
        block: block
      })
    end
  end

  operation(:withdrawals,
    summary: "List validator withdrawals including amounts, index and receiver details processed in a specific block",
    description: "Retrieves withdrawals processed in a specific block (typically for proof-of-stake networks).",
    parameters:
      base_params() ++
        [block_hash_or_number_param()] ++
        define_paging_params(["index", "items_count"]),
    responses: [
      ok:
        {"Withdrawals in the specified block, with pagination. Note that block_number and timestamp fields are not included in this endpoint.",
         "application/json",
         paginated_response(
           items: Schemas.Withdrawal,
           next_page_params_example: %{
             "index" => 88_192_653,
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]
  )

  @doc """
  Function to handle GET requests to `/api/v2/blocks/:block_hash_or_number_param/withdrawals` endpoint.
  """
  @spec withdrawals(Plug.Conn.t(), map()) ::
          {:error, :not_found | {:invalid, :hash | :number}}
          | {:lost_consensus, {:error, :not_found} | {:ok, Explorer.Chain.Block.t()}}
          | Plug.Conn.t()
  def withdrawals(conn, %{block_hash_or_number_param: block_hash_or_number} = params) do
    with {:ok, block} <- block_param_to_block(block_hash_or_number) do
      full_options =
        [
          necessity_by_association: %{
            [address: [:names, :smart_contract, proxy_implementations_association()]] => :optional
          },
          api?: true
        ]
        |> Keyword.merge(paging_options(params))

      withdrawals_plus_one = Chain.block_to_withdrawals(block.hash, full_options)
      {withdrawals, next_page} = split_list_by_page(withdrawals_plus_one)

      next_page_params = next_page |> next_page_params(withdrawals, params)

      conn
      |> put_status(200)
      |> put_view(WithdrawalView)
      |> render(:withdrawals, %{
        withdrawals: withdrawals |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  operation(:block_countdown,
    summary: "Get countdown information for a target block number",
    description:
      "Calculates the estimated time remaining until a specified block number is reached based on current block and average block time.",
    parameters: [block_number_param() | base_params()],
    responses: [
      ok: {"Block countdown information.", "application/json", Schemas.Block.Countdown},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]
  )

  @doc """
  Function to handle GET requests to `/api/v2/blocks/:block_number_param/countdown` endpoint.
  Calculates the estimated time remaining until a specified block number is reached
  based on the current block number and average block time.

  ## Parameters
  - `conn`: The connection struct
  - `params`: Map containing the target block number

  ## Returns
  - Renders countdown data with current block, target block, remaining blocks, and estimated time
  - Returns appropriate error responses via fallback controller for various failure cases
  """
  @spec block_countdown(Plug.Conn.t(), map()) ::
          Plug.Conn.t()
          | {:format, {:error, :invalid}}
          | {:max_block, nil}
          | {:average_block_time, {:error, :disabled}}
          | {:remaining_blocks, 0}
  def block_countdown(conn, %{block_number_param: block_number}) do
    with {:format, {:ok, target_block_number}} <- {:format, param_to_block_number(block_number)},
         {:max_block, current_block_number} when not is_nil(current_block_number) <-
           {:max_block, BlockNumber.get_max()},
         {:average_block_time, average_block_time} when is_struct(average_block_time) <-
           {:average_block_time, AverageBlockTime.average_block_time()},
         {:remaining_blocks, remaining_blocks} when remaining_blocks > 0 <-
           {:remaining_blocks, target_block_number - current_block_number} do
      estimated_time_in_sec = Float.round(remaining_blocks * Duration.to_seconds(average_block_time), 1)

      render(conn, :block_countdown,
        current_block: current_block_number,
        countdown_block: target_block_number,
        remaining_blocks: remaining_blocks,
        estimated_time_in_sec: estimated_time_in_sec
      )
    end
  end

  defp block_param_to_block(block_hash_or_number, options \\ @api_true) do
    with {:ok, type, value} <- parse_block_hash_or_number_param(block_hash_or_number) do
      fetch_block(type, value, options)
    end
  end
end
