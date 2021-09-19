defmodule IElixir do
  require Logger

  alias IElixir.Init.Resources

  def main(["install" | _]) do
    at_tmp_folder(fn tmp_folder_path ->
      case which_jupyter() do
        {_, 0} ->
          Resources.generate_kernel(tmp_folder_path)
          case kernelspec(tmp_folder_path) do
            {_, 0} ->
              [:green, "All set! You are ready to start"]

            _ ->
              [:red, "Kernelspec is not valid (and it's probably a bug)! Kernel installation is failed"]
          end

        _ ->
          [:red, "Jupyter execution is not found! Kernel installation is failed"]
      end
    end)
    |> IO.ANSI.format()
    |> IO.puts()
  end

  def main(["serve", connection_file_path | _]) do
    # Dir where the kernel is started
    # Logger.debug(File.cwd())
    Logger.debug("Starting IElixir kernel with connection_filed #{connection_file_path}")

    # Parsing connection file
    connection_data =
      connection_file_path
      |> IElixir.Kernel.ConnectionFile.parse()

    Logger.debug("Read connection data:\n#{inspect(connection_data)}")

    result = IElixir.Kernel.Supervisor.start_link(connection_data)
    Logger.debug("Supervision tree running results: #{inspect(result)}")

    :timer.sleep(:infinity)
  end

  defp kernelspec(tmp_folder_path) do
    System.cmd("jupyter", ["kernelspec", "install", "--user", "--replace", "--name=ielixir", tmp_folder_path])
  end

  defp at_tmp_folder(fun) do
    case IElixir.Util.Tmp.mktemp() do
      {:ok, tmp_folder_path} ->
        try do
          fun.(tmp_folder_path)
        after
          File.rm_rf!(tmp_folder_path)
        end

      {:error, _} ->
        [:red, "Impossible to create temp folder! Kernel installation is failed"]
    end
  end

  defp which_jupyter() do
    System.cmd("which", ["jupyter"])
  end

end
