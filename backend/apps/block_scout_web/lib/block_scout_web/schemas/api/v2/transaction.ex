defmodule BlockScoutWeb.Schemas.API.V2.Transaction do
  @moduledoc """
  This module defines the schema for the Transaction struct.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.{Address, General, SignedAuthorization, TokenTransfer}
  alias BlockScoutWeb.Schemas.API.V2.Transaction.Fee
  alias Explorer.Chain.TransactionAction
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    type: :object,
    properties: %{
      hash: General.FullHash,
      result: %Schema{
        anyOf: [
          %Schema{
            type: :string,
            enum: ["pending", "awaiting_internal_transactions", "success", "dropped/replaced"]
          },
          %Schema{
            type: :string,
            description: "Error message",
            example: "out of gas"
          }
        ],
        nullable: false
      },
      status: %Schema{
        type: :string,
        enum: ["ok", "error"],
        nullable: true
      },
      block_number: %Schema{
        type: :integer,
        nullable: true
      },
      timestamp: General.TimestampNullable,
      from: Address,
      to: Address,
      created_contract: %Schema{allOf: [Address], nullable: true},
      confirmations: %Schema{
        type: :integer,
        minimum: 0
      },
      confirmation_duration: %Schema{
        type: :array,
        items: %Schema{
          type: :integer,
          minimum: 0,
          description: "Duration in milliseconds"
        },
        description:
          "Array of time intervals in milliseconds. Can be empty [] (no info), single value [interval] (means that the transaction was confirmed within {interval} milliseconds), or two values [short_interval, long_interval] (means that the transaction's confirmation took from {short_interval} to {long_interval} milliseconds)",
        example: [1000, 2000],
        maxItems: 2
      },
      value: General.IntegerString,
      fee: Fee,
      gas_price: General.IntegerStringNullable,
      type: %Schema{
        type: :integer,
        nullable: true
      },
      gas_used: General.IntegerStringNullable,
      gas_limit: General.IntegerString,
      max_fee_per_gas: General.IntegerStringNullable,
      max_priority_fee_per_gas: General.IntegerStringNullable,
      base_fee_per_gas: General.IntegerStringNullable,
      priority_fee: General.IntegerStringNullable,
      transaction_burnt_fee: General.IntegerStringNullable,
      nonce: %Schema{
        type: :integer,
        nullable: false,
        minimum: 0
      },
      position: %Schema{
        type: :integer,
        nullable: true,
        minimum: 0
      },
      revert_reason: %Schema{
        oneOf: [
          General.DecodedInput,
          %Schema{
            type: :object,
            properties: %{raw: %Schema{anyOf: [General.HexString, %Schema{type: :string}], nullable: true}},
            required: [:raw],
            nullable: false,
            additionalProperties: false
          }
        ],
        nullable: true
      },
      raw_input: General.HexString,
      decoded_input: %Schema{allOf: [General.DecodedInput], nullable: true},
      token_transfers: %Schema{type: :array, items: TokenTransfer, nullable: true},
      token_transfers_overflow: %Schema{type: :boolean, nullable: true},
      actions: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          required: [:protocol, :type, :data],
          properties: %{
            protocol: %Schema{
              type: :string,
              enum: TransactionAction.supported_protocols(),
              nullable: false
            },
            type: %Schema{
              type: :string,
              enum: TransactionAction.supported_types(),
              nullable: false
            },
            data: %Schema{
              type: :object,
              description: "Transaction action details (json formatted)",
              nullable: false
            }
          },
          additionalProperties: false
        },
        nullable: true
      },
      exchange_rate: General.FloatStringNullable,
      historic_exchange_rate: General.FloatStringNullable,
      method: General.MethodNameNullable,
      transaction_types: %Schema{
        type: :array,
        items: %Schema{
          type: :string,
          enum: [
            "coin_transfer",
            "contract_call",
            "contract_creation",
            "token_creation",
            "token_transfer",
            "blob_transaction",
            "set_code_transaction"
          ]
        }
      },
      transaction_tag: %Schema{
        type: :string,
        nullable: true,
        example: "personal",
        description: "Transaction tag set in My Account"
      },
      has_error_in_internal_transactions: %Schema{type: :boolean, nullable: true},
      authorization_list: %Schema{type: :array, items: SignedAuthorization, nullable: true},
      is_pending_update: %Schema{type: :boolean, nullable: true}
    },
    required: [
      :hash,
      :result,
      :status,
      :block_number,
      :timestamp,
      :from,
      :to,
      :created_contract,
      :confirmations,
      :confirmation_duration,
      :value,
      :fee,
      :gas_price,
      :type,
      :gas_used,
      :gas_limit,
      :max_fee_per_gas,
      :max_priority_fee_per_gas,
      :base_fee_per_gas,
      :priority_fee,
      :transaction_burnt_fee,
      :nonce,
      :position,
      :revert_reason,
      :raw_input,
      :decoded_input,
      :token_transfers,
      :token_transfers_overflow,
      :actions,
      :exchange_rate,
      :historic_exchange_rate,
      :method,
      :transaction_types,
      :transaction_tag,
      :has_error_in_internal_transactions,
      :authorization_list,
      :is_pending_update
    ],
    additionalProperties: false
  })
end
