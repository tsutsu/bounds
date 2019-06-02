defmodule Bounds.MixProject do
  use Mix.Project

  @version "0.1.9"

  def project, do: [
    app: :bounds,
    version: @version,
    elixir: "~> 1.8",
    start_permanent: Mix.env() == :prod,
    description: description(),
    package: package(),
    deps: deps(),
    name: "Bounds",
    source_url: "https://github.com/tsutsu/bounds",
    docs: docs()
  ]

  def application, do: [
    extra_applications: [:logger]
  ]

  defp deps, do: [
    {:ex_doc, "~> 0.20.2", only: :dev, runtime: false},
    {:version_tasks, "~> 0.11.0", only: :dev, runtime: false}
  ]

  defp description, do: """
    Bounds is a library for generic Elixir intervals, which formalizes Erlang's `{pos, len}`
    tuples into an ADT with many supported operations.
  """

  defp package, do: [
    licenses: ["MIT"],
    links: %{"GitHub" => "https://github.com/tsutsu/bounds"}
  ]

  defp docs, do: [
    main: "Bounds"
  ]
end
