defmodule OpenAPICompiler do
  @moduledoc """
  Generate OpenAPI Generator from OpenAPI 3.0 Yaml / JSON

  ## Parameters

  - `yml_path` - Yaml Location Path
  - `json_path` - JSON Location Path
  - `server` - Server to choose (by description; required when >= 2 servers)

  ## Examples

  ### Using Yml File

      defmodule Acme.PetStore do
        use OpenAPICompiler,
          yml_path: Application.app_dir(:acme_petstore, "priv/openapi.yml")
          #...
      end

  ### Using JSON File

      defmodule Acme.PetStore do
        use OpenAPICompiler,
          json_path: Application.app_dir(:acme_petstore, "priv/openapi.json")
          #...
      end
  """
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts, compiler: __MODULE__] do
      %OpenAPICompiler.Context{
        schema: schema,
        external_resources: external_resources,
        server: server
      } = context = OpenAPICompiler.Context.create(opts, __MODULE__)

      @moduledoc compiler.description(context)

      @schema schema
      @context context
      @server server

      for external_resource <- external_resources do
        @external_resource external_resource
      end

      @doc false
      def __schema__, do: @schema

      use Tesla

      plug(OpenAPICompiler.Middleware.PathParams)
      plug(OpenAPICompiler.Middleware.Server, @server)
      plug(Tesla.Middleware.JSON)
      plug(Tesla.Middleware.Logger)
      plug(Tesla.Middleware.Opts, context: @context)

      require OpenAPICompiler.Typespec

      OpenAPICompiler.Typespec.server_typespec(context)

      require OpenAPICompiler.Component.Schema

      # credo:disable-for-next-line Credo.Check.Design.AliasUsage
      OpenAPICompiler.Component.Schema.define_module(context, :read)
      # credo:disable-for-next-line Credo.Check.Design.AliasUsage
      OpenAPICompiler.Component.Schema.define_module(context, :write)

      require OpenAPICompiler.Path

      OpenAPICompiler.Path.define_base_paths(context)
      OpenAPICompiler.Path.define_alias_modules(context)
    end
  end

  @doc false
  def description(%{schema: schema}) do
    info =
      schema
      |> Enum.map(& &1["info"])
      |> Enum.reduce(%{}, &Map.merge/2)

    """
    #{info["title"]} - #{info["version"]}
    """
    |> add_description_text(not is_nil(info["description"]), fn -> info["description"] end)
    |> add_description_text(not is_nil(info["termsOfService"]), fn ->
      "Terms of Service: " <> info["termsOfService"]
    end)
    |> add_description_text(not is_nil(info["license"]), fn ->
      "License: " <>
        if is_nil(info["license"]["url"]) do
          info["license"]["name"]
        else
          "[#{info["license"]["name"]}](#{info["license"]["url"]})"
        end
    end)
    |> add_description_text(not is_nil(info["contact"]), fn ->
      [
        info["contact"]["name"],
        unless is_nil(info["contact"]["email"]) do
          "[#{info["contact"]["email"]}](mailto:#{info["contact"]["email"]})"
        end,
        info["contact"]["url"]
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" - ")
    end)
  end

  defp add_description_text(acc, false, _), do: acc

  defp add_description_text(acc, true, callback) do
    """
    #{acc}

    #{callback.()}
    """
  end
end
