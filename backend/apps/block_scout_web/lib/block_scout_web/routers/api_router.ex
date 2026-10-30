defmodule RPCTranslatorForwarder do
  @moduledoc """
  Phoenix router limits forwarding,
  so this module is to forward old paths for backward compatibility
  """
  alias BlockScoutWeb.API.RPC.RPCTranslator
  defdelegate init(opts), to: RPCTranslator
  defdelegate call(conn, opts), to: RPCTranslator
end

defmodule BlockScoutWeb.Routers.ApiRouter do
  @moduledoc """
  Router for API
  """
  use BlockScoutWeb, :router

  use Utils.CompileTimeEnvHelper,
    graphql_enabled: [:block_scout_web, [Api.GraphQL, :enabled]],
    graphql_max_complexity: [:block_scout_web, [Api.GraphQL, :max_complexity]],
    graphql_token_limit: [:block_scout_web, [Api.GraphQL, :token_limit]],
    reading_enabled: [:block_scout_web, [__MODULE__, :reading_enabled]],
    writing_enabled: [:block_scout_web, [__MODULE__, :writing_enabled]],
    mud_enabled_compile_time?: [:explorer, [Explorer.Chain.Mud, :enabled]]

  use Utils.RuntimeEnvHelper,
    mud_enabled?: [:explorer, [Explorer.Chain.Mud, :enabled]]

  alias BlockScoutWeb.Routers.{
    AccountRouter,
    AddressBadgesApiV2Router,
    APIKeyV2Router,
    SmartContractsApiV2Router,
    TokensApiV2Router,
    UtilsApiV2Router
  }

  alias BlockScoutWeb.Plug.{CheckApiV2, CheckFeature}

  @max_query_string_length 5_000

  forward("/v2/smart-contracts", SmartContractsApiV2Router)
  forward("/v2/tokens", TokensApiV2Router)

  forward("/v2/key", APIKeyV2Router)
  forward("/v2/utils", UtilsApiV2Router)
  forward("/v2/scam-badge-addresses", AddressBadgesApiV2Router)

  pipeline :api do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      length: 20_000_000,
      query_string_length: @max_query_string_length,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api)
    plug(:accepts, ["json"])
    plug(:fetch_cookies)
  end

  pipeline :api_v2 do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      query_string_length: @max_query_string_length,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api_v2)
    plug(:accepts, ["json"])
    plug(CheckApiV2)
    plug(:fetch_session)
    plug(:protect_from_forgery)
    plug(OpenApiSpex.Plug.PutApiSpec, module: BlockScoutWeb.Specs.Public)
  end

  pipeline :api_v2_no_session do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      query_string_length: @max_query_string_length,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api_v2)
    plug(:accepts, ["json"])
    plug(CheckApiV2)
  end

  pipeline :api_v1_graphql do
    plug(
      Plug.Parsers,
      parsers: [:json, Absinthe.Plug.Parser],
      json_decoder: Poison,
      body_reader: {BlockScoutWeb.GraphQL.BodyReader, :read_body, []}
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api)
    plug(:accepts, ["json"])
    plug(BlockScoutWeb.Plug.GraphQLSchemaIntrospection)
  end

  pipeline :mud do
    plug(CheckFeature, feature_check: &mud_enabled?/0)
  end

  alias BlockScoutWeb.API.V2

  forward("/account", AccountRouter)

  scope "/v2/import" do
    pipe_through(:api_v2_no_session)

    post("/token-info", V2.ImportController, :import_token_info)
    delete("/token-info", V2.ImportController, :delete_token_info)

    get("/smart-contracts/:address_hash_param", V2.ImportController, :try_to_search_contract)
    post("/smart-contracts/:address_hash_param/audit-reports", V2.ImportController, :import_audit_report)
  end

  scope "/v2", as: :api_v2 do
    pipe_through(:api_v2)
    get("/openapi", OpenApiSpex.Plug.RenderSpec, [])

    scope "/search" do
      get("/", V2.SearchController, :search)
      get("/check-redirect", V2.SearchController, :check_redirect)
      get("/quick", V2.SearchController, :quick_search)
    end

    scope "/config" do
      get("/backend", V2.ConfigController, :backend)
      get("/backend-version", V2.ConfigController, :backend_version)
      get("/csv-export", V2.ConfigController, :csv_export)
      get("/indexer", V2.ConfigController, :indexer)
      get("/public-metrics", V2.ConfigController, :public_metrics)
      get("/smart-contracts/languages", V2.ConfigController, :languages_list)
      get("/db-background-migrations", V2.ConfigController, :db_background_migrations)
    end

    scope "/transactions" do
      get("/", V2.TransactionController, :transactions)
      get("/watchlist", V2.TransactionController, :watchlist_transactions)
      get("/stats", V2.TransactionController, :stats)

      get("/:transaction_hash_param", V2.TransactionController, :transaction)
      get("/:transaction_hash_param/token-transfers", V2.TransactionController, :token_transfers)
      get("/:transaction_hash_param/internal-transactions", V2.TransactionController, :internal_transactions)
      get("/:transaction_hash_param/logs", V2.TransactionController, :logs)
      get("/:transaction_hash_param/raw-trace", V2.TransactionController, :raw_trace)
      get("/:transaction_hash_param/state-changes", V2.TransactionController, :state_changes)
      get("/:transaction_hash_param/summary", V2.TransactionController, :summary)
    end

    scope "/token-transfers" do
      get("/", V2.TokenTransferController, :token_transfers)
    end

    scope "/internal-transactions" do
      get("/", V2.InternalTransactionController, :internal_transactions)
    end

    scope "/blocks" do
      get("/", V2.BlockController, :blocks)
      get("/:block_hash_or_number_param", V2.BlockController, :block)
      get("/:block_hash_or_number_param/transactions", V2.BlockController, :transactions)
      get("/:block_hash_or_number_param/internal-transactions", V2.BlockController, :internal_transactions)
      get("/:block_hash_or_number_param/withdrawals", V2.BlockController, :withdrawals)
      get("/:block_number_param/countdown", V2.BlockController, :block_countdown)
    end

    scope "/addresses" do
      get("/", V2.AddressController, :addresses_list)
      get("/:address_hash_param", V2.AddressController, :address)
      get("/:address_hash_param/tabs-counters", V2.AddressController, :tabs_counters)
      get("/:address_hash_param/counters", V2.AddressController, :counters)
      get("/:address_hash_param/token-balances", V2.AddressController, :token_balances)
      get("/:address_hash_param/tokens", V2.AddressController, :tokens)
      get("/:address_hash_param/transactions", V2.AddressController, :transactions)
      get("/:address_hash_param/transactions/csv", V2.CsvExportController, :transactions_csv)
      get("/:address_hash_param/token-transfers", V2.AddressController, :token_transfers)
      get("/:address_hash_param/token-transfers/csv", V2.CsvExportController, :token_transfers_csv)
      get("/:address_hash_param/internal-transactions", V2.AddressController, :internal_transactions)
      get("/:address_hash_param/internal-transactions/csv", V2.CsvExportController, :internal_transactions_csv)
      get("/:address_hash_param/logs", V2.AddressController, :logs)
      get("/:address_hash_param/logs/csv", V2.CsvExportController, :logs_csv)
      get("/:address_hash_param/blocks-validated", V2.AddressController, :blocks_validated)
      get("/:address_hash_param/coin-balance-history", V2.AddressController, :coin_balance_history)
      get("/:address_hash_param/coin-balance-history-by-day", V2.AddressController, :coin_balance_history_by_day)
      get("/:address_hash_param/withdrawals", V2.AddressController, :withdrawals)
      get("/:address_hash_param/nft", V2.AddressController, :nft_list)
      get("/:address_hash_param/nft/collections", V2.AddressController, :nft_collections)
    end

    scope "/main-page" do
      get("/blocks", V2.MainPageController, :blocks)
      get("/transactions", V2.MainPageController, :transactions)
      get("/transactions/watchlist", V2.MainPageController, :watchlist_transactions)
      get("/indexing-status", V2.MainPageController, :indexing_status)
    end

    scope "/stats" do
      get("/", V2.StatsController, :stats)
      get("/hot-smart-contracts", V2.StatsController, :hot_smart_contracts)

      scope "/charts" do
        get("/transactions", V2.StatsController, :transactions_chart)
        get("/market", V2.StatsController, :market_chart)
        get("/secondary-coin-market", V2.StatsController, :secondary_coin_market_chart)
      end
    end

    scope "/withdrawals" do
      get("/", V2.WithdrawalController, :withdrawals_list)
      get("/counters", V2.WithdrawalController, :withdrawals_counters)
    end

    scope "/proxy" do
      scope "/3rdparty" do
        get("/:platform_id", V2.Proxy.UniversalProxyController, :index)

        scope "/noves-fi" do
          get("/transactions/:transaction_hash_param", V2.Proxy.NovesFiController, :transaction)

          get("/addresses/:address_hash_param/transactions", V2.Proxy.NovesFiController, :address_transactions)

          get("/transaction-descriptions", V2.Proxy.NovesFiController, :describe_transactions)
        end

        scope "/xname" do
          get("/addresses/:address_hash_param", V2.Proxy.XnameController, :address)
        end

        scope "/solidityscan" do
          get("/smart-contracts/:address_hash/report", V2.Proxy.SolidityScanController, :solidityscan_report)
        end
      end

      scope "/account-abstraction" do
        get("/operations/:operation_hash_param", V2.Proxy.AccountAbstractionController, :operation)
        get("/operations/:operation_hash_param/summary", V2.Proxy.AccountAbstractionController, :summary)
        get("/bundlers/:address_hash_param", V2.Proxy.AccountAbstractionController, :bundler)
        get("/bundlers", V2.Proxy.AccountAbstractionController, :bundlers)
        get("/factories/:address_hash_param", V2.Proxy.AccountAbstractionController, :factory)
        get("/factories", V2.Proxy.AccountAbstractionController, :factories)
        get("/paymasters/:address_hash_param", V2.Proxy.AccountAbstractionController, :paymaster)
        get("/paymasters", V2.Proxy.AccountAbstractionController, :paymasters)
        get("/accounts/:address_hash_param", V2.Proxy.AccountAbstractionController, :account)
        get("/accounts", V2.Proxy.AccountAbstractionController, :accounts)
        get("/bundles", V2.Proxy.AccountAbstractionController, :bundles)
        get("/operations", V2.Proxy.AccountAbstractionController, :operations)
        get("/status", V2.Proxy.AccountAbstractionController, :status)
      end

      scope "/metadata" do
        get("/addresses", V2.Proxy.MetadataController, :addresses)
      end
    end

    if @mud_enabled_compile_time? do
      scope "/mud" do
        pipe_through(:mud)
        get("/worlds", V2.MudController, :worlds)
        get("/worlds/count", V2.MudController, :worlds_count)
        get("/worlds/:world/tables", V2.MudController, :world_tables)
        get("/worlds/:world/systems", V2.MudController, :world_systems)
        get("/worlds/:world/systems/:system", V2.MudController, :world_system)
        get("/worlds/:world/tables/count", V2.MudController, :world_tables_count)
        get("/worlds/:world/tables/:table_id/records", V2.MudController, :world_table_records)
        get("/worlds/:world/tables/:table_id/records/count", V2.MudController, :world_table_records_count)
        get("/worlds/:world/tables/:table_id/records/:record_id", V2.MudController, :world_table_record)
      end
    end

    scope "/advanced-filters" do
      get("/", V2.AdvancedFilterController, :list)
      get("/csv", V2.AdvancedFilterController, :list_csv)
      get("/methods", V2.AdvancedFilterController, :list_methods)
    end
  end

  scope "/v1/graphql" do
    pipe_through(:api_v1_graphql)

    if @graphql_enabled do
      forward("/", Absinthe.Plug,
        schema: BlockScoutWeb.GraphQL.Schema,
        analyze_complexity: true,
        max_complexity: @graphql_max_complexity,
        token_limit: @graphql_token_limit
      )
    end
  end

  scope "/v1", as: :api_v1 do
    pipe_through(:api)
    alias BlockScoutWeb.API.{EthRPC, RPC, V1}
    alias BlockScoutWeb.API.V1.GasPriceOracleController
    alias BlockScoutWeb.API.V2.SearchController

    # leave the same endpoint in v1 in order to keep backward compatibility
    get("/search", SearchController, :search)

    get("/gas-price-oracle", GasPriceOracleController, :gas_price_oracle)

    if @reading_enabled do
      get("/supply", V1.SupplyController, :supply)
      post("/eth-rpc", EthRPC.EthController, :eth_request)
    end

    if @writing_enabled do
      post("/verified_smart_contracts", V1.VerifiedSmartContractController, :create)
    end

    if @reading_enabled do
      forward("/", RPC.RPCTranslator, %{
        "block" => {RPC.BlockController, []},
        "account" => {RPC.AddressController, []},
        "logs" => {RPC.LogsController, []},
        "token" => {RPC.TokenController, []},
        "stats" => {RPC.StatsController, []},
        "contract" => {RPC.ContractController, [:verify]},
        "transaction" => {RPC.TransactionController, []}
      })
    end
  end

  scope "/health" do
    get("/", BlockScoutWeb.API.HealthController, :health)
    get("/liveness", BlockScoutWeb.API.HealthController, :liveness)
    get("/readiness", BlockScoutWeb.API.HealthController, :readiness)
    get("/multichain-search-export", BlockScoutWeb.API.HealthController, :multichain_search_db_export)
  end

  scope "/v2" do
    pipe_through(:api_v2)

    get("/*path", BlockScoutWeb.API.V2.FallbackController, :unknown_action)
  end

  scope "/" do
    pipe_through(:api)
    alias BlockScoutWeb.API.{EthRPC, RPC}

    if @reading_enabled do
      post("/eth-rpc", EthRPC.EthController, :eth_request)

      forward(
        "/",
        RPCTranslatorForwarder,
        %{
          "block" => {RPC.BlockController, []},
          "account" => {RPC.AddressController, []},
          "logs" => {RPC.LogsController, []},
          "token" => {RPC.TokenController, []},
          "stats" => {RPC.StatsController, []},
          "contract" => {RPC.ContractController, [:verify]},
          "transaction" => {RPC.TransactionController, []}
        }
        |> then(fn options ->
          options
        end)
      )
    end
  end
end
