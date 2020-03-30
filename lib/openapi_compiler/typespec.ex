defmodule OpenAPICompiler.Typespec do
  @moduledoc false

  require Logger

  defmacro type(name, value, read_or_write, context) do
    quote location: :keep,
          bind_quoted: [name: name, read_or_write: read_or_write, value: value, context: context] do
      name = OpenAPICompiler.Typespec.type_name(name)
      typespec = OpenAPICompiler.Typespec.typespec(value, read_or_write, context)

      for type <- [value | value["allOf"] || []] do
        case Map.fetch(type, "description") do
          :error -> nil
          {:ok, desc} -> @typedoc desc
        end
      end

      @type unquote(name)() :: unquote(typespec)
    end
  end

  def api_response(definition, context) do
    definition
    |> Map.get("responses", %{})
    |> Enum.flat_map(fn {code, media_types} ->
      media_types
      |> Map.get("content", %{})
      |> Enum.map(fn
        {_media_type, media_type_definition = %{}} ->
          media_type_definition["schema"]

        _ ->
          nil
      end)
      |> Enum.uniq()
      |> Enum.map(&{code, &1})
      |> case do
        [] -> [{code, nil}]
        other -> other
      end
    end)
    |> Enum.map(fn
      {code, nil} ->
        {code,
         quote location: :keep do
           any()
         end}

      {code, type} ->
        {code, typespec(type, :read, context)}
    end)
    |> Enum.map(fn
      {"default", typespec} ->
        quote location: :keep do
          {Tesla.Env.status(), unquote(typespec)}
        end

      {code, typespec} ->
        code = String.to_integer(code)

        quote location: :keep do
          {unquote(code), unquote(typespec)}
        end
    end)
    |> Enum.reduce(
      quote location: :keep do
        any()
      end,
      fn
        value, {:any, _, _} -> value
        value, acc -> {:|, [], [value, acc]}
      end
    )
  end

  def api_config(definition, %OpenAPICompiler.Context{base_module: base_module} = context) do
    {:%{}, [],
     [
       optional?(
         has_no_required_parameter?(definition, "query"),
         :query,
         parameters_type(definition, "query", context, true)
       ),
       optional?(
         has_no_required_parameter?(definition, "header"),
         :headers,
         parameters_type(definition, "header", context, true)
       ),
       optional?(
         has_no_required_parameter?(definition, "path"),
         :path,
         parameters_type(definition, "path", context, false)
       ),
       optional?(
         definition["requestBody"]["required"] != true,
         :body,
         request_body_type(definition, context)
       ),
       optional?(
         true,
         :server,
         quote location: :keep do
           unquote(base_module).server_parameters()
         end
       ),
       optional?(
         true,
         :opts,
         quote location: :keep do
           Tesla.Env.opts()
         end
       )
     ]}
  end

  defp request_body_type(definition, context) do
    (definition["requestBody"]["content"] || %{})
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
        typespec(schema, :write, context)
    end)
    |> Kernel.++(
      if Map.has_key?(definition["requestBody"]["content"] || %{}, "multipart/form-data") do
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
      quote location: :keep do
        any()
      end,
      fn
        value, {:any, _, _} -> value
        value, acc -> {:|, [], [value, acc]}
      end
    )
  end

  defp has_no_required_parameter?(definition, type) do
    definition
    |> Map.get("parameters", [])
    |> Enum.filter(&(&1["in"] == type))
    |> Enum.all?(&(&1["required"] != true))
  end

  defp parameters_type(definition, type, context, allow_more) do
    parameters =
      definition
      |> Map.get("parameters", [])
      |> Enum.filter(&(&1["in"] == type))

    {:%{}, [],
     Enum.map(parameters, fn parameter_definition ->
       optional?(
         parameter_definition["required"] != true,
         String.to_atom(parameter_definition["name"]),
         typespec(parameter_definition["schema"], :write, context)
       )
     end) ++
       if allow_more do
         [
           optional?(
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

  defmacro server_typespec(context) do
    quote location: :keep, bind_quoted: [context: context, caller: __MODULE__] do
      %OpenAPICompiler.Context{server: server} = context
      server_parameters_type = caller.server_type(server, context)
      @type server_parameters :: unquote(server_parameters_type)
    end
  end

  def server_type(%{"variables" => variables}, context) do
    {:%{}, [],
     Enum.map(variables, fn {name, definition} ->
       optional?(
         true,
         String.to_atom(name),
         definition |> Map.put("type", "string") |> typespec(:write, context)
       )
     end)}
  end

  def server_type(_server, _context) do
    quote location: :keep do
      %{}
    end
  end

  defp optional?(false, name, type) do
    {name, type}
  end

  defp optional?(true, name, type) do
    {{:optional, [], [name]}, type}
  end

  def typespec(type, read_or_write, context)

  def typespec(%{"nullable" => true} = type, read_or_write, context) do
    {:|, [], [typespec(%{type | "nullable" => false}, read_or_write, context), nil]}
  end

  def typespec(%{__ref__: ["components", "schemas", name]}, :read, %{
        components_schema_read_module: module
      }) do
    quote location: :keep do
      unquote(module).unquote(type_name(name))
    end
  end

  def typespec(%{__ref__: ["components", "schemas", name]}, :write, %{
        components_schema_write_module: module
      }) do
    quote location: :keep do
      unquote(module).unquote(type_name(name))
    end
  end

  def typespec(%{"type" => "string", "format" => binary_format}, _, _)
      when binary_format in ["byte", "binary"] do
    quote location: :keep do
      binary()
    end
  end

  def typespec(%{"type" => "string", "enum" => options}, :write, _) do
    options
    |> Enum.map(&String.to_atom/1)
    |> Enum.reduce(nil, fn
      value, nil -> value
      value, acc -> {:|, [], [value, acc]}
    end)
  end

  def typespec(%{"type" => "string"}, _, _) do
    quote location: :keep do
      String.t()
    end
  end

  def typespec(%{"type" => "boolean"}, _, _) do
    quote location: :keep do
      boolean()
    end
  end

  def typespec(%{"type" => "number", "format" => format}, _, _)
      when format in ["float", "double"] do
    quote location: :keep do
      float()
    end
  end

  def typespec(%{"type" => "number"}, _, _) do
    quote location: :keep do
      float() | integer()
    end
  end

  def typespec(%{"type" => "integer"}, _, _) do
    quote location: :keep do
      integer()
    end
  end

  def typespec(%{"type" => "object", "properties" => properties} = type, read_or_write, context) do
    required = Map.get(type, "required", [])

    {:%{}, [],
     properties
     |> Enum.map(fn {property_name, property_definition} ->
       property(
         property_name,
         property_definition,
         read_or_write,
         Enum.member?(required, property_name),
         context
       )
     end)
     |> Enum.reject(&is_nil/1)}
  end

  def typespec(%{"type" => "object"}, _, _) do
    quote location: :keep do
      map()
    end
  end

  def typespec(%{"type" => "array", "items" => items}, read_or_write, context) do
    quote location: :keep do
      list(unquote(typespec(items, read_or_write, context)))
    end
  end

  def typespec(%{"type" => "array"}, _, _) do
    quote location: :keep do
      list()
    end
  end

  def typespec(%{"oneOf" => options}, read_or_write, context) do
    options
    |> Enum.map(&typespec(&1, read_or_write, context))
    |> Enum.reduce(nil, fn
      value, nil -> value
      value, acc -> {:|, [], [value, acc]}
    end)
  end

  def typespec(%{"allOf" => requirements}, read_or_write, context) do
    requirements
    |> Enum.reduce(%{}, fn value, acc ->
      Map.merge(acc, value, fn
        _key, %{} = old_value, %{} = new_value -> Map.merge(old_value, new_value)
        _key, [_ | _] = old_value, [_ | _] = new_value -> old_value ++ new_value
        _key, _old_value, new_value -> new_value
      end)
    end)
    |> Map.drop([:__ref__])
    |> typespec(read_or_write, context)
  end

  def typespec(%{"type" => _} = type, _, _) do
    raise "Unknown #{inspect(type)}"
  end

  def typespec(%{} = type, read_or_write, context) do
    type
    |> Map.put("type", "object")
    |> typespec(read_or_write, context)
  end

  def type_name(name) do
    name
    |> Macro.underscore()
    |> String.to_atom()
  end

  defp property(name, definition, read_or_write, required, context)

  defp property(_, %{"readOnly" => true}, :write, _, _) do
    nil
  end

  defp property(_, %{"writeOnly" => true}, :read, _, _) do
    nil
  end

  defp property(name, definition, read_or_write, true, context) do
    {String.to_atom(name), typespec(definition, read_or_write, context)}
  end

  defp property(name, definition, read_or_write, false, context) do
    {{:optional, [], [String.to_atom(name)]}, typespec(definition, read_or_write, context)}
  end
end
