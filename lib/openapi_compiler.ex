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
    quote location: :keep, bind_quoted: [opts: opts] do
      %OpenAPICompiler.Context{
        schema: schema,
        external_resources: external_resources,
        server: server
      } = context = OpenAPICompiler.Context.create(opts, __MODULE__)

      @moduledoc OpenAPICompiler.Description.description(context)

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

      require OpenAPICompiler.Typespec.Server

      OpenAPICompiler.Typespec.Server.typespec(context)

      require OpenAPICompiler.Component.Schema

      # credo:disable-for-next-line Credo.Check.Design.AliasUsage
      OpenAPICompiler.Component.Schema.define_module(context, :read)
      # credo:disable-for-next-line Credo.Check.Design.AliasUsage
      OpenAPICompiler.Component.Schema.define_module(context, :write)

      require OpenAPICompiler.Typespec.Api.Response

      OpenAPICompiler.Typespec.Api.Response.base_typespecs()

      require OpenAPICompiler.Path

      OpenAPICompiler.Path.define_base_paths(context)
      OpenAPICompiler.Path.define_alias_modules(context)
      OpenAPICompiler.Path.define_callbacks(context)
    end
  end

  defmodule UnknownTypeError do
    defexception [:message, :definition, :type, :context]

    @impl Exception
    def exception(opts) do
      type = Keyword.fetch!(opts, :type)
      context = Keyword.fetch!(opts, :context)
      definition = Keyword.fetch!(opts, :definition)

      %__MODULE__{
        message: "Unknown Type #{type}",
        type: type,
        context: context,
        definition: definition
      }
    end
  end

  defmodule InvalidOptsError do
    defexception [:message]
  end

  defmodule RefNotFoundError do
    defexception [:message, :ref, :schema]

    @impl Exception
    def exception(opts) do
      ref = Keyword.fetch!(opts, :ref)
      schema = Keyword.fetch!(opts, :schema)

      %__MODULE__{
        message: "Ref #{ref} not found",
        ref: ref,
        schema: schema
      }
    end
  end

  defmodule CircularRefError do
    defexception [:message, :schema]

    @impl Exception
    def exception(opts) do
      schema = Keyword.fetch!(opts, :schema)

      %__MODULE__{
        message: "Circular refs are only supported for schema components",
        schema: schema
      }
    end
  end
end
