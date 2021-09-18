defmodule IElixir.Util.MagicCommand do
  @magic_command_regexp ~r/^%[a-z][a-zA-Z0-9]*.*$/

  @spec parse(code :: String.t()) :: term()
  def parse(code) do
    case Regex.match?(@magic_command_regexp, code) do
      true ->
        {:ok,
         code
         |> String.trim_leading("%")
         |> String.split(~r/\W+/)}

      false ->
        {:error, code}
    end
  end
end
