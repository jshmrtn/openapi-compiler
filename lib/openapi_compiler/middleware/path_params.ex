defmodule OpenAPICompiler.Middleware.PathParams do
  @moduledoc false

  @behaviour Tesla.Middleware

  @impl Tesla.Middleware
  def call(%Tesla.Env{opts: opts} = env, next, _) do
    env
    |> Map.update!(:url, fn
      %UriTemplate{} = path_template ->
        UriTemplate.expand(path_template, Keyword.get(opts, :path_parameters, %{}))

      url ->
        url
    end)
    |> Tesla.run(next)
  end
end
