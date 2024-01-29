defmodule OpenAPICompiler.Context do
  @moduledoc false

  @type t :: %__MODULE__{
          schema: [map],
          base_module: atom,
          components_schema_read_module: atom,
          components_schema_write_module: atom,
          external_resources: [Path.t()],
          server: map | (-> map)
        }

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

  @spec create(opts :: Enum.t(), module :: atom) :: t
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

        _opts ->
          raise OpenAPICompiler.InvalidOptsError, message: "Schema not provided"
      end
      |> lookup_server
      |> Map.put_new(:base_module, module)
      |> Map.put_new(:components_schema_read_module, Module.concat(module, Schema.Read))
      |> Map.put_new(:components_schema_write_module, Module.concat(module, Schema.Write))
      |> Map.put_new(:external_resources, [])
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

  defp normalize_config_yml(%{yml: yml} = opts) do
    opts
    |> Map.drop([:yml])
    |> Map.put_new_lazy(:schema, fn ->
      Application.ensure_all_started(:yamerl)

      yml
      |> String.to_charlist()
      |> :yamerl.decode(str_node_as_binary: true)
      |> to_map
    end)
  end

  defp normalize_config_yml(other), do: other

  defp normalize_config_json(%{json: json} = opts) do
    opts
    |> Map.drop([:json])
    |> Map.put_new_lazy(:schema, fn ->
      Application.ensure_all_started(:jason)

      [Jason.decode!(json)]
    end)
  end

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
    do: Enum.map(structure, &to_map/1)

  defp to_map(other), do: other

  defp lookup_refs(schema), do: lookup_refs(schema, schema, 1000)

  defp lookup_refs(_schema, roots, 0), do: raise(OpenAPICompiler.CircularRefError, schema: roots)

  defp lookup_refs(%{"$ref" => path}, roots, depth) do
    "#/" <> local_path = path

    parts = String.split(local_path, "/")

    roots
    |> Enum.find_value(&get_in(&1, parts))
    |> case do
      nil -> raise OpenAPICompiler.RefNotFoundError, ref: path, schema: roots
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

  defp lookup_refs(other, _roots, _depth), do: other

  defp lookup_server(opts)
  defp lookup_server(%{server: server} = opts) when is_function(server, 0), do: opts

  defp lookup_server(%{schema: schema} = opts) do
    case validate_server(schema, opts[:server]) do
      {:ok, server} -> Map.put(opts, :server, server)
      {:error, message} -> raise OpenAPICompiler.InvalidOptsError, message: message
    end
  end

  @spec load_server(context :: t()) :: map
  def load_server(context)
  def load_server(%__MODULE__{server: server}) when is_map(server), do: server

  def load_server(%__MODULE__{server: server, schema: schema}) when is_function(server, 0) do
    case validate_server(schema, server.()) do
      {:ok, server} -> server
      {:error, message} -> raise OpenAPICompiler.InvalidOptsError, message: message
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp validate_server(schema, server) do
    servers =
      schema
      |> Enum.map(& &1["servers"])
      |> Enum.reject(&is_nil/1)
      |> List.flatten()

    case {servers, server} do
      {[], nil} ->
        {:error, "No server was defined"}

      {[_first, _second | _others], nil} ->
        {:error, "No server was defined"}

      {_servers, %{} = server} ->
        {:ok, server}

      {[server], nil} ->
        {:ok, server}

      {servers, server_index}
      when is_integer(server_index) and server_index >= 0 and server_index < length(servers) ->
        {:ok, Enum.at(servers, server_index)}

      {servers, server_selector} when is_binary(server_selector) ->
        servers
        |> Enum.find(&(&1["description"] == server_selector or &1["url"] == server_selector))
        |> case do
          nil ->
            {:error, "Server #{server_selector} not found"}

          server ->
            {:ok, server}
        end
    end
  end

  defimpl Inspect do
    @spec inspect(input :: OpenAPICompiler.Context.t(), opts :: Inspect.Opts.t()) ::
            Inspect.Algebra.t()
    def inspect(%OpenAPICompiler.Context{base_module: module}, _opts) do
      "#OpenAPICompiler.Context<#{module}>"
    end
  end
end
