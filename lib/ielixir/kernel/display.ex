defmodule IElixir.Kernel.Display do
  defstruct data: %{},
            metadata: %{},
            transient: %{}

  @type t() :: %__MODULE__{data: map(), metadata: map(), transient: map()}

  alias IElixir.Kernel.Displayable

  def display({:ok, :"do not show this result in output"}) do
    # Functions in the `IEx.Helpers` module return this specific value
    # to indicate no result should be printed in the iex shell,
    # so we respect that as well.
    :ignored
  end

  def display({:ok, value}) do
    {:display, Displayable.display(value)}
  end

  def display({:error, kind, error, stacktrace}) do
    formatted = Exception.format(kind, error, stacktrace)
    {:error, formatted, error_type(error)}
  end

  defp error_type(error) do
    cond do
      mix_install_vm_error?(error) -> :runtime_restart_required
      true -> :other
    end
  end

  defp mix_install_vm_error?(exception) do
    is_struct(exception, Mix.Error) and
      Exception.message(exception) =~
        "Mix.install/2 can only be called with the same dependencies"
  end

end

defprotocol IElixir.Kernel.Displayable do
  @fallback_to_any true

  @spec display(term()) :: IElixir.Kernel.Display.t()
  def display(term)

end

defimpl IElixir.Kernel.Displayable, for: Any do

  # Note: we intentionally don't specify colors
  # for `:binary`, `:list`, `:map` and `:tuple`
  # and rely on these using the default text color.
  # This way we avoid a bunch of HTML tags for coloring commas, etc.
  @opts [
    pretty: true,
    width: 100,
    syntax_colors: [
        atom: :blue,
        # binary: :light_black,
        boolean: :magenta,
        # list: :light_black,
        # map: :light_black,
        number: :blue,
        nil: :magenta,
        regex: :red,
        string: :green,
        # tuple: :light_black,
        reset: :reset
      ]
    ]

  def display(term) do
    %IElixir.Kernel.Display{data: %{"text/plain": inspect(term, @opts)}}
  end

end

defimpl IElixir.Kernel.Displayable, for: BitString do

  # Basic implementation - for everything.
  @spec display(binary) :: IElixir.Kernel.Display.t()
  def display(term) do
    case ExImageInfo.info(term) do
      # This is not an image, or at least - not recognizable
      nil ->
        # Here we check that the data is valid json
        case Jason.decode(term) do
          {:ok, json_data} ->
            %IElixir.Kernel.Display{
              data: %{
                "text/plain": inspect(term),
                "application/json": json_data
              },
              metadata: %{"application/json": %{expanded: true}},
              transient: %{}
            }

          # This is nothing
          {:error, _reason} ->
            %IElixir.Kernel.Display{
              data: %{"text/plain": inspect(term)},
              metadata: %{},
              transient: %{}
            }
        end

      {mime_type, width, height, _type_name} ->
        %IElixir.Kernel.Display{
          data: %{mime_type => Base.encode64(term), "text/plain" => inspect(term)},
          metadata: %{mime_type => %{width: width, height: height}},
          transient: %{}
        }
    end
  end
end

defimpl IElixir.Kernel.Displayable, for: Map do
  def display(
        %{
          "$schema" => "https://vega.github.io/schema/vega-lite/v5.json"
        } = vega_doc
      ) do
    %IElixir.Kernel.Display{
      data: %{
        "application/vnd.vegalite.v4+json": %{vega_doc | "$schema" => "https://vega.github.io/schema/vega-lite/v4.json"}
      }
    }
  end

  # Basic implementation - for everything.
  @spec display(binary) :: IElixir.Kernel.Display.t()
  def display(term) do
    IElixir.Kernel.Displayable.Any.display(term)
  end
end
