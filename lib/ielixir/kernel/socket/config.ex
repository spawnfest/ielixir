defmodule IElixir.Kernel.Socket.Config do
  defstruct zmq_context: nil,
            connection_data: nil

  @type t() :: %__MODULE__{}
end
