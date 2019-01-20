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
      {:msgpax, "~> 2.0"},
      {:benchee, "~> 0.13", only: :dev},
      {:stream_data, "~> 0.4", only: :test},
      {:jason, "~> 1.0", only: :dev}
    ]
  end
end
