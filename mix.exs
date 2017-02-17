defmodule PhoenixEtag.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [app: :phoenix_etag,
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package(),
     name: "PhoenixETag",
     docs: docs()]
  end

  def application do
    [applications: [:logger, :phoenix, :plug]]
  end

  defp deps do
    [{:phoenix, "~> 1.2"},
     {:plug, "~> 1.0"},
     {:ex_doc, "~> 0.14", only: :dev}]
  end

  defp description do
    """
    Conditional request (ETag & modified-since) support for Phoenix.
    """
  end

  defp package do
    [maintainers: ["Michał Muskała"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/michalmuskala/phoenix_etag"}]
  end

  defp docs do
    [source_ref: "v#{@version}",
     canonical: "http://hexdocs.pm/phoenix_etag",
     source_url: "https://github.com/michalmuskala/phoenix_etag",
     main: "PhoenixETag"]
  end
end
