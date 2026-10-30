defmodule Explorer.Chain.BlockNumberHelper do
  @moduledoc """
  Provides helper functions for navigating block numbers in a blockchain.
  """

  alias EthereumJSONRPC.Utility.RangesHelper

  @doc """
    Returns the previous block number in the blockchain sequence (the number decremented by one).
  """
  @spec previous_block_number(non_neg_integer()) :: non_neg_integer()
  def previous_block_number(number), do: move_by_one(number, :previous)

  @doc """
    Returns the next block number in the blockchain sequence (the number incremented by one).
  """
  @spec next_block_number(non_neg_integer()) :: non_neg_integer()
  def next_block_number(number), do: move_by_one(number, :next)

  @doc """
    Moves block number by one in the specified direction.

    When moving backward from the configured minimum possible blockchain block number
    (set in :indexer, :block_ranges), returns that minimum block number to maintain
    the lower boundary. Callers implementing block traversal loops must explicitly check
    for the minimum block number to prevent infinite loops, as moving backward from the
    minimum block will continuously return the same number.

    ## Parameters
    - `number`: The block number to move from
    - `direction`: Either `:previous` or `:next` to indicate movement direction

    ## Returns
    - For `:next`: The next block number (number + 1)
    - For `:previous`: The previous block number (number - 1), or the configured minimum
      possible block number if current block is at the minimum block

    ## Examples

        iex> move_by_one(5, :next)
        6

        iex> move_by_one(5, :previous)
        4

        # Assuming first_block is configured as 0
        iex> move_by_one(0, :previous)
        0  # Returns configured minimum possible block number
  """
  @spec move_by_one(non_neg_integer(), :previous | :next) :: non_neg_integer()
  def move_by_one(number, direction) do
    min_block = RangesHelper.get_min_block_number_from_range_string(Application.get_env(:indexer, :block_ranges))

    case {number, direction} do
      {n, :previous} when n <= min_block -> min_block
      {_, :previous} -> number - 1
      {_, :next} -> number + 1
    end
  end
end
