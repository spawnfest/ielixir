defmodule IElixir.Kernel.Supervisor do
  use Supervisor

  alias IElixir.Kernel
  alias IElixir.Kernel.Channels

  alias IElixir.Kernel.Socket.Config, as: SocketConfig

  def start_link(connection_data) do
    Supervisor.start_link(__MODULE__, connection_data, name: __MODULE__)
  end

  @impl true
  def init(connection_data) do
    channel_starting_args = %SocketConfig{
      connection_data: connection_data
    }

    children = [
      # Starting supporting services
      {Kernel.History, %{db_path: db_path(), connection_data: connection_data}},
      {Kernel.Session, connection_data},

      # Starting channels
      {Channels.Hb, channel_starting_args},
      {Channels.IOPub, channel_starting_args},
      {Channels.StdIn, channel_starting_args},
      {Channels.Shell, channel_starting_args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Function calculates db path for installation.
  The path is located is users home director, following the convention from IPython
  """
  def db_path do
    System.user_home!()
    |> Path.join(".ielixir")
    |> Path.join("history")
  end
end
