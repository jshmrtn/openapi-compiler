defmodule OpenAPICompiler.Middleware.Server do
  @moduledoc false

  @behaviour Tesla.Middleware

  alias OpenAPICompiler.Context
  alias Tesla.Middleware.BaseUrl

  @impl Tesla.Middleware
  def call(%Tesla.Env{opts: opts, url: url} = env, next, context) do
    url
    |> URI.parse()
    |> case do
      %URI{scheme: scheme, host: host} when not is_nil(scheme) and not is_nil(host) ->
        Tesla.run(env, next)

      _uri ->
        server = Context.load_server(context)
        BaseUrl.call(env, next, replace_variables(server, opts))
    end
  end

  defp replace_variables(%{"url" => url} = server, opts) do
    user_opts =
      opts
      |> Keyword.get(:server_parameters, %{})
      |> normalize_keys

    UriTemplate.expand(
      url,
      server
      |> Map.get("variables", %{})
      |> Enum.map(fn {key, value} ->
        {key, value["default"]}
      end)
      |> Enum.reject(&is_nil(elem(&1, 1)))
      |> normalize_keys
      |> Keyword.merge(user_opts)
    )
  end

  defp normalize_keys(variables) do
    Enum.map(variables, fn
      {key, value} when is_atom(key) -> {key, value}
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
    end)
  end
end
