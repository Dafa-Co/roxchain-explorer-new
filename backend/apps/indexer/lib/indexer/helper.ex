defmodule Indexer.Helper do
  @moduledoc """
  Auxiliary common functions for indexers.
  """

  require Logger

  alias Explorer.Chain.Hash
  alias Explorer.SmartContract.Reader, as: ContractReader

  @doc """
  Checks whether the given Ethereum address looks correct.
  The address should begin with 0x prefix and then contain 40 hexadecimal digits (can be in mixed case).
  This function doesn't check if the address is checksummed.
  """
  @spec address_correct?(binary()) :: boolean()
  def address_correct?(address) when is_binary(address) do
    String.match?(address, ~r/^0x[[:xdigit:]]{40}$/i)
  end

  def address_correct?(_address) do
    false
  end

  @doc """
  Converts Explorer.Chain.Hash representation of the given address to a string
  beginning with 0x prefix. If the given address is already a string, it is not modified.
  The second argument forces the result to be downcased.
  """
  @spec address_hash_to_string(binary(), boolean()) :: binary()
  def address_hash_to_string(hash, downcase \\ false)

  def address_hash_to_string(hash, downcase) when is_binary(hash) do
    if downcase do
      String.downcase(hash)
    else
      hash
    end
  end

  def address_hash_to_string(hash, downcase) do
    if downcase do
      String.downcase(Hash.to_string(hash))
    else
      Hash.to_string(hash)
    end
  end

  @doc """
    Retrieves decoded results of `eth_call` requests to contracts, with retry
    logic for handling errors.

    The function attempts the specified number of retries, with a progressive
    delay between each retry, for each `eth_call` request. If, after all
    retries, some requests remain unsuccessful, it returns a list of unique
    error messages encountered.

    ## Parameters
    - `requests`: A list of `EthereumJSONRPC.Contract.call()` instances
                  describing the parameters for `eth_call`, including the
                  contract address and method selector.
    - `abi`: A list of maps providing the ABI that describes the input
             parameters and output format for the contract functions.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC
                                  connection.
    - `retries_left`: The number of retries allowed for any `eth_call` that
                      returns an error.
    - `log_error?` (optional):  A boolean indicating whether to log error
                               messages on retries. Defaults to `true`.

    ## Returns
    - `{responses, errors}` where:
      - `responses`: A list of tuples `{status, result}`, where `result` is the
                     decoded response from the corresponding `eth_call` if
                     `status` is `:ok`, or the error message if `status` is
                     `:error`.
      - `errors`: A list of error messages, if any element in `responses`
        contains `:error`.
  """
  @spec read_contracts_with_retries(
          [EthereumJSONRPC.Contract.call()],
          [map()],
          EthereumJSONRPC.json_rpc_named_arguments(),
          integer(),
          boolean()
        ) :: {[{:ok | :error, any()}], list()}
  def read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left, log_error? \\ true)
      when is_list(requests) and is_list(abi) and is_integer(retries_left) do
    do_read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left, 0, log_error?)
  end

  defp do_read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left, retries_done, log_error?) do
    responses = ContractReader.query_contracts(requests, abi, json_rpc_named_arguments: json_rpc_named_arguments)

    error_messages =
      Enum.reduce(responses, [], fn {status, error_message}, acc ->
        acc ++
          if status == :error do
            [error_message]
          else
            []
          end
      end)

    retries_left = retries_left - 1

    cond do
      error_messages == [] ->
        {responses, []}

      retries_left <= 0 ->
        if log_error?, do: Logger.error("#{List.first(error_messages)}.")
        {responses, Enum.uniq(error_messages)}

      true ->
        if log_error?, do: Logger.error("#{List.first(error_messages)}. Retrying...")
        pause_before_retry(retries_done)

        do_read_contracts_with_retries(
          requests,
          abi,
          json_rpc_named_arguments,
          retries_left,
          retries_done + 1,
          log_error?
        )
    end
  end

  @doc """
  Converts a log topic from Hash.Full representation to string one.
  """
  @spec log_topic_to_string(any()) :: binary() | nil
  def log_topic_to_string(topic) do
    if is_binary(topic) or is_nil(topic) do
      topic
    else
      Hash.to_string(topic)
    end
  end

  @doc """
  Pauses the process, incrementally increasing the sleep time up to a maximum of 20 minutes.

  ## Parameters
  - `retries_done`: How many retries have already been done.

  ## Returns
  - Nothing.
  """
  @spec pause_before_retry(non_neg_integer()) :: :ok
  def pause_before_retry(retries_done) do
    :timer.sleep(min(3000 * Integer.pow(2, retries_done), 1_200_000))
  end

  @max_queue_size 5000
  @enqueue_busy_waiting_timeout 500
  @doc """
  Reduces the given `data` into an accumulator `acc` using the provided `reducer` function,
  but only if the queue is not full. This function ensures that the processing respects
  the queue's size constraints.

  If the queue is full (i.e., its size is greater than or equal to `@max_queue_size` or
  its `maximum_size`), the function will pause for a duration defined by `@busy_waiting_timeout`
  and retry until the queue has available space.

  ## Parameters

    - `data`: The data to be processed by the `reducer` function.
    - `acc`: The accumulator that will be passed to the `reducer` function.
    - `reducer`: A function that takes `data` and `acc` as arguments and returns the updated accumulator.

  ## Returns

  The result of applying the `reducer` function to the `data` and `acc`.

  ## Notes

  This function uses a recursive approach to wait for the queue to have available space.
  Ensure that the `@busy_waiting_timeout` is set to an appropriate value to avoid excessive delays.
  """
  @spec reduce_if_queue_is_not_full(any(), any(), (any(), any() -> any()), module()) :: any()
  def reduce_if_queue_is_not_full(data, acc, reducer, module) do
    bound_queue = GenServer.call(module, :state).bound_queue

    max_queue_size = Application.get_env(:indexer, module)[:max_queue_size] || @max_queue_size

    enqueue_busy_waiting_timeout =
      Application.get_env(:indexer, module)[:enqueue_busy_waiting_timeout] || @enqueue_busy_waiting_timeout

    if bound_queue.size >= max_queue_size or (bound_queue.maximum_size && bound_queue.size >= bound_queue.maximum_size) do
      :timer.sleep(enqueue_busy_waiting_timeout)

      reduce_if_queue_is_not_full(data, acc, reducer, module)
    else
      reducer.(data, acc)
    end
  end
end
