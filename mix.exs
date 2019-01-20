defmodule FDBLayer.MixProject do
  use Mix.Project

  def project do
    [
      app: :fdb_layer,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(:dev), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:fdb, "~> 6.0.15-1"},
      {:msgpax, "~> 2.0"},
      {:protox, "~> 0.17.0"},
      {:benchee, "~> 0.13", only: :dev},
      {:stream_data, "~> 0.4", only: :test},
      {:jason, "~> 1.0", only: :dev}
    ]
  end
end
