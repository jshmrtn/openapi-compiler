defmodule OpenAPICompiler.MixProject do
  use Mix.Project

  @version "1.0.0-beta.1"

  def project do
    [
      app: :openapi_compiler,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:yamerl]
      ],
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  defp description do
    """
    Generate API client from OpenAPI Yaml / JSON.
    """
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.2"},
      {:tesla, "~> 1.3"},
      {:uri_template, "~> 1.2"},
      {:yamerl, "~> 0.7", runtime: false},
      {:ex_doc, "~> 0.21", runtime: false},
      {:dialyxir, "~> 1.0", runtime: false, only: [:dev]}
    ]
  end

  defp package do
    # These are the default files included in the package
    [
      name: :openapi_compiler,
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Jonatan Männchen"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/jshmrtn/openapi-compiler"}
    ]
  end

  defp docs do
    [
      source_ref: "v" <> @version,
      source_url: "https://github.com/jshmrtn/openapi-compiler",
      extras: [
        "CHANGELOG.md"
      ]
    ]
  end
end
