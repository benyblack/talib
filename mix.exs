defmodule TAlib.MixProject do
  use Mix.Project

  @app_name :talib
  @version "0.5.0"
  @elixir_version "~> 1.8"
  @github "https://github.com/benyblack/talib"

  def project do
    [
      app: @app_name,
      name: "TAlib",
      version: @version,
      elixir: @elixir_version,
      source_url: @github,
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [main: "TAlib", extras: ["README.md"]]
    ]
  end

  def package do
    [
      name: @app_name,
      description: "Technical analysis library",
      licenses: ["MIT"],
      maintainers: ["Behnam Shomali"],
      links: %{Github: @github}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
