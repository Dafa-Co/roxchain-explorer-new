defmodule BlockScoutWeb.Schemas.API.V2.General.Implementation do
  @moduledoc false
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    description: "Proxy smart contract implementation",
    type: :object,
    properties: %{
      address_hash: General.AddressHash,
      name: %Schema{type: :string, nullable: true}
    },
    required: [:address_hash, :name],
    additionalProperties: false
  })
end
