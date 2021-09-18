defmodule IElixir.Kernel.ConnectionFile do
  @moduledoc """
  This module provides operations with kernel connection file.
  It's protocol is defined here:
  https://jupyter-client.readthedocs.io/en/latest/kernels.html#connection-files
  """

  require Logger

  @doc """
  Parse connection file and return map with proper fields.

  ### Example

      iex> conn_info = IElixir.Utils.parse_connection_file("test/test_connection_file"); :ok
      :ok
      iex> conn_info["key"]
      "7534565f-e742-40f3-85b4-bf4e5f35390a"

  """
  @spec parse(String.t()) :: map()
  def parse(connection_file) do
    # Caching contents of the connection file
    connection_file_contents = File.read!(connection_file)

    Logger.debug(fn ->
      "Parsing connection file #{connection_file}:\n#{connection_file_contents}"
    end)

    Jason.decode!(connection_file_contents)
  end

  @doc """
  Function creates connection string that is acceptable for ZMQ client to open a connection

  Params:

  * connection_data - data from parsed connection file
  * channel_name - "control" | "shell" | "stdin" | "hb" | "iopub"
  """
  @spec channel_connection_config(connection_data :: map(), channel_name :: String.t()) ::
          {atom(), list(), integer()}
  def channel_connection_config(connection_data, channel_name) do
    {
      :erlang.binary_to_atom(connection_data["transport"]),
      :erlang.binary_to_list(connection_data["ip"]),
      connection_data["#{channel_name}_port"]
    }
  end
end
