defmodule OpenAPICompiler.Path do
  @moduledoc false

  defmacro define_base_paths(context) do
    quote location: :keep do
      %OpenAPICompiler.Context{schema: schema} = unquote(context)

      import unquote(__MODULE__)

      for root <- schema,
          {path, methods} <- root["paths"] || [],
          {method, definition} <- methods do
        path_definition(path, method, definition, unquote(context))

        unless is_nil(definition["operationId"]) do
          alias_path(definition["operationId"], method, path, unquote(context))
        end
      end

      case @spec do
        [] -> @moduledoc false
        _ -> @moduledoc "TODO"
      end
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

      config_type = OpenAPICompiler.Typespec.api_config(definition, context)
      response_type = OpenAPICompiler.Typespec.api_response(definition, context)

      fn_name =
        caller.normalize_name(
          method <>
            "_" <>
            case path do
              url when url in ["", "/"] -> "root"
              url -> url
            end
        )

      @doc """
      `#{String.upcase(method)}` `#{path}`

      #{definition["description"]}
      """
      @spec unquote(fn_name)(client :: Tesla.Client.t(), config :: unquote(config_type)) ::
              {:ok, unquote(response_type)}
              | {:error, {:unexpected_response, Tesla.Env.t()} | any}
      def unquote(fn_name)(client \\ %Tesla.Client{}, config) do
        client
        |> unquote(base_module).request(
          method: unquote(String.to_atom(method)),
          url: UriTemplate.from_string(unquote(path)),
          query: Map.get(config, :query, []),
          headers: Map.get(config, :headers, []),
          body: Map.get(config, :body, nil),
          opts:
            [
              path_parameters: Map.get(config, :path, %{}),
              server_parameters: Map.get(config, :server, %{})
            ] ++ Map.get(config, :opts, [])
        )
        |> unquote(:"#{fn_name}_response")()
      end

      for {code, response_definition} <- definition["responses"] do
        case {code, Integer.parse(code)} do
          {"default", _} ->
            defp unquote(:"#{fn_name}_response")(
                   {:ok, %Tesla.Env{status: code, body: body} = env}
                 )
                 when not is_nil(code) do
              {:ok, {code, body, env}}
            end

          {_, {code, ""}} ->
            defp unquote(:"#{fn_name}_response")(
                   {:ok, %Tesla.Env{status: unquote(code), body: body} = env}
                 ) do
              {:ok, {unquote(code), body, env}}
            end
        end
      end

      defp unquote(:"#{fn_name}_response")({:ok, env}) do
        {:error, {:unexpected_response, env}}
      end

      defp unquote(:"#{fn_name}_response")({:error, reason}) do
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

  def normalize_name(name) do
    name
    |> String.replace(~R/[^\w]/, "_", global: true)
    |> Macro.underscore()
    |> String.replace(~R/_+/, "_", global: true)
    |> String.trim("_")
    |> String.to_atom()
  end
end
