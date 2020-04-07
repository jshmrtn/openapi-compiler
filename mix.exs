defmodule OpenAPICompiler.MixProject do
  @moduledoc false

  use Mix.Project

  @version "1.0.0-beta.8"

  def project do
    [
      app: :openapi_compiler,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer:
        [
          plt_add_apps: [:yamerl]
        ] ++
          if (System.get_env("DIALYZER_PLT_PRIV") || "false") in ["1", "true"] do
            [
              plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
            ]
          else
            []
          end,
      test_coverage: [tool: ExCoveralls],
      build_embedded: (System.get_env("BUILD_EMBEDDED") || "false") in ["1", "true"],
      description: description(),
      package: package(),
      docs: docs(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:ex_doc, "~> 0.21", runtime: false, only: [:dev, :test]},
      {:dialyxir, "~> 1.0", runtime: false, only: [:dev]},
      {:excoveralls, "~> 0.5", only: [:test], runtime: false},
      {:credo, "~> 1.0", only: [:dev], runtime: false},
      {:assert_value, "~> 0.9", only: [:dev, :test]}
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
