defmodule IElixir.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ielixir,
      escript: escript(),
      version: @version,
      source_url: "https://github.com/ilhub/ielixir",
      name: "IElixir",
      elixir: ">= 1.12.0",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: false,
      deps: deps(),
      description: """
      Jupyter's kernel for Elixir programming language
      """,
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def escript() do
    [
      main_module: IElixir
    ]
  end

  defp deps do
    [
      {:chumak, "~> 1.4"},
      {:jason, "~> 1.2"},
      {:uuid, "~> 2.0", hex: :uuid_erl},
      {:ex_image_info, "~> 0.2.4"},
      {:vega_lite, "~> 0.1.1"},

      # Docs dependencies
      {:ex_doc, ">= 0.0.0", only: :docs, runtime: false},
      {:inch_ex, "~> 2.0.0", only: :docs},

      # Test dependencies
      {:excoveralls, "~> 0.14", only: :test},
      {:dialyxir, "~> 1.1", runtime: false, only: [:dev, :test]}
    ]
  end

  defp package do
    [
      files: [
        "config",
        "lib",
        "priv",
        "mix.exs",
        "README.md"
      ],
      maintainers: ["Dmitry Rubinstein", "Georgy Sychev"],
      licenses: ["MIT", "Apache-2.0"]
    ]
  end
end
