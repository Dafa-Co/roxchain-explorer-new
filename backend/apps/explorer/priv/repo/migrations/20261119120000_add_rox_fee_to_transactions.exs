defmodule Explorer.Repo.Migrations.AddRoxFeeToTransactions do
  @moduledoc """
  RoxChain: the fixed fee each transaction paid under the genesis "roxFixedFee" rule of the RoxChain
  Besu node (receipt fields roxFee, roxFeePayer), and the account it was taken from.
  Nullable, no defaults: adding them does not rewrite the table.
  """
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add_if_not_exists(:rox_fee, :numeric, precision: 100, null: true)
      add_if_not_exists(:rox_fee_payer_hash, :bytea, null: true)
    end
  end
end
