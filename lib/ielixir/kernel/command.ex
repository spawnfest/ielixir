defmodule IElixir.Kernel.Command do
  defstruct code: [], magic: []

  @type t() :: %__MODULE__{code: [], magic: []}

  @spec parse(binary) :: t()
  def parse(code) do
    code
    |> String.split(~r/\R/)
    |> Enum.reduce(%__MODULE__{}, &command_line_parser/2)
    |> then(fn %__MODULE__{code: code, magic: magic} ->
      %__MODULE__{code: Enum.reverse(code), magic: Enum.reverse(magic)}
    end)
  end

  defp command_line_parser(code_line, command = %__MODULE__{}) do
    case IElixir.Util.MagicCommand.parse(code_line) do
      {:ok, value} -> Map.update(command, :magic, [], &[value | &1])
      {:error, value} -> Map.update(command, :code, [], &[value | &1])
    end
  end
end
