defmodule IElixir.Runtime.ErlDist.RuntimeServer do
  @moduledoc false

  # A server process backing a specific runtime.
  #
  # This process handles `IElixir.Runtime` operations,
  # like evaluation and completion. It spawns/terminates
  # individual evaluators corresponding to evaluation
  # containers as necessary.
  #
  # Every runtime server must have an owner process,
  # to which the server lifetime is bound.
  #
  # For more specification see `IElixir.Runtime`.
  
  require Logger

  use GenServer, restart: :temporary

  alias IElixir.Evaluator
  alias IElixir.Runtime
  alias IElixir.Runtime.ErlDist.EvaluatorSupervisor

  @await_owner_timeout 5_000

  @doc """
  Starts the manager.

  Note: make sure to call `set_owner` within #{@await_owner_timeout}ms
  or the runtime server assumes it's not needed and terminates.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Sets the owner process.

  The owner process is monitored and as soon as it terminates,
  the server also terminates. All the evaluation results are
  send directly to the owner.
  """
  @spec set_owner(pid(), pid()) :: :ok
  def set_owner(pid, owner) do
    GenServer.cast(pid, {:set_owner, owner})
  end

  @doc """
  Evaluates the given code using an `IElixir.Evaluator`
  process belonging to the given container and instructs
  it to send all the outputs to the owner process.

  If no evaluator exists for the given container, a new
  one is started.

  See `IElixir.Evaluator` for more details.
  """
  def evaluate_code(pid, code, cell, opts \\ []) do
    IO.puts("sending evaluate_code")
    GenServer.cast(pid, {:evaluate_code, code, cell, opts})
  end

  @doc """
  Removes the specified evaluation from the history.

  See `IElixir.Evaluator` for more details.
  """
  @spec forget_evaluation(pid(), Runtime.locator()) :: :ok
  def forget_evaluation(pid, locator) do
    GenServer.cast(pid, {:forget_evaluation, locator})
  end

  @doc """
  Terminates the `IElixir.Evaluator` process that belongs
  to the given container.
  """
  @spec drop_container(pid(), Runtime.cell()) :: :ok
  def drop_container(pid, cell) do
    GenServer.cast(pid, {:drop_container, cell})
  end

  def handle_completion(pid, code, cursor, cell) do
    GenServer.cast(pid, {:handle_completion, self(), code, cursor, cell})
  end

  @doc """
  Stops the manager.

  This results in all IElixir-related modules being unloaded
  from the runtime node.
  """
  @spec stop(pid()) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  @impl true
  def init(_opts) do
    Process.send_after(self(), :check_owner, @await_owner_timeout)

    {:ok, evaluator_supervisor} = EvaluatorSupervisor.start_link()
    {:ok, completion_supervisor} = Task.Supervisor.start_link()
    {:ok, evaluator} = EvaluatorSupervisor.start_evaluator(evaluator_supervisor)
    Process.monitor(evaluator.pid)

    {:ok,
     %{
       owner: nil,
       evaluator: evaluator,
       evaluator_supervisor: evaluator_supervisor,
       completion_supervisor: completion_supervisor
     }}
  end

  @impl true
  def handle_info(:check_owner, state) do
    # If not owner has been set within @await_owner_timeout
    # from the start, terminate the process.
    if state.owner do
      {:noreply, state}
    else
      {:stop, :no_owner, state}
    end
  end

  def handle_info({:DOWN, _, :process, owner, _}, %{owner: owner} = state) do
    {:stop, :normal, state}
  end

  def handle_info({:DOWN, _, :process, pid, reason}, %{evaluator_supervisor: evaluator_supervisor} = state) do
    Logger.error("Evaluator #{inspect pid} stopped with #{inspect reason}. Starting new evaluator")
    {:ok, evaluator} = EvaluatorSupervisor.start_evaluator(evaluator_supervisor)
    {:noreply, %{state | evaluator: evaluator}}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def handle_cast({:set_owner, owner}, state) do
    Process.monitor(owner)
    {:noreply, %{state | owner: owner}}
  end

  def handle_cast(
        {:evaluate_code, code, current_cell, opts},
        %{evaluator: evaluator} = state
      ) do
    Evaluator.evaluate_code(
      evaluator,
      state.owner,
      code,
      current_cell,
      opts
    )

    {:noreply, state}
  end

  def handle_cast({:handle_completion, send_to, code, cursor, cell}, %{evaluator: evaluator} = state) do
    Evaluator.handle_completion(evaluator, send_to, code, cursor, cell)
    {:noreply, state}
  end

end
