defmodule OpenAPICompiler.Typespec.Api.Config do
  @moduledoc false

  import OpenAPICompiler.Typespec.Utility

  alias OpenAPICompiler.Typespec.Schema
  alias OpenAPICompiler.Typespec.Server

  defmacro typespec(name, definition, context) do
    quote location: :keep,
          bind_quoted: [name: name, definition: definition, context: context, caller: __MODULE__] do
      type = caller.type(definition, context, __MODULE__)

      @type unquote(name)() :: unquote(type)
    end
  end

  @spec type(definition :: map, context :: OpenAPICompiler.Context.t(), caller :: atom) ::
          Macro.t()
  def type(
        definition,
        %OpenAPICompiler.Context{server: global_server} = context,
        caller
      ) do
    {:%{}, [],
     [
       optional_ast(
         has_no_required_parameter?(definition, "query"),
         :query,
         parameters_type(definition, "query", context, true, caller)
       ),
       optional_ast(
         has_no_required_parameter?(definition, "header"),
         :headers,
         parameters_type(definition, "header", context, true, caller)
       ),
       optional_ast(
         true,
         :opts,
         quote location: :keep do
           Tesla.Env.opts()
         end
       )
     ]
     |> add_path(definition, context, caller)
     |> add_request_body(definition, context, caller)
     |> add_server(definition["server"] || global_server, context, caller)}
  end

  defp add_request_body(config, definition, context, caller)

  defp add_request_body(
         config,
         %{"requestBody" => %{} = request_body_definition},
         context,
         caller
       ) do
    [
      optional_ast(
        request_body_definition["required"] != true,
        :body,
        request_body_type(request_body_definition, context, caller)
      )
      | config
    ]
  end

  defp add_request_body(config, _, _, _), do: config

  defp add_path(config, definition, context, caller) do
    if has_parameter?(definition, "path") do
      [
        optional_ast(
          has_no_required_parameter?(definition, "path"),
          :path,
          parameters_type(definition, "path", context, false, caller)
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

            _ ->
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

  defp add_server(_, _, _, _) do
    # TODO: Implement
    raise "Only one global server is supported"
  end

  defp request_body_type(request_body_definition, context, caller)

  defp request_body_type(%{"content" => %{} = content}, context, caller) do
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

  defp request_body_type(_, _, _) do
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

  defp has_parameter?(definition, type) do
    definition
    |> Map.get("parameters", [])
    |> Enum.filter(&(&1["in"] == type))
    |> case do
      [] -> false
      [_ | _] -> true
    end
  end

  defp parameters_type(definition, type, context, allow_more, caller) do
    parameters =
      definition
      |> Map.get("parameters", [])
      |> Enum.filter(&(&1["in"] == type))

    {:%{}, [],
     Enum.map(parameters, fn parameter_definition ->
       optional_ast(
         parameter_definition["required"] != true,
         String.to_atom(parameter_definition["name"]),
         Schema.type(parameter_definition["schema"], :write, context, caller)
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
