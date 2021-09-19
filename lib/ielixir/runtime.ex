defprotocol IElixir.Runtime do
  @moduledoc false

  # This protocol defines an interface for evaluation backends.
  #
  # Usually a runtime involves a set of processes responsible
  # for evaluation, which could be running on a different node,
  # however the protocol does not require that.

  @typedoc """
  An arbitrary term identifying an evaluation container.

  A container is an abstraction of an isolated group of evaluations.
  Containers are mostly independent and consequently can be evaluated
  concurrently if possible.

  Note that every evaluation can use the resulting environment
  and bindings of any previous evaluation, even from a different
  container.
  """
  @type cell :: String.t()

  @typedoc """
  Expected completion responses.

  Responding with `nil` indicates there is no relevant reply
  and effectively aborts the request, so it's suitable for
  error cases.
  """
  @type completion_response :: term()

  @typedoc """
  Looks up a list of identifiers that are suitable code
  completions for the given hint.
  """
  @type completion_request :: {:completion, hint :: String.t()}

  @type completion_item :: %{
          label: String.t(),
          kind: completion_item_kind(),
          detail: String.t() | nil,
          documentation: String.t() | nil,
          insert_text: String.t()
        }

  @type completion_item_kind ::
          :function | :module | :struct | :interface | :type | :variable | :field

  @typedoc """
  Looks up more details about an identifier found in `column` in `line`.
  """
  @type details_request :: {:details, line :: String.t(), column :: pos_integer()}

  @type details_response :: %{
          range: %{
            from: non_neg_integer(),
            to: non_neg_integer()
          },
          contents: list(String.t())
        }

  @typedoc """
  Formats the given code snippet.
  """
  @type format_request :: {:format, code :: String.t()}

  @type format_response :: %{
          code: String.t()
        }

  @doc """
  Sets the caller as runtime owner.

  It's advised for each runtime to have a leading process
  that is coupled to the lifetime of the underlying runtime
  resources. In this case the `connect` function may start
  monitoring that process and return the monitor reference.
  This way the caller is notified when the runtime goes down
  by listening to the :DOWN message.
  """
  @spec connect(t()) :: reference()
  def connect(runtime)

  @doc """
  Disconnects the current owner from runtime.

  This should cleanup the underlying node/processes.
  """
  @spec disconnect(t()) :: :ok
  def disconnect(runtime)

  @doc """
  Asynchronously parses and evaluates the given code.

  The given `cell` identifies the container where
  the code should be evaluated as well as the evaluation
  reference to store the resulting contxt under.

  Additionally, `prev_cell` points to a previous
  evaluation to be used as the starting point of this
  evaluation. If not applicable, the previous evaluation
  reference may be specified as `nil`.

  ## Communication

  Evaluation outputs are sent to the connected runtime owner.
  The messages should be of the form:

    * `{:evaluation_output, ref, output}` - output captured
      during evaluation

    * `{:evaluation_response, ref, output, metadata}` - final
      result of the evaluation. Recognised metadata entries
      are: `evaluation_time_ms`

  The evaluation may request user input by sending
  `{:evaluation_input, ref, reply_to, prompt}` to the runtime owner,
  which is supposed to reply with `{:evaluation_input_reply, reply}`
  where `reply` is either `{:ok, input}` or `:error` if no matching
  input can be found.

  In all of the above `ref` is the evaluation reference.

  If the evaluation state within a container is lost (for example
  a process goes down), the runtime may send `{:container_down, cell, message}`
  to notify the owner.

  ## Options

    * `:file` - file to which the evaluated code belongs. Most importantly,
      this has an impact on the value of `__DIR__`.
  """
  @spec evaluate_code(t(), String.t(), cell(), cell(), keyword()) :: :ok
  def evaluate_code(runtime, code, cell, prev_cell, opts \\ [])

  @doc """
  Disposes of an evaluation identified by the given cell.

  This can be used to cleanup resources related to an old evaluation
  if no longer needed.
  """
  @spec forget_evaluation(t(), cell()) :: :ok
  def forget_evaluation(runtime, cell)

  @doc """
  Disposes of an evaluation container identified by the given ref.

  This should be used to cleanup resources keeping track of the
  container all of its evaluations.
  """
  @spec drop_container(t(), cell()) :: :ok
  def drop_container(runtime, cell)

  @doc """
  Asynchronously handles an completion request.

  This part of runtime functionality is used to provide
  language and context specific completion features in
  the text editor.

  The response is sent to the `send_to` process as
  `{:completion_response, ref, request, response}`.

  The given `cell` idenfities an evaluation that may be used
  as context when resolving the request (if relevant).
  """
  @spec handle_completion(t(), String.t(), Integer.t(), cell()) :: :ok
  def handle_completion(runtime, code, cursor, cell)

  @doc """
  Synchronously starts a runtime of the same type with the
  same parameters.
  """
  @spec duplicate(Runtime.t()) :: {:ok, Runtime.t()} | {:error, String.t()}
  def duplicate(runtime)
end
