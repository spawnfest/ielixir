defmodule IElixir.Runtime.ElixirStandalone do
  defstruct [:node, :server_pid]

  # A runtime backed by a standalone Elixir node managed by IElixir.
  #
  # IElixir is responsible for starting and terminating the node.
  # Most importantly we have to make sure the started node doesn't
  # stay in the system when the session or the entire IElixir terminates.

  import IElixir.Runtime.StandaloneInit

  @type t :: %__MODULE__{
          node: node(),
          server_pid: pid()
        }

  @doc """
  Starts a new Elixir node (i.e. a system process) and initializes
  it with IElixir-specific modules and processes.

  If no process calls `Runtime.connect/1` for a period of time,
  the node automatically terminates. Whoever connects, becomes the owner
  and as soon as it terminates, the node terminates as well.
  The node may also be terminated manually by using `Runtime.disconnect/1`.

  Note: to start the node it is required that `elixir` is a recognised
  executable within the system.
  """
  @spec init() :: {:ok, t()} | {:error, String.t()}
  def init() do
    parent_node = node()
    [_, hostname] = String.split("#{parent_node}", "@")
    child_node = :"child@#{hostname}"
    argv = [parent_node]

    with(
      {:ok, elixir_path} <- find_elixir_executable(),
      port = start_elixir_node(elixir_path, child_node, child_node_eval_string(), argv),
      {:ok, server_pid} <- parent_init_sequence(child_node, port)
    )do
      runtime = %__MODULE__{
        node: child_node,
        server_pid: server_pid
      }

      {:ok, runtime}
    end
  end

  defp start_elixir_node(elixir_path, node_name, eval, argv) do
    args = elixir_flags(node_name) ++ ["--eval", eval, "--" | Enum.map(argv, &to_string/1)]

    IO.inspect(args, label: :args)
    IO.inspect(elixir_path, label: :elixir_path)

    Port.open({:spawn_executable, elixir_path}, [:nouse_stdio, :hide, args: args])
    |> IO.inspect(label: :port_spawn_executable)
  end
end

defimpl IElixir.Runtime, for: IElixir.Runtime.ElixirStandalone do
  alias IElixir.Runtime.ErlDist

  def connect(runtime) do
    ErlDist.RuntimeServer.set_owner(runtime.server_pid, self())
    Process.monitor(runtime.server_pid)
  end

  def disconnect(runtime) do
    ErlDist.RuntimeServer.stop(runtime.server_pid)
  end

  def evaluate_code(runtime, code, current_cell, _previous_cell, opts \\ []) do
    ErlDist.RuntimeServer.evaluate_code(runtime.server_pid, code, current_cell, opts)
  end

  def forget_evaluation(runtime, locator) do
    ErlDist.RuntimeServer.forget_evaluation(runtime.server_pid, locator)
  end

  def drop_container(runtime, container_ref) do
    ErlDist.RuntimeServer.drop_container(runtime.server_pid, container_ref)
  end

  def handle_completion(runtime, code, cursor, cell) do
    ErlDist.RuntimeServer.handle_completion(runtime.server_pid, code, cursor, cell)
  end

  def duplicate(_runtime) do
    IElixir.Runtime.ElixirStandalone.init()
  end
end
