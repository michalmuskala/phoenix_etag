defmodule PhoenixEtag.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix_etag,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger, :phoenix, :plug]]
  end

  defp deps do
    [{:phoenix, "~> 1.2"},
     {:plug, "~> 1.0"}]
  end
end
