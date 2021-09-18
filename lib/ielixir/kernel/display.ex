defmodule IElixir.Kernel.Display do
  defstruct data: %{},
            metadata: %{},
            transient: %{}

  @type t() :: %__MODULE__{data: map(), metadata: map(), transient: map()}
end

defprotocol IElixir.Kernel.Displayable do
  @fallback_to_any true

  @spec display(term()) :: IElixir.Kernel.Display.t()
  def display(term)
end

defimpl IElixir.Kernel.Displayable, for: Any do
  # Basic implementation - for everything.
  def display(term) do
    %IElixir.Kernel.Display{data: %{"text/plain": inspect(term)}, metadata: %{}, transient: %{}}
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
