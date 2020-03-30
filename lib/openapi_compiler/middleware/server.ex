defmodule OpenAPICompiler.Middleware.Server do
  @moduledoc false

  @behaviour Tesla.Middleware

  alias Tesla.Middleware.BaseUrl

  @impl Tesla.Middleware
  def call(%Tesla.Env{opts: opts, url: url} = env, next, server) do
    url
    |> URI.parse()
    |> case do
      %URI{scheme: scheme, host: host} when not is_nil(scheme) and not is_nil(host) ->
        Tesla.run(env, next)

      _ ->
        BaseUrl.call(env, next, replace_variables(server, opts))
    end
  end

  defp replace_variables(%{"url" => url} = server, opts) do
    UriTemplate.expand(
      url,
      server
      |> Map.get("variables", %{})
      |> Enum.map(fn {key, value} ->
        {key, value["default"]}
      end)
      |> Enum.reject(&is_nil(elem(&1, 1)))
      |> Map.new()
      |> Map.merge(Keyword.get(opts, :server_parameters, %{}))
    )
  end
end
