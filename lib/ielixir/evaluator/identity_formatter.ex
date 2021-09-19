defmodule IElixir.Evaluator.IdentityFormatter do
  @moduledoc false

  # The default formatter leaving the output unchanged.

  @behaviour IElixir.Evaluator.Formatter

  @impl true
  def format_response(evaluation_response) do
    inspect(evaluation_response)
  end
end
