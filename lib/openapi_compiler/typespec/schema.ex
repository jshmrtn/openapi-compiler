defmodule OpenAPICompiler.Typespec.Schema do
  @moduledoc false

  import OpenAPICompiler.Typespec.Utility

  defmacro typespec(name, value, mode, context) do
    quote location: :keep,
          bind_quoted: [name: name, mode: mode, value: value, context: context] do
      name = OpenAPICompiler.Typespec.Utility.type_name(name)
      typespec = OpenAPICompiler.Typespec.Schema.type(value, mode, context, __MODULE__)

      for type <- [value | value["allOf"] || []] do
        case Map.fetch(type, "description") do
          :error -> nil
          {:ok, desc} -> @typedoc desc
        end
      end

      @type unquote(name)() :: unquote(typespec)
    end
  end

  @spec type(
          definition :: map,
          mode :: :read | :write,
          context :: OpenAPICompiler.Context.t(),
          caller :: atom
        ) :: Macro.t()
  def type(definition, mode, context, caller)

  def type(%{"nullable" => true} = type, mode, context, caller) do
    {:|, [], [type(%{type | "nullable" => false}, mode, context, caller), nil]}
  end

  def type(
        %{__ref__: ["components", "schemas", name]},
        :read,
        %OpenAPICompiler.Context{
          components_schema_read_module: module
        },
        caller
      ) do
    case caller do
      ^module ->
        quote location: :keep do
          unquote(type_name(name))()
        end

      _other ->
        quote location: :keep do
          unquote(module).unquote(type_name(name))
        end
    end
  end

  def type(
        %{__ref__: ["components", "schemas", name]},
        :write,
        %OpenAPICompiler.Context{
          components_schema_write_module: module
        },
        caller
      ) do
    case caller do
      ^module ->
        quote location: :keep do
          unquote(type_name(name))()
        end

      _other ->
        quote location: :keep do
          unquote(module).unquote(type_name(name))
        end
    end
  end

  def type(%{"type" => "string", "format" => binary_format}, _mode, _context, _caller)
      when binary_format in ["byte", "binary"] do
    quote location: :keep do
      binary()
    end
  end

  def type(%{"type" => "string", "enum" => options}, :write, _context, _caller) do
    options
    |> Enum.map(&String.to_atom/1)
    |> Enum.reduce(nil, fn
      value, nil -> value
      value, acc -> {:|, [], [value, acc]}
    end)
  end

  def type(%{"type" => "string"}, _mode, _context, _caller) do
    quote location: :keep do
      String.t()
    end
  end

  def type(%{"type" => "boolean"}, _mode, _context, _caller) do
    quote location: :keep do
      boolean()
    end
  end

  def type(%{"type" => "number", "format" => format}, _mode, _context, _caller)
      when format in ["float", "double"] do
    quote location: :keep do
      float()
    end
  end

  def type(%{"type" => "number"}, _mode, _context, _caller_) do
    quote location: :keep do
      float() | integer()
    end
  end

  def type(%{"type" => "integer"}, _mode, _context, _caller) do
    quote location: :keep do
      integer()
    end
  end

  def type(%{"type" => "array", "items" => items}, mode, context, caller) do
    quote location: :keep do
      list(unquote(type(items, mode, context, caller)))
    end
  end

  def type(%{"type" => "array"}, _mode, _context, _caller) do
    quote location: :keep do
      list()
    end
  end

  def type(
        %{
          "oneOf" => options,
          "discriminator" => %{"propertyName" => discriminator_property_name} = discriminator
        },
        mode,
        context,
        caller
      ) do
    options
    |> Enum.map(fn option ->
      merge_definitions([
        option,
        %{
          "type" => "object",
          "properties" => %{
            discriminator_property_name => %{
              "type" => "string",
              "enum" => [discriminator_name(option, discriminator)]
            }
          },
          "required" => [discriminator_property_name]
        }
      ])
    end)
    |> Enum.map(&type(&1, mode, context, caller))
    |> Enum.reduce(nil, fn
      value, nil -> value
      value, acc -> {:|, [], [value, acc]}
    end)
  end

  def type(%{"oneOf" => options}, mode, context, caller) do
    options
    |> Enum.map(&type(&1, mode, context, caller))
    |> Enum.reduce(nil, fn
      value, nil -> value
      value, acc -> {:|, [], [value, acc]}
    end)
  end

  def type(%{"allOf" => requirements}, mode, context, caller) do
    requirements
    |> merge_definitions
    |> type(mode, context, caller)
  end

  def type(%{"anyOf" => options}, mode, context, caller) do
    options
    |> merge_definitions
    |> Map.drop(["required"])
    |> type(mode, context, caller)
  end

  def type(
        %{"type" => "object", "properties" => properties} = type,
        mode,
        context,
        caller
      ) do
    required = Map.get(type, "required", [])

    {:%{}, [],
     properties
     |> Enum.map(fn {property_name, property_definition} ->
       property(
         property_definition,
         property_name,
         mode,
         Enum.member?(required, property_name),
         context,
         caller
       )
     end)
     |> Enum.reject(&is_nil/1)}
  end

  def type(%{"type" => "object"}, _mode, _context, _caller) do
    quote location: :keep do
      map()
    end
  end

  def type(%{"type" => type} = definition, _mode, context, _caller) do
    raise OpenAPICompiler.UnknownTypeError, definition: definition, type: type, context: context
  end

  def type(%{} = type, mode, context, caller) do
    type
    |> Map.put("type", "object")
    |> type(mode, context, caller)
  end

  defp merge_definitions(definitions) do
    definitions
    |> Enum.map(fn
      %{"allOf" => options} -> merge_definitions(options)
      %{"anyOf" => options} -> options |> merge_definitions() |> Map.drop(["required"])
      other -> other
    end)
    |> Enum.reduce(%{}, fn value, acc ->
      Map.merge(acc, value, fn
        _key, %{} = old_value, %{} = new_value -> Map.merge(old_value, new_value)
        _key, [_ | _] = old_value, [_ | _] = new_value -> old_value ++ new_value
        _key, _old_value, new_value -> new_value
      end)
    end)
    |> Map.drop([:__ref__])
  end

  defp property(definition, name, mode, required, context, caller)

  defp property(%{"allOf" => requirements}, name, mode, required, context, caller) do
    requirements
    |> merge_definitions()
    |> property(name, mode, required, context, caller)
  end

  defp property(%{"readOnly" => true}, _name, :write, _required, _context, _caller) do
    nil
  end

  defp property(%{"writeOnly" => true}, _name, :read, _required, _context, _caller) do
    nil
  end

  defp property(definition, name, mode, true, context, caller) do
    {String.to_atom(name), type(definition, mode, context, caller)}
  end

  defp property(definition, name, mode, false, context, caller) do
    {{:optional, [], [String.to_atom(name)]}, type(definition, mode, context, caller)}
  end

  defp discriminator_name(option_definition, discriminator)

  defp discriminator_name(%{__ref__: ["components", "schemas", name] = search_path}, %{
         "mapping" => mapping
       }) do
    {name, _} =
      mapping
      |> Enum.map(fn {name, "#/" <> ref} ->
        {name, String.split(ref, "/")}
      end)
      |> Enum.find({name, search_path}, fn
        {_name, path} when search_path == path -> true
        {_name, _path} -> false
      end)

    name
  end

  defp discriminator_name(%{__ref__: ["components", "schemas", name]}, _search_path) do
    name
  end
end
