defmodule IElixir.Kernel.Session do
  @moduledoc """
  This module provides genserver that handles current shell session.
  It stores current kernel encryption so is able to compute signatures.
  Also it handles current session's key.
  """

  require Logger
  use GenServer

  alias IElixir.Kernel.History
  alias IElixir.Runtime

  @doc """
  Start the session server

    IElixir.Kernel.Session.start_link(%{"signature_scheme" => "hmac-sha256", "key" => "7534565f-e742-40f3-85b4-bf4e5f35390a"})

  ## Options

  "signature_scheme" and "key" options are required for proper work of HMAC server.
  """
  @spec start_link(map) :: GenServer.on_start()
  def start_link(conn_info) do
    GenServer.start_link(__MODULE__, conn_info, name: __MODULE__)
  end

  def init(conn_info) do
    # TODO make default runtime selectable

    {:ok, runtime} = Runtime.ElixirStandalone.init()
    Runtime.connect(runtime)

    init_state = %{
      session_id: History.get_session(),
      runtime: runtime,
      evaluating_cells: %{},
      completing_cells: %{},
      execution_count: 0
    }

    case String.split(conn_info["signature_scheme"], "-") do
      ["hmac", tail] ->
        {:ok,
         Map.merge(init_state, %{
           signature_data: {String.to_atom(tail), conn_info["key"]}
         })}

      ["", _] ->
        {:ok,
         Map.merge(init_state, %{
           signature_data: {nil, ""}
         })}

      scheme ->
        Logger.error("Invalid signature_scheme: #{inspect(scheme)}")
        {:error, "Invalid signature_scheme"}
    end
  rescue
    e ->
      IO.inspect(e)
      IO.inspect(__STACKTRACE__)
      reraise(e, __STACKTRACE__)
  end

  @doc """
  Compute signature for provided message.
  Each argument must be valid UTF-8 string, because it is JSON decodable.

  ### Example

      iex> IElixir.HMAC.compute_signature("", "", "", "")
      "25eb8ea448d87f384f43c96960600c2ce1e713a364739674a6801585ae627958"

  """
  @spec compute_signature(String.t(), String.t(), String.t(), String.t()) :: String.t()
  def compute_signature(header_raw, parent_header_raw, metadata_raw, content_raw) do
    GenServer.call(
      __MODULE__,
      {:compute_sig, [header_raw, parent_header_raw, metadata_raw, content_raw]}
    )
  end

  @spec get_session :: String.t()
  def get_session() do
    GenServer.call(__MODULE__, :get_session)
  end

  @spec increase_counter :: :ok
  def increase_counter() do
    GenServer.cast(__MODULE__, :increase_counter)
  end

  @spec get_counter :: Integer.t()
  def get_counter() do
    GenServer.call(__MODULE__, :get_counter)
  end

  def execute_request(cell, content) do
    GenServer.call(__MODULE__, {:execute_request, cell, content}, :infinity)
  end

  def complete_request(cell, content) do
    GenServer.call(__MODULE__, {:complete_request, cell, content}, :infinity)
  end

  def handle_call(
        {:complete_request, cell, content},
        from,
        %{completing_cells: completing_cells, runtime: runtime} = state
      ) do
    cursor = content["cursor_pos"]
    code = content["code"]
    Runtime.handle_completion(runtime, code, cursor, cell)

    completing_cells = Map.put(completing_cells, cell, {from, %{code: code, cursor: cursor}})
    {:noreply, %{state | completing_cells: completing_cells}}
  end

  def handle_call(
        {:execute_request, cell, content},
        from,
        %{evaluating_cells: evaluating_cells, runtime: runtime} = state
      ) do
    Runtime.evaluate_code(runtime, content["code"], cell, nil)
    evaluating_cells = Map.put(evaluating_cells, cell, {from, %{}})
    {:noreply, %{state | evaluating_cells: evaluating_cells}}
  end

  def handle_call(:get_session, _from, %{session_id: session} = state) do
    {:reply, session, state}
  end

  def handle_call(:get_counter, _from, %{execution_count: execution_count} = state) do
    {:reply, execution_count, state}
  end

  def handle_call({:compute_sig, _parts}, _from, %{signature_data: {_, ""}} = state) do
    {:reply, "", state}
  end

  def handle_call({:compute_sig, parts}, _from, %{signature_data: {algo, key}} = state) do
    {:reply, IElixir.Util.Crypto.compute_signature(algo, key, parts), state}
  end

  def handle_cast(:increase_counter, state) do
    {:noreply, Map.update(state, :execution_count, 0, &(&1 + 1))}
  end

  def handle_info({:evalutaion_output, cell, data}, %{evaluating_cells: evaluating_cells} = state) do
    evaluating_cells =
      Map.update!(evaluating_cells, cell, fn {from, cell_data} ->
        cell_data = Map.update(cell_data, :output, &[data | &1], [data])
        {from, cell_data}
      end)

    {:noreply, %{state | evaluating_cells: evaluating_cells}}
  end

  def handle_info(
        {:evaluation_response, cell, data, metadata},
        %{evaluating_cells: evaluating_cells} = state
      ) do
    {{from, cell_state}, evaluating_cells} = Map.pop(evaluating_cells, cell)

    cell_state =
      cell_state
      |> Map.put(:response, data)
      |> Map.put(:response_metadata, metadata)

    GenServer.reply(from, cell_state)

    {:noreply, %{state | evaluating_cells: evaluating_cells}}
  end

  def handle_info(
        {:completion_response, cell, matches, _cursor_start, _cursor_end},
        %{completing_cells: completing_cells} = state
      ) do
    {{from, cell_state}, completing_cells} = Map.pop(completing_cells, cell)

    cursor_start = IElixir.Util.Substring.calculate_substring_position(cell_state.code, matches)
    cursor = cell_state.cursor

    cell_state =
      cell_state
      |> Map.put(:matches, matches)
      |> Map.put(:cursor_start, cursor_start)
      |> Map.put(:cursor_end, cursor)

    GenServer.reply(from, cell_state)

    {:noreply, %{state | completing_cells: completing_cells}}
  end

  def handle_info({:log, level, message}, state) do
    Logger.log(level, message)
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("Missed message: #{inspect(msg)}")
    {:noreply, state}
  end
end
