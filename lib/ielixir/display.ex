defmodule IElixir.Display do
  @moduledoc """
  This module is to be propogated on target machine.
  """

  def display({:ok, :"do not show this result in output"} = v), do: v

  def display({:ok, value}) do
    {:ok, IElixir.Displayable.display(value)}
  end

  def display(other), do: other

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
