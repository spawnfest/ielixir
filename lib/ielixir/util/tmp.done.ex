defmodule IElixir.Util.Tmp do
  @doc """
  Function is to create a temporary directory path where all the kernel initializtion files will be created
  """
  @spec mktemp(binary) :: {:ok, String.t()} | {:error, :enoent}
  def mktemp(template \\ "XXXXXX") do
    case System.cmd("mktemp", ["-d", "-t", template], stderr_to_stdout: true) do
      {path, 0} -> {:ok, String.trim(path)}
      _ -> {:error, :enoent}
    end
  end
end
