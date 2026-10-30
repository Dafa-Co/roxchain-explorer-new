defmodule BlockScoutWeb.Schemas.API.V2.Block.Common do
  @moduledoc """
  This module defines common schema fields for block.
  """
  alias BlockScoutWeb.Schemas.API.V2.{Address, General}
  alias OpenApiSpex.Schema

  @required_fields [
    :height,
    :timestamp,
    :transactions_count,
    :internal_transactions_count,
    :miner,
    :size,
    :hash,
    :parent_hash,
    :difficulty,
    :total_difficulty,
    :gas_used,
    :gas_limit,
    :nonce,
    :base_fee_per_gas,
    :burnt_fees,
    :priority_fee,
    :uncles_hashes,
    :rewards,
    :gas_target_percentage,
    :gas_used_percentage,
    :burnt_fees_percentage,
    :type,
    :transaction_fees,
    :withdrawals_count,
    :is_pending_update
  ]

  @rewards_schema %Schema{
    type: :array,
    items: %Schema{
      type: :object,
      properties: %{
        address_hash: General.AddressHash,
        reward: General.IntegerString,
        type: %Schema{type: :string, nullable: false}
      },
      required: [:type, :reward],
      additionalProperties: false
    },
    nullable: false
  }

  @doc """
    Returns the common rewards schema for block.
  """
  @spec rewards_schema() :: Schema.t()
  def rewards_schema, do: @rewards_schema

  @doc """
    Returns the list of required fields for the block schema.
  """
  @spec required_fields() :: [atom()]
  def required_fields, do: @required_fields

  @doc """
    Returns the common schema for block.
  """
  @spec schema() :: map()
  def schema do
    %{
      type: :object,
      properties: %{
        height: %Schema{type: :integer, nullable: false, minimum: 0},
        timestamp: General.Timestamp,
        transactions_count: %Schema{type: :integer, nullable: false},
        internal_transactions_count: %Schema{type: :integer, nullable: true},
        miner: Address,
        size: %Schema{type: :integer, nullable: false},
        hash: General.FullHash,
        parent_hash: General.FullHash,
        difficulty: General.IntegerStringNullable,
        total_difficulty: General.IntegerStringNullable,
        gas_used: General.IntegerString,
        gas_limit: General.IntegerString,
        nonce: General.HexStringNullable,
        base_fee_per_gas: General.IntegerStringNullable,
        burnt_fees: General.IntegerStringNullable,
        priority_fee: General.IntegerStringNullable,
        uncles_hashes: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{hash: General.FullHash},
            required: [:hash],
            nullable: false,
            additionalProperties: false
          },
          nullable: false
        },
        rewards: @rewards_schema,
        gas_target_percentage: %Schema{type: :number, format: :float, nullable: false},
        gas_used_percentage: %Schema{type: :number, format: :float, nullable: false},
        burnt_fees_percentage: %Schema{type: :number, format: :float, nullable: true},
        type: %Schema{type: :string, nullable: false, enum: ["block", "uncle", "reorg"]},
        transaction_fees: General.IntegerString,
        withdrawals_count: %Schema{type: :integer, minimum: 0, nullable: true},
        is_pending_update: %Schema{type: :boolean, nullable: false}
      },
      required: required_fields(),
      additionalProperties: false
    }
  end
end

defmodule BlockScoutWeb.Schemas.API.V2.Block do
  @moduledoc """
  This module defines the schema for the Block struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Block.Common

  OpenApiSpex.schema(Common.schema())
end
