defmodule Bounds.MixProject do
  use Mix.Project

  def project, do: [
    app: :bounds,
    version: "0.1.0",
    elixir: "~> 1.8",
    start_permanent: Mix.env() == :prod,
    deps: deps()
  ]

  def application, do: [
    extra_applications: [:logger]
  ]

  defp deps, do: [
    {:ex_doc, "~> 0.20.2", only: :dev, runtime: false}
  ]
end
