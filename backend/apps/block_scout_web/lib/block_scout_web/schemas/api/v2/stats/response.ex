defmodule BlockScoutWeb.Schemas.API.V2.Stats.Response do
  @moduledoc """
  This module defines the schema for response from /api/v2/stats.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%Schema{
    type: :object,
    title: "StatsResponse",
    description: "Stats response",
    properties: %{
      average_block_time: %Schema{type: :number, format: :float},
      coin_image: %Schema{type: :string, nullable: true},
      coin_price: General.FloatStringNullable,
      coin_price_change_percentage: %Schema{type: :number, format: :float, nullable: true},
      gas_price_updated_at: General.TimestampNullable,
      gas_prices: %Schema{type: :object, nullable: true},
      gas_prices_update_in: %Schema{type: :integer, nullable: true},
      gas_used_today: %Schema{anyOf: [General.IntegerStringNullable, %Schema{type: :integer}]},
      market_cap: General.FloatString,
      network_utilization_percentage: %Schema{type: :number, nullable: true},
      secondary_coin_image: %Schema{type: :string, nullable: true},
      secondary_coin_price: General.FloatStringNullable,
      static_gas_price: General.IntegerStringNullable,
      total_addresses: General.IntegerString,
      total_blocks: General.IntegerString,
      total_gas_used: General.IntegerString,
      total_transactions: General.IntegerString,
      transactions_today: General.IntegerString,
      tvl: General.IntegerStringNullable
    }
  })
end
