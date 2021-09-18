defmodule IElixir.Kernel.History do
  require Logger

  defmodule Record do
    defstruct [
      :session_id,
      :line,
      :source,
      :source_raw,
      :output
    ]
  end

  alias IElixir.Kernel.History.Record

  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(%{db_path: path}) do
    File.mkdir_p!(path)
    sessions_log = Path.join(path, "sessions.log")

    # This is ID of the current kernel
    session_id =
      :rand.uniform() |> Float.to_string() |> then(&:crypto.hash(:sha, &1)) |> Base.encode16()

    # Index of current session
    session_index =
      with true <- File.exists?(sessions_log),
           value when is_integer(value) <-
             Enum.find_index(File.stream!(sessions_log), &(String.trim(&1) == session_id)) do
        raise "Kernel's id conflict! Restarting kernel to generate new id"
      else
        _ ->
          # Part with appending kernel id to sessions log
          {:ok, file} = File.open(sessions_log, [:append])
          IO.write(file, "#{session_id}\n")
          # Closing file to apply the appendance
          File.close(file)

          # Getting actual id
          File.stream!(sessions_log)
          |> Enum.find_index(&(String.trim(&1) == session_id))
      end

    # Opening the file
    history_log = Path.join(path, "#{session_index}.log")
    {:ok, fd} = File.open(history_log, [:append])

    # Finishing init
    {:ok, %{fd: fd, session_id: session_id, session_index: session_index}}
  end

  def insert(line, source, source_raw, output) do
    GenServer.call(__MODULE__, {:insert, line, source, source_raw, output})
  end

  @spec get_session() :: integer()
  def get_session() do
    GenServer.call(__MODULE__, :get_session)
  end

  def handle_call({:insert, line, source, source_raw, output}, _from, %{fd: fd, session_id: session} = conn) do
    line_to_write =
      %Record{
        session_id: session,
        line: line,
        source: source,
        source_raw: source_raw,
        output: output
      }
      |> :erlang.term_to_binary()
      |> Base.encode64()

    :file.write(fd, line_to_write <> "\n")

    {:reply, :ok, conn}
  end

  def handle_call(:get_session, _from, %{session_id: session_id} = conn) do
    {:reply, session_id, conn}
  end
end
