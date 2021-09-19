defmodule IElixir.Runtime.ErlDist do
  @moduledoc false

  # This module allows for initializing nodes connected using
  # Erlang Distribution with modules and processes necessary for evaluation.
  #
  # To ensure proper isolation between sessions,
  # code evaluation may take place in a separate Elixir runtime,
  # which also makes it easy to terminate the whole
  # evaluation environment without stopping IElixir.
  # This is what `Runtime.ElixirStandalone`, `Runtime.MixStandalone`
  # and `Runtime.Attached` do, so this module contains the shared
  # functionality they need.
  #
  # To work with a separate node, we have to inject the necessary
  # IElixir modules there and also start the relevant processes
  # related to evaluation. Fortunately Erlang allows us to send modules
  # binary representation to the other node and load them dynamically.
  #
  # For further details see `IElixir.Runtime.ErlDist.NodeManager`.

  # Modules to load into the connected node.
  @required_modules [
    IElixir.Evaluator,
    IElixir.Evaluator.IOProxy,
    IElixir.Display,
    IElixir.Displayable,
    IElixir.Displayable.Any,
    IElixir.Completion,
    IElixir.Completion.IdentifierMatcher,
    IElixir.Runtime.ErlDist,
    IElixir.Runtime.ErlDist.NodeManager,
    IElixir.Runtime.ErlDist.RuntimeServer,
    IElixir.Runtime.ErlDist.EvaluatorSupervisor,
    IElixir.Runtime.ErlDist.IOForwardGL,
    IElixir.Runtime.ErlDist.LoggerGLBackend
  ]

  @doc """
  Starts a runtime server on the given node.

  If necessary, the required modules are loaded
  into the given node and the node manager process
  is started with `node_manager_opts`.
  """
  @spec initialize(node(), keyword()) :: pid()
  def initialize(node, node_manager_opts \\ []) do
    unless modules_loaded?(node) do
      load_required_modules(node)
    end

    unless node_manager_started?(node) do
      start_node_manager(node, node_manager_opts)
    end

    start_runtime_server(node)
  end

  defp load_required_modules(node) do
    for module <- @required_modules do
      {_module, binary, filename} = :code.get_object_code(module)

      case :rpc.call(node, :code, :load_binary, [module, filename, binary]) do
        {:module, _} ->
          :ok

        {:error, reason} ->
          local_otp = :erlang.system_info(:otp_release)
          remote_otp = :rpc.call(node, :erlang, :system_info, [:otp_release])

          if local_otp != remote_otp do
            raise RuntimeError,
                  "failed to load #{inspect(module)} module into the remote node, potentially due to Erlang/OTP version mismatch, reason: #{inspect(reason)} (local #{local_otp} != remote #{remote_otp})"
          else
            raise RuntimeError,
                  "failed to load #{inspect(module)} module into the remote node, reason: #{inspect(reason)}"
          end
      end
    end
  end

  defp start_node_manager(node, opts) do
    :rpc.call(node, IElixir.Runtime.ErlDist.NodeManager, :start, [opts])
  end

  defp start_runtime_server(node) do
    IElixir.Runtime.ErlDist.NodeManager.start_runtime_server(node)
  end

  defp modules_loaded?(node) do
    :rpc.call(node, Code, :ensure_loaded?, [IElixir.Runtime.ErlDist.NodeManager])
  end

  defp node_manager_started?(node) do
    case :rpc.call(node, Process, :whereis, [IElixir.Runtime.ErlDist.NodeManager]) do
      nil -> false
      _pid -> true
    end
  end

  @doc """
  Unloads the previously loaded IElixir modules from the caller node.
  """
  def unload_required_modules() do
    for module <- @required_modules do
      # If we attached, detached and attached again, there may still
      # be deleted module code, so purge it first.
      :code.purge(module)
      :code.delete(module)
    end
  end
end
