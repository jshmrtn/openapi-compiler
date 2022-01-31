defmodule OpenAPICompiler.Middleware.PathParams do
  @moduledoc false

  @behaviour Tesla.Middleware

  @impl Tesla.Middleware
  def call(%Tesla.Env{opts: opts} = env, next, _) do
    env
    |> case do
      %Tesla.Env{url: %UriTemplate{} = path_template} ->
        %Tesla.Env{
          env
          | url: UriTemplate.expand(path_template, Keyword.get(opts, :path_parameters, %{})),
            opts: [{:path_template, path_template} | opts]
        }

      _env ->
        env
    end
    |> Tesla.run(next)
  end
end
