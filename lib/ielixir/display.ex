defmodule IElixir.Display do
  @moduledoc """
  This module is to be propogated on target machine.
  """
  @type t() :: %__MODULE__{fields: map()}
  defstruct fields: %{}
end

defprotocol IElixir.Displayable do
  @fallback_to_any true

  @spec display(t) :: IElixir.Display.t() | term
  def display(value)
end

defimpl IElixir.Displayable, for: Any do
  @spec display(any) :: IElixir.Display.t() | term
  # For the first run - do nothing with data. If user define something - he must return IElixir.Display.t() stuff
  def display(value), do: value
end
