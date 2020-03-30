defmodule OpenAPICompiler.TypespecTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use OpenAPICompiler.IExCase, async: true

  import AssertValue

  describe "server_typespec/1" do
    setup tags do
      module_name = :"#{__MODULE__}.ServerTypespec"

      compile_local(
        tags.test,
        quote do
          defmodule unquote(module_name) do
            @moduledoc false

            use OpenAPICompiler,
              yml: """
              openapi: "3.0.0"
              info:
                version: 1.0.0
                title: Swagger Petstore
                license:
                  name: MIT
              servers:
                - url: "https://{env}.localhost:{port}"
                  variables:
                    env:
                      default: dev
                      enum: ['dev', 'test', 'prod']
                    port:
                      default: "8080"
              """
          end
        end
      )

      {:ok, module_name: module_name}
    end

    test "generates variables", %{module_name: module_name} do
      assert_value iex_t(module_name.server_parameters()) == """
                   @type server_parameters() :: %{
                           optional(:env) => :prod | :test | :dev,
                           optional(:port) => String.t()
                         }

                   """
    end
  end

  describe "api_response/2" do
    setup tags do
      module_name = :"#{__MODULE__}.ApiResponse"

      compile_local(
        tags.test,
        quote do
          defmodule unquote(module_name) do
            @moduledoc false

            use OpenAPICompiler,
              yml: """
              openapi: "3.0.0"
              info:
                version: 1.0.0
                title: Swagger Petstore
                license:
                  name: MIT
              servers:
                - url: "https://localhost"
              paths:
                /:
                  get:
                    responses:
                      '200':
                        description: 200 response
                        content:
                          application/json:
                            schema: 
                              type: string
              """
          end
        end
      )

      {:ok, module_name: module_name}
    end

    test "generates variables", %{module_name: module_name} do
      assert_value iex_h(module_name.get_root()) == """
                   * def get_root(client \\\\ %Tesla.Client{}, config)

                     @spec get_root(
                             client :: Tesla.Client.t(),
                             config :: %{
                               optional(:query) => %{optional(String.t()) => any()},
                               optional(:headers) => %{optional(String.t()) => any()},
                               optional(:path) => %{},
                               optional(:body) => any(),
                               optional(:server) => server_parameters(),
                               optional(:opts) => Tesla.Env.opts()
                             }
                           ) ::
                             {:ok, {200, String.t()}}
                             | {:error, {:unexpected_response, Tesla.Env.t()} | any()}

                   `GET` `/`



                   """
    end
  end
end
