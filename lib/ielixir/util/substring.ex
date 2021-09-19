defmodule IElixir.Util.Substring do
  @spec calculate_substring_position(string :: String.t(), substitutions :: list(String.t())) ::
          integer()
  def calculate_substring_position(string, [first_substitution | _] = _substitutions) do
    default_position = String.length(string)

    start_position =
      Enum.reduce_while((default_position - 1)..0, :not_found, fn grapheme_index, acc ->
        if String.starts_with?(
             first_substitution,
             String.slice(string, grapheme_index, default_position)
           ) do
          {:halt, grapheme_index}
        else
          {:cont, acc}
        end
      end)

    if String.starts_with?(first_substitution, string) do
      0
    else
      case start_position do
        :not_found -> default_position
        value when is_integer(value) -> value
      end
    end
  end
end
