defmodule IElixir.SimpleEvaluator do

  alias IElixir.Evaluator
  
  @doc """
  Starts the evaluator.

  Options:

    * `formatter` - a module implementing the `IElixir.Evaluator.Formatter` behaviour,
      used for transforming evaluation response before it's sent to the client
  """
  def start_link(opts \\ []) do
    case :proc_lib.start_link(__MODULE__, :init, [opts]) do
      {:error, error} -> {:error, error}
      evaluator -> {:ok, evaluator.pid, evaluator}
    end
  end

  def evaluate_code(evaluator, send_to, code, cell, opts \\ []) do
    cast(evaluator, {:evaluate_code, send_to, code, cell, opts})
  end

  def handle_completion(evaluator, send_to, code, cursor, cell) do
    cast(evaluator, {:handle_completion, send_to, code, cursor, cell})
  end

  defp handle_cast({:evaluate_code, send_to, code, cell, opts}, %{context: context} = state) do
    Evaluator.IOProxy.configure(state.io_proxy, send_to, cell)
    file = Keyword.get(opts, :file, "nofile")
    context = put_in(context.env.file, file)
    start_time = System.monotonic_time()

    {context, response} =
      case eval(code, context) do
        {:ok, result, context} ->
          response = {:ok, result}
          {context, response}

        {:error, kind, error, stacktrace} ->
          response = {:error, kind, error, stacktrace}
          {context, response}
      end

    evaluation_time_ms = get_execution_time_delta(start_time)

    Evaluator.IOProxy.flush(state.io_proxy)
    Evaluator.IOProxy.clear_input_buffers(state.io_proxy)

    output = state.formatter.format_response(response)
    metadata = %{evaluation_time_ms: evaluation_time_ms}
    send(send_to, {:evaluation_response, cell, output, metadata})

    {:noreply, %{state | context: context}}
  end

  defp handle_cast({:handle_completion, send_to, code, cursor, cell}, %{context: context} = state) do
    << code :: binary-size(cursor), _ :: binary() >> = code
    # Safely rescue from completion errors
    %{items: items} =
      try do
        IElixir.Completion.handle_request({:completion, code}, context.binding, context.env)
      rescue
        error ->
          send(send_to, {:log, :error, Exception.format(:error, error, __STACKTRACE__)})
      end

    matches = for %{insert_text: text} <- items, do: text
    send(send_to, {:completion_response, cell, matches, cursor, cursor})

    {:noreply, state}
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :temporary
    }
  end

  def init(opts) do
    formatter = Keyword.get(opts, :formatter, Evaluator.IdentityFormatter)

    {:ok, io_proxy} = Evaluator.IOProxy.start_link()

    # Use the dedicated IO device as the group leader,
    # so that it handles all :stdio operations.
    Process.group_leader(self(), io_proxy)

    evaluator_ref = make_ref()
    state = initial_state(evaluator_ref, formatter, io_proxy)
    evaluator = %{pid: self(), ref: evaluator_ref}

    :proc_lib.init_ack(evaluator)

    loop(state)
  end

  defp cast(evaluator, message) do
    send(evaluator.pid, {:cast, evaluator.ref, message})
    :ok
  end

  defp initial_state(evaluator_ref, formatter, io_proxy) do
    %{
      evaluator_ref: evaluator_ref,
      formatter: formatter,
      io_proxy: io_proxy,
      context: initial_context()
    }
  end

  defp initial_context() do
    env = :elixir.env_for_eval([])
    %{binding: [], env: env}
  end

  defp loop(%{evaluator_ref: evaluator_ref} = state) do
    receive do
      # {:call, ^evaluator_ref, pid, ref, message} ->
      #   {:reply, reply, state} = handle_call(message, pid, state)
      #   send(pid, {ref, reply})
      #   loop(state)

      {:cast, ^evaluator_ref, message} ->
        {:noreply, state} = handle_cast(message, state)
        loop(state)
    end
  end

  defp eval(code, %{binding: binding, env: env}) do
    try do
      quoted = Code.string_to_quoted!(code)
      {result, binding, env} = :elixir.eval_quoted(quoted, binding, env)
      {:ok, result, %{binding: binding, env: env}}
    catch
      kind, error ->
        {kind, error, stacktrace} = prepare_error(kind, error, __STACKTRACE__)
        {:error, kind, error, stacktrace}
    end
  end

  defp prepare_error(kind, error, stacktrace) do
    {error, stacktrace} = Exception.blame(kind, error, stacktrace)
    stacktrace = prune_stacktrace(stacktrace)
    {kind, error, stacktrace}
  end

  # Adapted from https://github.com/elixir-lang/elixir/blob/1c1654c88adfdbef38ff07fc30f6fbd34a542c07/lib/iex/lib/iex/evaluator.ex#L355-L372

  @elixir_internals [:elixir, :elixir_expand, :elixir_compiler, :elixir_module] ++
                      [:elixir_clauses, :elixir_lexical, :elixir_def, :elixir_map] ++
                      [:elixir_erl, :elixir_erl_clauses, :elixir_erl_pass]

  defp prune_stacktrace(stacktrace) do
    # The order in which each drop_while is listed is important.
    # For example, the user may call Code.eval_string/2 in their code
    # and if there is an error we should not remove erl_eval
    # and eval_bits information from the user stacktrace.
    stacktrace
    |> Enum.reverse()
    |> Enum.drop_while(&(elem(&1, 0) == :proc_lib))
    |> Enum.drop_while(&(elem(&1, 0) == :gen_server))
    |> Enum.drop_while(&(elem(&1, 0) == __MODULE__))
    |> Enum.drop_while(&(elem(&1, 0) == :elixir))
    |> Enum.drop_while(&(elem(&1, 0) in [:erl_eval, :eval_bits]))
    |> Enum.reverse()
    |> Enum.reject(&(elem(&1, 0) in @elixir_internals))
  end

  defp get_execution_time_delta(started_at) do
    System.monotonic_time()
    |> Kernel.-(started_at)
    |> System.convert_time_unit(:native, :millisecond)
  end
end
