defmodule OpenAPICompiler.Typespec.Api.Config do
  @moduledoc false

  import OpenAPICompiler.Typespec.Utility

  alias OpenAPICompiler.Typespec.Schema
  alias OpenAPICompiler.Typespec.Server

  defmacro typespec(name, definition, context) do
    quote location: :keep,
          bind_quoted: [name: name, definition: definition, context: context, caller: __MODULE__] do
      type = caller.type(definition, name, context, __MODULE__)

      query_name = :"#{name}_query"

      @type unquote(query_name)() ::
              unquote(caller.parameters_type(definition, "query", context, true, __MODULE__))

      header_name = :"#{name}_header"

      @type unquote(header_name)() ::
              unquote(caller.parameters_type(definition, "header", context, true, __MODULE__))

      if caller.has_parameter?(definition, "path") do
        path_name = :"#{name}_path"

        @type unquote(path_name)() ::
                unquote(caller.parameters_type(definition, "path", context, true, __MODULE__))
      end

      case definition["requestBody"] do
        nil ->
          nil

        %{} = request_body_definition ->
          request_body_name = :"#{name}_request_body"

          @type unquote(request_body_name)() ::
                  unquote(caller.request_body_type(request_body_definition, context, __MODULE__))
      end

      @type unquote(name)() :: unquote(type)
    end
  end

  @spec type(
          definition :: map,
          name :: atom,
          context :: OpenAPICompiler.Context.t(),
          caller :: atom
        ) ::
          Macro.t()
  def type(
        definition,
        name,
        %OpenAPICompiler.Context{server: global_server} = context,
        caller
      ) do
    query_name = :"#{name}_query"
    header_name = :"#{name}_header"
    path_name = :"#{name}_path"
    request_body_name = :"#{name}_request_body"

    {:%{}, [],
     [
       optional_ast(
         has_no_required_parameter?(definition, "query"),
         :query,
         quote location: :keep do
           unquote(query_name)()
         end
       ),
       optional_ast(
         has_no_required_parameter?(definition, "header"),
         :headers,
         quote location: :keep do
           unquote(header_name)()
         end
       ),
       optional_ast(
         true,
         :opts,
         quote location: :keep do
           Tesla.Env.opts()
         end
       )
     ]
     |> add_path(path_name, definition)
     |> add_request_body(request_body_name, definition)
     |> add_server(definition["server"] || global_server, context, caller)}
  end

  defp add_request_body(config, name, definition)

  defp add_request_body(
         config,
         name,
         %{"requestBody" => %{} = request_body_definition}
       ) do
    [
      optional_ast(
        request_body_definition["required"] != true,
        :body,
        quote location: :keep do
          unquote(name)()
        end
      )
      | config
    ]
  end

  defp add_request_body(config, _name, _request_body_definition),
    do: [
      optional_ast(
        true,
        :body,
        quote location: :keep do
          any()
        end
      )
      | config
    ]

  defp add_path(config, name, definition) do
    if has_parameter?(definition, "path") do
      [
        optional_ast(
          has_no_required_parameter?(definition, "path"),
          :path,
          quote location: :keep do
            unquote(name)()
          end
        )
        | config
      ]
    else
      config
    end
  end

  defp add_server(config, server, context, caller)

  # Global Server
  defp add_server(
         config,
         server,
         %OpenAPICompiler.Context{
           base_module: base_module,
           server: server
         },
         caller
       ) do
    if Server.has_variables?(server) do
      [
        optional_ast(
          true,
          :server,
          case caller do
            ^base_module ->
              quote location: :keep do
                server_parameters()
              end

            _other ->
              quote location: :keep do
                unquote(base_module).server_parameters()
              end
          end
        )
        | config
      ]
    else
      config
    end
  end

  defp add_server(_config, _server, _context, _caller) do
    # TODO: Implement
    raise "Only one global server is supported"
  end

  @spec request_body_type(map, OpenAPICompiler.Context.t(), atom) :: Macro.t()
  def request_body_type(request_body_definition, context, caller)

  def request_body_type(%{"content" => %{} = content}, context, caller) do
    content
    |> Enum.map(fn {_media_type, media_type} ->
      media_type["schema"]
    end)
    |> Enum.uniq()
    |> Enum.map(fn
      nil ->
        quote location: :keep do
          any()
        end

      schema ->
        Schema.type(schema, :write, context, caller)
    end)
    |> Kernel.++(
      if Map.has_key?(content, "multipart/form-data") do
        [
          quote location: :keep do
            Tesla.Multipart.t()
          end
        ]
      else
        []
      end
    )
    |> Enum.reduce(
      nil,
      fn
        value, nil -> value
        value, acc -> {:|, [], [value, acc]}
      end
    )
  end

  def request_body_type(_request_body_definition, _context, _caller) do
    quote location: :keep do
      any()
    end
  end

  defp has_no_required_parameter?(definition, type) do
    definition
    |> Map.get("parameters", [])
    |> Enum.filter(&(&1["in"] == type))
    |> Enum.all?(&(&1["required"] != true))
  end

  @spec has_parameter?(map, String.t()) :: boolean()
  def has_parameter?(definition, type) do
    definition
    |> Map.get("parameters", [])
    |> Enum.filter(&(&1["in"] == type))
    |> case do
      [] -> false
      [_ | _] -> true
    end
  end

  @spec parameters_type(map, String.t(), OpenAPICompiler.Context.t(), boolean(), atom) ::
          Macro.t()
  def parameters_type(definition, type, context, allow_more, caller) do
    parameters =
      definition
      |> Map.get("parameters", [])
      |> Enum.filter(&(&1["in"] == type))

    {:%{}, [],
     Enum.map(parameters, fn parameter_definition ->
       optional_ast(
         parameter_definition["required"] != true,
         case type do
           "header" ->
             name_length_bytes = String.length(parameter_definition["name"]) * 8

             quote do
               <<_::unquote(name_length_bytes)>>
             end

           _other ->
             String.to_atom(parameter_definition["name"])
         end,
         case parameter_definition["schema"] do
           nil ->
             quote location: :keep do
               any()
             end

           schema ->
             Schema.type(schema, :write, context, caller)
         end
       )
     end) ++
       if allow_more do
         [
           optional_ast(
             true,
             quote location: :keep do
               String.t()
             end,
             quote location: :keep do
               any()
             end
           )
         ]
       else
         []
       end}
  end
end
