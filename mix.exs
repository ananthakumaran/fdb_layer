defmodule FDBLayer.MixProject do
  use Mix.Project

  def project do
    [
      app: :fdb_layer,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:fdb, "~> 6.0.15-1"},
      {:msgpax, "~> 2.0"}
    ]
  end
end
