defmodule IElixir.Kernel.Channels.Shell do
  @moduledoc """
  "Shell: this single ROUTER socket allows multiple incoming connections from
  frontends, and this is the socket where requests for code execution, object
  information, prompts, etc. are made to the kernel by any frontend.
  The communication on this socket is a sequence of request/reply actions from
  each frontend and the kernel."
  From https://ipython.org/ipython-doc/dev/development/messaging.html
  """

  use IElixir.Kernel.Socket.Router, name: "shell"

  alias IElixir.Kernel.Wire
  alias IElixir.Kernel.Wire.Packet
  alias IElixir.Kernel.Wire.Message
  alias IElixir.Kernel.Session

  alias IElixir.Kernel.Channels.IOPub

  @impl true
  @spec handle_packet(packet :: Packet.t(), channel :: Wire.channel()) ::
          Packet.t() | nil | {Packet.t() | nil, (() -> :ok)}
  def handle_packet(
        %Packet{
          uuids: uuids,
          message: %Message{header: %{msg_type: "kernel_info_request"}} = parent_message
        } = packet,
        _channel
      ) do
    Logger.debug("Received kernel_info_request")
    IOPub.busy_notifier(packet).()

    {
      %Packet{
        uuids: uuids,
        message:
          Message.from_parent(
            Session.get_session(),
            parent_message,
            "kernel_info_reply",
            content: %{
              protocol_version: "5.3",
              implementation: "ielixir",
              implementation_version: "1.0",
              language_info: %{
                "name" => "elixir",
                "version" => System.version(),
                "mimetype" => "text/x-ielixir",
                "file_extension" => "ex",
                "pygments_lexer" => "elixir",
                "codemirror_mode" => "ielixir",
                "nbconvert_exporter" => ""
              },
              banner: "IElixir kernel: `#{File.cwd!()}`",
              help_links: [
                %{
                  "text" => "Elixir Getting Started",
                  "url" => "http://elixir-lang.org/getting-started/introduction.html"
                },
                %{
                  "text" => "Elixir Documentation",
                  "url" => "http://elixir-lang.org/docs.html"
                },
                %{
                  "text" => "Elixir Sources",
                  "url" => "https://github.com/elixir-lang/elixir"
                }
              ]
            }
          )
      },
      IOPub.idle_notifier(packet)
    }
  end

  def handle_packet(
        %Packet{
          uuids: uuids,
          message: %Message{header: %{msg_type: "comm_info_request"}} = parent_message
        } = packet,
        _channel
      ) do
    Logger.debug("Received comm_info_request")
    IOPub.busy_notifier(packet).()

    {
      %Packet{
        uuids: uuids,
        message:
          Message.from_parent(
            Session.get_session(),
            parent_message,
            "comm_info_reply",
            content: %{
              comms: %{}
            }
          )
      },
      IOPub.idle_notifier(packet)
    }
  end

  def handle_packet(
        %Packet{
          uuids: uuids,
          message: %Message{
            header: %{msg_type: "complete_request"},
            content: content
          } = parent_message
        } = packet,
        _channel
      ) do
    Logger.debug("Received complete_request")
    IOPub.busy_notifier(packet).()

    result = Session.complete_request(:crypto.strong_rand_bytes(20), content)
    Logger.debug("Returned complete_request: #{inspect result}")

    {
      %Packet{
        uuids: uuids,
        message:
          Message.from_parent(
            Session.get_session(),
            parent_message,
            "complete_reply",
            content: %{
              status: :ok,
              matches: result.matches,
              cursor_start: result.cursor_start,
              cursor_end: result.cursor_end
            }
          )
      },
      IOPub.idle_notifier(packet)
    }
  end

  def handle_packet(
        %Packet{
          uuids: uuids,
          message: %Message{
            header: %{msg_type: "execute_request"},
            content: content,
            metadata: %{"cellId" => cell}
          } = parent_message
        } = packet,
        _channel
      ) do
    Logger.debug("Received execute_request")
    Logger.debug("Packet: #{inspect packet}")

    IOPub.busy_notifier(packet).()
    Session.increase_counter()

    result = Session.execute_request(cell, content)
    Logger.debug("Returned execute_request: #{inspect result}")

    result
    |> Map.get(:output, [])
    |> Enum.join("\n")
    |> case do
      "" -> nil
      output -> IOPub.stream(packet, "stdout", output)
    end

    case result.response do
      {:text, text} ->
        IOPub.display_data(
          packet,
          data: %{"text/plain": text}
        )

      {:error, exception, :runtime_restart_required} ->
        IOPub.stream(packet, "stderr", exception)
        IOPub.stream(packet, "stderr", "Restart runtime pls")

      {:error, exception, _} ->
        IOPub.stream(packet, "stderr", exception)
    end

    {
      %Packet{
        uuids: uuids,
        message:
          Message.from_parent(
            Session.get_session(),
            parent_message,
            "execute_reply",
            content: %{
              status: "ok",
              execution_count: Session.get_counter(),
              user_expressions: %{},
              payload: %{}
            }
          )
      },
      IOPub.idle_notifier(packet)
    }
  end

end
