defmodule OpenAPICompiler.PathTest do
  @moduledoc false

  use ExUnit.Case
  use OpenAPICompiler.IExCase, async: true

  import AssertValue

  doctest OpenAPICompiler.Path

  @spec context(module :: atom) :: OpenAPICompiler.Context.t()
  def context(module),
    do:
      OpenAPICompiler.Context.create(
        [yml_path: Application.app_dir(:openapi_compiler, "priv/examples/internal.yaml")],
        module
      )

  @spec callback_context(module :: atom) :: OpenAPICompiler.Context.t()
  def callback_context(module),
    do:
      OpenAPICompiler.Context.create(
        [
          yml_path:
            Application.app_dir(
              :openapi_compiler,
              "priv/examples/openapi-specification/examples/v3.0/callback-example.yaml"
            ),
          server: %{"url" => "https://example.com"}
        ],
        module
      )

  describe "define_base_paths/1" do
    test "works", %{test: test} do
      module_name = :"#{__MODULE__}.BasePaths"

      compile_local(
        test,
        quote location: :keep do
          defmodule unquote(module_name) do
            @moduledoc false

            require OpenAPICompiler.Typespec.Api.Response

            OpenAPICompiler.Typespec.Api.Response.base_typespecs()

            require OpenAPICompiler.Path

            @type server_parameters :: any

            context = unquote(__MODULE__).context(__MODULE__)

            OpenAPICompiler.Path.define_base_paths(context)
          end
        end
      )

      assert_value iex_h(module_name.get_root()) ==
                     """
                     * def get_root(client \\\\ %Tesla.Client{}, config)

                       @spec get_root(client :: Tesla.Client.t(), config :: get_root_config()) ::
                               get_root_response()

                     `GET` `/`



                     """

      assert_value iex_h(module_name.list()) ==
                     """
                     * def list(client \\\\ %Tesla.Client{}, config)

                     delegate_to: OpenAPICompiler.PathTest.BasePaths.get_root/2


                     """
    end
  end

  describe "define_callbacks/1" do
    test "works", %{test: test} do
      module_name = :"#{__MODULE__}.Callbacks"

      compile_local(
        test,
        quote location: :keep do
          defmodule unquote(module_name) do
            @moduledoc false

            require OpenAPICompiler.Typespec.Api.Response

            OpenAPICompiler.Typespec.Api.Response.base_typespecs()

            require OpenAPICompiler.Path

            @type server_parameters :: any

            context = unquote(__MODULE__).callback_context(__MODULE__)

            OpenAPICompiler.Path.define_callbacks(context)
          end
        end
      )

      assert_value iex_h(module_name.get_root()) ==
                     "No documentation for OpenAPICompiler.PathTest.Callbacks.get_root was found\n"

      assert_value iex_h(module_name.list()) ==
                     "No documentation for OpenAPICompiler.PathTest.Callbacks.list was found\n"
    end
  end
end
