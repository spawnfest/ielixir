defmodule IElixir do
  require Logger

  def main(["install" | _]) do
    case IElixir.Util.Tmp.mktemp() do
      {:ok, tmp_folder_path} ->
        result =
          case System.cmd("which", ["jupyter"], stderr_to_stdout: true) do
            {_, 0} ->
              IElixir.Init.Resources.generate_kernel(tmp_folder_path)

              case System.cmd(
                     "jupyter",
                     [
                       "kernelspec",
                       "install",
                       "--user",
                       "--replace",
                       "--name=ielixir",
                       tmp_folder_path
                     ],
                     stderr_to_stdout: true
                   ) do
                {_, 0} ->
                  [:green, "All set! You are ready to start"]

                _ ->
                  [
                    :red,
                    "Kernelspec is not valid (and it's probably a bug)! Kernel installation is failed"
                  ]
              end

            _ ->
              [
                :red,
                "Jupyter execution is not found! Kernel installation is failed"
              ]
          end

        File.rm_rf!(tmp_folder_path)
        result

      {:error, _} ->
        [
          :red,
          "Impossible to create temp folder! Kernel installation is failed"
        ]
    end
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
end
