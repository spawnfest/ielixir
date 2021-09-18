defmodule IElixir.Init.Resources do
  @external_resource "priv/kernel.js"
  @external_resource "priv/kernel.json"
  @external_resource "priv/logo-32x32.png"
  @external_resource "priv/logo-64x64.png"

  @kernel_folder_data [
    {"kernel.js", File.read!("priv/kernel.js")},
    {"kernel.json", File.read!("priv/kernel.json")},
    {"logo-32x32.png", File.read!("priv/logo-32x32.png")},
    {"logo-64x64.png", File.read!("priv/logo-64x64.png")}
  ]

  @spec generate_kernel(path_to_folder :: String.t()) :: :ok
  def generate_kernel(path_to_folder) do
    File.mkdir_p!(path_to_folder)

    Enum.each(@kernel_folder_data, fn {file_name, file_data} ->
      File.write!(Path.join(path_to_folder, file_name), file_data)
    end)
  end
end
