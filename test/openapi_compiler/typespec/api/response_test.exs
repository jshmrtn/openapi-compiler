defmodule OpenAPICompiler.Typespec.Api.ResponseTest do
  @moduledoc false

  use ExUnit.Case
  use OpenAPICompiler.IExCase, async: true

  import OpenAPICompiler.Typespec.Api.Response
  import AssertValue

  doctest OpenAPICompiler.Typespec.Api.Response

  @context %OpenAPICompiler.Context{
    schema: nil,
    base_module: Api,
    components_schema_read_module: Read,
    components_schema_write_module: Write,
    external_resources: [],
    server: nil
  }

  @spec type_def_ast(type :: Macro.t()) :: Macro.t()
  def type_def_ast(type) do
    {:@, [], [{:type, [], [{:"::", [], [:type, type]}]}]}
  end

  describe "base_typespecs/0" do
    test "works", %{test: test} do
      module_name = :"#{__MODULE__}.Base"

      compile_local(
        test,
        quote location: :keep do
          defmodule unquote(module_name) do
            @moduledoc false

            require OpenAPICompiler.Typespec.Api.Response

            OpenAPICompiler.Typespec.Api.Response.base_typespecs()
          end
        end
      )

      assert_value iex_t(module_name.response()) ==
                     "Beam code not available for OpenAPICompiler.Typespec.Api.ResponseTest.Base or debug info is missing, cannot load typespecs\n"
    end
  end

  describe "typespec/3" do
    test "works", %{test: test} do
      module_name = :"#{__MODULE__}.Specific"

      compile_local(
        test,
        quote location: :keep do
          defmodule unquote(module_name) do
            @moduledoc false

            require OpenAPICompiler.Typespec.Api.Response

            OpenAPICompiler.Typespec.Api.Response.base_typespecs()

            OpenAPICompiler.Typespec.Api.Response.typespec(
              :foo,
              %{
                "responses" => %{
                  "200" => %{
                    "description" => "test",
                    "content" => %{
                      "application/json" => %{
                        "schema" => %{
                          "type" => "string"
                        }
                      }
                    }
                  }
                }
              },
              %OpenAPICompiler.Context{
                schema: nil,
                base_module: Api,
                components_schema_read_module: Read,
                components_schema_write_module: Write,
                external_resources: [],
                server: nil
              }
            )
          end
        end
      )

      assert_value iex_t(module_name.foo()) ==
                     "Beam code not available for OpenAPICompiler.Typespec.Api.ResponseTest.Specific or debug info is missing, cannot load typespecs\n"
    end
  end

  describe "type/3" do
    test "works" do
      assert_value %{
                     "responses" => %{
                       "200" => %{
                         "description" => "test",
                         "content" => %{
                           "application/json" => %{
                             "schema" => %{
                               "type" => "string"
                             }
                           },
                           "application/other" => %{
                             "schema" => %{
                               "type" => "integer"
                             }
                           }
                         }
                       },
                       400 => %{
                         "description" => "test",
                         "content" => %{
                           "application/json" => %{
                             "schema" => %{
                               "type" => "number"
                             }
                           }
                         }
                       },
                       "default" => %{
                         "description" => "fallback",
                         "content" => %{
                           "application/json" => %{
                             "schema" => %{
                               "type" => "boolean"
                             }
                           }
                         }
                       }
                     }
                   }
                   |> type(@context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type ::
                             {Tesla.Env.status(), boolean(), Tesla.Env.t()}
                             | {200, integer(), Tesla.Env.t()}
                             | {200, String.t(), Tesla.Env.t()}
                             | {400, float() | integer(), Tesla.Env.t()}<NOEOL>
                     """
    end

    test "works empty" do
      assert_value %{}
                   |> type(@context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: any()"
    end
  end
end
