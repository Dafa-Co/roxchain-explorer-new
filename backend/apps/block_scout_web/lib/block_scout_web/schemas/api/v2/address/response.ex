defmodule BlockScoutWeb.Schemas.API.V2.Address.Response do
  @moduledoc """
  This module defines the schema for address response from /api/v2/addresses/:hash.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General, Token}
  alias BlockScoutWeb.Schemas.Helper
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(
    Address.schema()
    |> Helper.extend_schema(
      title: "AddressResponse",
      description: "Address response",
      properties: %{
        creator_address_hash: General.AddressHashNullable,
        creation_transaction_hash: General.FullHashNullable,
        token: %Schema{allOf: [Token], nullable: true},
        coin_balance: General.IntegerStringNullable,
        exchange_rate: General.FloatStringNullable,
        block_number_balance_updated_at: %Schema{type: :integer, minimum: 0, nullable: true},
        has_validated_blocks: %Schema{type: :boolean, nullable: false},
        has_logs: %Schema{type: :boolean, nullable: false},
        has_tokens: %Schema{type: :boolean, nullable: false},
        has_token_transfers: %Schema{type: :boolean, nullable: false},
        watchlist_address_id: %Schema{type: :integer, nullable: true},
        has_beacon_chain_withdrawals: %Schema{type: :boolean, nullable: false},
        creation_status: %Schema{
          type: :string,
          description: "Creation status of the contract",
          enum: ["success", "failed", "selfdestructed"],
          nullable: true
        }
      },
      required: [
        :creator_address_hash,
        :creation_transaction_hash,
        :token,
        :coin_balance,
        :exchange_rate,
        :block_number_balance_updated_at,
        :has_validated_blocks,
        :has_logs,
        :has_tokens,
        :has_token_transfers,
        :watchlist_address_id,
        :has_beacon_chain_withdrawals,
        :creation_status
      ]
    )
  )
end
