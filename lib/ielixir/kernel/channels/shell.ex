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
          message:
            %Message{header: %{msg_type: "execute_request"}, content: _content} = parent_message
        } = packet,
        _channel
      ) do
    Logger.debug("Received execute_request")
    IOPub.busy_notifier(packet).()
    Session.increase_counter()

    # TODO

    # magic_function(content) -> (stdout, stderr, display_Data)

    # END TODO

    IOPub.stream(
      packet,
      "stdout",
      "OUT: BOOOM!!"
    )
    IOPub.stream(
      packet,
      "stderr",
      "ERROR: Crash!!"
    )

    # IOPub.display_data(
    #   packet,
    #   IElixir.Kernel.Displayable.display(NaiveDateTime.utc_now)
    # )

    # IOPub.display_data(
    #   packet,
    #   IElixir.Kernel.Displayable.display(~s({"foo": true}))
    # )

    IOPub.display_data(
      packet,
      IElixir.Kernel.Displayable.display(File.read!("/Users/dmitry.r/dev/elixir/IElixir/resources/logo.png"))
    )

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
