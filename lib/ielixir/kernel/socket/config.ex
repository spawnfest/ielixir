defmodule IElixir.Kernel.Socket.Config do
  @moduledoc false

  defstruct zmq_context: nil,
            connection_data: nil

  @type t() :: %__MODULE__{}
end
