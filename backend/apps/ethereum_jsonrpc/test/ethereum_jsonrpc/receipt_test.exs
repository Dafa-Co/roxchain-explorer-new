defmodule EthereumJSONRPC.ReceiptTest do
  use ExUnit.Case, async: true

  alias EthereumJSONRPC.Receipt

  doctest Receipt

  describe "to_elixir/1" do
    test "ignores new key" do
      assert Receipt.to_elixir(%{
               "new_key" => "new_value",
               "transactionHash" => "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
             }) == %{
               "transactionHash" => "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
             }
    end

    # Regression test for https://github.com/poanetwork/blockscout/issues/638
    test ~s|"status" => nil is treated the same as no status| do
      assert Receipt.to_elixir(%{"status" => nil, "transactionHash" => "0x0"}) == %{"transactionHash" => "0x0"}
    end
  end

  describe "RoxChain fixed fee (roxFee, roxFeePayer, roxFeeTreasury)" do
    @receipt %{
      "contractAddress" => nil,
      "cumulativeGasUsed" => "0xd4b3",
      "gasUsed" => "0xd4b3",
      "effectiveGasPrice" => "0x0",
      "status" => "0x1",
      "transactionHash" => "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060",
      "transactionIndex" => "0x0"
    }

    test "is decoded and passed on with the fee payer and the treasury" do
      params =
        @receipt
        |> Map.merge(%{
          "roxFee" => "0x9184e72a000",
          "roxFeePayer" => "0x00000000000000000000000000000000000fee01",
          "roxFeeTreasury" => "0x00000000000000000000000000000000000fee02"
        })
        |> Receipt.to_elixir()
        |> Receipt.elixir_to_params()

      assert params.rox_fee == 10_000_000_000_000
      assert params.rox_fee_payer_hash == "0x00000000000000000000000000000000000fee01"
      assert params.rox_fee_treasury_hash == "0x00000000000000000000000000000000000fee02"
      assert params.gas_price == 0
    end

    test "is absent when the node reports none" do
      params = @receipt |> Receipt.to_elixir() |> Receipt.elixir_to_params()

      refute Map.has_key?(params, :rox_fee)
      refute Map.has_key?(params, :rox_fee_payer_hash)
      refute Map.has_key?(params, :rox_fee_treasury_hash)
    end
  end

  test "leaves nil if blockNumber is nil" do
    assert Receipt.to_elixir(%{"blockNumber" => nil, "transactionHash" => "0x0"}) == %{
             "transactionHash" => "0x0",
             "blockNumber" => nil
           }
  end
end
