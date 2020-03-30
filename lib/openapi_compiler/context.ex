defmodule OpenAPICompiler.Context do
  @moduledoc false

  @enforce_keys [
    :schema,
    :base_module,
    :components_schema_read_module,
    :components_schema_write_module,
    :external_resources,
    :server
  ]

  defstruct [
    :schema,
    :base_module,
    :components_schema_read_module,
    :components_schema_write_module,
    :server,
    external_resources: []
  ]

  defimpl Inspect do
    def inspect(%OpenAPICompiler.Context{base_module: module}, _opts) do
      "#OpenAPICompiler.Context<#{module}>"
    end
  end

  def create(opts, module) do
    struct!(
      __MODULE__,
      opts
      |> Map.new()
      |> normalize_config_yml
      |> normalize_config_json
      |> case do
        %{schema: schema} = opts ->
          %{opts | schema: lookup_refs(schema)}

        _ ->
          raise "Schema not provided"
      end
      |> lookup_server
      |> Map.put_new(:base_module, module)
      |> Map.put_new(:components_schema_read_module, Module.concat(module, Schema.Read))
      |> Map.put_new(:components_schema_write_module, Module.concat(module, Schema.Write))
    )
  end

  defp normalize_config_yml(%{yml_path: yml_path} = opts) do
    opts
    |> Map.drop([:yml_path])
    |> Map.update(:external_resources, [yml_path], &[yml_path | &1])
    |> Map.put_new_lazy(:schema, fn ->
      Application.ensure_all_started(:yamerl)

      yml_path
      |> String.to_charlist()
      |> :yamerl.decode_file(str_node_as_binary: true)
      |> to_map
    end)
  end

  defp normalize_config_yml(other), do: other

  defp normalize_config_json(%{json_path: json_path} = opts) do
    opts
    |> Map.drop([:json_path])
    |> Map.update(:external_resources, [json_path], &[json_path | &1])
    |> Map.put_new_lazy(:schema, fn ->
      Application.ensure_all_started(:jason)

      json =
        json_path
        |> File.read!()
        |> Jason.decode!()

      [json]
    end)
  end

  defp normalize_config_json(other), do: other

  defp to_map([{_key, _value} | _] = structure),
    do: structure |> Enum.map(&{elem(&1, 0), to_map(elem(&1, 1))}) |> Map.new()

  defp to_map([]), do: %{}

  defp to_map([_ | _] = structure),
    do: structure |> Enum.map(&to_map/1)

  defp to_map(other), do: other

  defp lookup_refs(schema), do: lookup_refs(schema, schema, 10)

  defp lookup_refs(type, _, 0), do: type

  defp lookup_refs(%{"$ref" => path}, roots, depth) do
    "#/" <> local_path = path

    parts = String.split(local_path, "/")

    roots
    |> Enum.find_value(&get_in(&1, parts))
    |> case do
      nil -> raise "not found"
      found -> Map.put(found, :__ref__, parts)
    end
    |> lookup_refs(roots, depth - 1)
  end

  defp lookup_refs(%{} = node, roots, depth) do
    node
    |> Enum.map(&{elem(&1, 0), lookup_refs(elem(&1, 1), roots, depth)})
    |> Map.new()
  end

  defp lookup_refs([_ | _] = node, roots, depth) do
    Enum.map(node, &lookup_refs(&1, roots, depth))
  end

  defp lookup_refs(other, _, _), do: other

  defp lookup_server(%{schema: schema} = opts) do
    servers =
      schema
      |> Enum.map(& &1["servers"])
      |> Enum.reject(&is_nil/1)
      |> List.flatten()

    case {servers, opts[:server]} do
      {[], nil} ->
        raise "No server was defined"

      {_, %{}} ->
        opts

      {[server], nil} ->
        Map.put(opts, :server, server)

      {servers, server_index}
      when is_integer(server_index) and server_index >= 0 and server_index < length(servers) ->
        Map.put(opts, :server, servers[server_index])

      {servers, server_selector} when is_binary(server_selector) ->
        servers
        |> Enum.filter(&(&1["description"] == server_selector or &1["url"] == server_selector))
        |> case do
          [] -> raise "Server #{server_selector} not found"
          [server | _] -> Map.put(opts, :server, server)
        end
    end
  end
end
