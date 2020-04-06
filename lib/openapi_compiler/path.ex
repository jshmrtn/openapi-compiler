defmodule OpenAPICompiler.Path do
  @moduledoc false

  defmacro define_base_paths(context) do
    quote location: :keep do
      %OpenAPICompiler.Context{schema: schema} = unquote(context)

      import unquote(__MODULE__)

      for root <- schema,
          not is_nil(root["paths"]),
          {path, methods} <- root["paths"],
          not is_nil(methods),
          {method, definition} <- methods do
        path_definition(path, method, definition, unquote(context))

        unless is_nil(definition["operationId"]) do
          alias_path(definition["operationId"], method, path, unquote(context))
        end
      end
    end
  end

  defmacro define_callbacks(context) do
    quote location: :keep do
      %OpenAPICompiler.Context{schema: schema} = unquote(context)

      import unquote(__MODULE__)

      for root <- schema,
          not is_nil(root["paths"]),
          {api_path, api_methods} <- root["paths"],
          not is_nil(api_methods),
          {api_method, api_definition} <- api_methods,
          not is_nil(api_definition["callbacks"]),
          {callback_name, callback_paths} <- api_definition["callbacks"],
          not is_nil(callback_paths),
          {callback_path, callback_methods} <- callback_paths,
          not is_nil(callback_methods),
          {callback_method, callback_definition} <- callback_methods do
        callback_definition(
          api_path,
          api_method,
          callback_name,
          callback_path,
          callback_method,
          callback_definition,
          unquote(context)
        )
      end
    end
  end

  defmacro callback_definition(
             api_path,
             api_method,
             callback_name,
             callback_path,
             callback_method,
             callback_definition,
             context
           ) do
    quote location: :keep,
          bind_quoted: [
            api_path: api_path,
            api_method: api_method,
            callback_name: callback_name,
            callback_path: callback_path,
            callback_method: callback_method,
            callback_definition: callback_definition,
            caller: __MODULE__,
            context: context
          ] do
      callback_name =
        caller.normalize_name(
          Enum.join(
            [
              api_method,
              case api_path do
                url when url in ["", "/"] -> "root"
                url -> url
              end,
              callback_name,
              # callback_path,
              callback_method
            ],
            "_"
          )
        )

      require OpenAPICompiler.Typespec.Api.Response
      response_type_name = :"#{callback_name}_response"

      OpenAPICompiler.Typespec.Api.Response.typespec(
        response_type_name,
        callback_definition,
        context
      )

      require OpenAPICompiler.Typespec.Api.Config
      config_type_name = :"#{callback_name}_config"
      OpenAPICompiler.Typespec.Api.Config.typespec(config_type_name, callback_definition, context)
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro path_definition(path, method, definition, context) do
    quote location: :keep,
          bind_quoted: [
            path: path,
            method: method,
            definition: definition,
            caller: __MODULE__,
            context: context
          ] do
      %OpenAPICompiler.Context{base_module: base_module} = context

      fn_name =
        caller.normalize_name(
          method <>
            "_" <>
            case path do
              url when url in ["", "/"] -> "root"
              url -> url
            end
        )

      require OpenAPICompiler.Typespec.Api.Response
      response_type_name = :"#{fn_name}_response"
      OpenAPICompiler.Typespec.Api.Response.typespec(response_type_name, definition, context)

      require OpenAPICompiler.Typespec.Api.Config
      config_type_name = :"#{fn_name}_config"
      OpenAPICompiler.Typespec.Api.Config.typespec(config_type_name, definition, context)

      @doc """
      `#{String.upcase(method)}` `#{path}`

      #{definition["description"]}
      """
      @spec unquote(fn_name)(client :: Tesla.Client.t(), config :: unquote(config_type_name)()) ::
              unquote(response_type_name)()
      # credo:disable-for-next-line Credo.Check.Readability.Specs
      def unquote(fn_name)(client \\ %Tesla.Client{}, config) do
        unquote(caller).request(
          client,
          config,
          unquote(base_module),
          unquote(method),
          unquote(path),
          Function.capture(__MODULE__, :"#{unquote(fn_name)}_response", 1)
        )
      end

      @doc false
      for {code, response_definition} <- definition["responses"] do
        case code do
          "default" ->
            # credo:disable-for-next-line Credo.Check.Readability.Specs
            def unquote(:"#{fn_name}_response")({:ok, %Tesla.Env{status: nil, body: body} = env}) do
              {:error, {:unexpected_response, env}}
            end

            # credo:disable-for-next-line Credo.Check.Readability.Specs
            def unquote(:"#{fn_name}_response")({:ok, %Tesla.Env{status: code, body: body} = env}) do
              {:ok, {code, body, env}}
            end

          code when is_binary(code) ->
            code = String.to_integer(code)

            # credo:disable-for-next-line Credo.Check.Readability.Specs
            def unquote(:"#{fn_name}_response")(
                  {:ok, %Tesla.Env{status: unquote(code), body: body} = env}
                ) do
              {:ok, {unquote(code), body, env}}
            end

          code when is_integer(code) ->
            # credo:disable-for-next-line Credo.Check.Readability.Specs
            def unquote(:"#{fn_name}_response")(
                  {:ok, %Tesla.Env{status: unquote(code), body: body} = env}
                ) do
              {:ok, {unquote(code), body, env}}
            end
        end
      end

      # credo:disable-for-next-line Credo.Check.Readability.Specs
      def unquote(:"#{fn_name}_response")({:ok, env}) do
        {:error, {:unexpected_response, env}}
      end

      # credo:disable-for-next-line Credo.Check.Readability.Specs
      def unquote(:"#{fn_name}_response")({:error, reason}) do
        {:error, reason}
      end
    end
  end

  defmacro alias_path(name, method, path, context) do
    quote location: :keep,
          bind_quoted: [
            name: name,
            context: context,
            method: method,
            path: path,
            caller: __MODULE__
          ] do
      %OpenAPICompiler.Context{base_module: module} = context

      operation_name = caller.normalize_name(name)

      fn_name =
        caller.normalize_name(
          method <>
            "_" <>
            case path do
              url when url in ["", "/"] -> "root"
              url -> url
            end
        )

      defdelegate unquote(operation_name)(client \\ %Tesla.Client{}, config),
        to: module,
        as: fn_name
    end
  end

  defmacro define_alias_modules(context) do
    quote location: :keep do
      import unquote(__MODULE__)

      %OpenAPICompiler.Context{schema: schema, base_module: base_module} = unquote(context)

      schema
      |> Enum.flat_map(&(get_in(&1, ["paths"]) || []))
      |> Enum.flat_map(fn {path, methods} ->
        Enum.map(methods, fn {method, definition} ->
          {path, method, definition["tags"] || [], definition["operationId"]}
        end)
      end)
      |> Enum.flat_map(fn {path, method, tags, operation_id} ->
        Enum.map(tags, &{&1, path, method, operation_id})
      end)
      |> Enum.group_by(&elem(&1, 0))
      |> Enum.map(fn {tag, endpoints} ->
        module = Module.concat(base_module, Macro.camelize(tag))

        defmodule module do
          @moduledoc OpenAPICompiler.Description.description(unquote(context))

          for {_tag, path, method, operation_id} <- endpoints do
            alias_path(method <> "_" <> path, method, path, unquote(context))

            unless is_nil(operation_id) do
              alias_path(operation_id, method, path, unquote(context))
            end
          end
        end
      end)
    end
  end

  @spec normalize_name(name :: String.t()) :: atom
  def normalize_name(name) do
    name
    |> String.replace(~R/[^\w]/, "_", global: true)
    |> Macro.underscore()
    |> String.replace(~R/_+/, "_", global: true)
    |> String.trim("_")
    |> String.to_atom()
  end

  @spec request(
          client :: Tesla.Client.t(),
          config :: map(),
          base_module :: atom(),
          method :: String.t(),
          path :: String.t(),
          callback :: (Tesla.Env.result() -> result)
        ) :: result
        when result: any
  def request(client, config, base_module, method, path, callback) do
    client
    |> base_module.request(
      method: String.to_atom(method),
      url: UriTemplate.from_string(path),
      query: Map.get(config, :query, []),
      headers: Map.get(config, :headers, []),
      body: Map.get(config, :body, nil),
      opts:
        [
          path_parameters: Map.get(config, :path, %{}),
          server_parameters: Map.get(config, :server, %{})
        ] ++ Map.get(config, :opts, [])
    )
    |> callback.()
  end
end
