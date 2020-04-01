defmodule OpenAPICompiler.Typespec.Api.ConfigTest do
  @moduledoc false

  use ExUnit.Case
  use OpenAPICompiler.IExCase, async: true

  import OpenAPICompiler.Typespec.Api.Config
  import AssertValue

  doctest OpenAPICompiler.Typespec.Api.Config

  @context %OpenAPICompiler.Context{
    schema: nil,
    base_module: Api,
    components_schema_read_module: Read,
    components_schema_write_module: Write,
    external_resources: [],
    server: nil
  }

  @server_complex %{
    "url" => "https://{env}.localhost:{port}",
    "variables" => %{
      "env" => %{
        "default" => "dev",
        "enum" => ["dev", "test", "prod"]
      },
      "port" => %{
        "default" => "8080"
      }
    }
  }

  @server_simple %{"url" => "https://example.com"}

  @spec type_def_ast(type :: Macro.t()) :: Macro.t()
  def type_def_ast(type) do
    {:@, [], [{:type, [], [{:"::", [], [:type, type]}]}]}
  end

  describe "typespec/3" do
    test "works", %{test: test} do
      module_name = :"#{__MODULE__}.Specific"

      compile_local(
        test,
        quote location: :keep do
          defmodule unquote(module_name) do
            @moduledoc false

            require OpenAPICompiler.Typespec.Api.Config

            OpenAPICompiler.Typespec.Api.Config.typespec(
              :foo,
              %{},
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

      assert_value iex_t(module_name.foo()) == """
                   @type foo() :: %{
                           optional(:query) => %{optional(String.t()) => any()},
                           optional(:headers) => %{optional(String.t()) => any()},
                           optional(:opts) => Tesla.Env.opts()
                         }

                   """
    end
  end

  describe "type/3" do
    test "query optional" do
      assert_value %{
                     "parameters" => [
                       %{"in" => "query", "name" => "test", "schema" => %{"type" => "string"}}
                     ]
                   }
                   |> type(@context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:query) => %{optional(:test) => String.t(), optional(String.t()) => any()},
                             optional(:headers) => %{optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "query required" do
      assert_value %{
                     "parameters" => [
                       %{
                         "in" => "query",
                         "name" => "test",
                         "required" => true,
                         "schema" => %{"type" => "string"}
                       }
                     ]
                   }
                   |> type(@context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             :query => %{:test => String.t(), optional(String.t()) => any()},
                             optional(:headers) => %{optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "query missing" do
      assert_value %{}
                   |> type(@context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:query) => %{optional(String.t()) => any()},
                             optional(:headers) => %{optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "header optional" do
      assert_value %{
                     "parameters" => [
                       %{"in" => "header", "name" => "X-Test", "schema" => %{"type" => "string"}}
                     ]
                   }
                   |> type(@context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:query) => %{optional(String.t()) => any()},
                             optional(:headers) => %{optional(:\"X-Test\") => String.t(), optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "header required" do
      assert_value %{
                     "parameters" => [
                       %{
                         "in" => "header",
                         "name" => "X-Test",
                         "required" => true,
                         "schema" => %{"type" => "string"}
                       }
                     ]
                   }
                   |> type(@context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:query) => %{optional(String.t()) => any()},
                             :headers => %{:\"X-Test\" => String.t(), optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "header missing" do
      assert_value %{}
                   |> type(@context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:query) => %{optional(String.t()) => any()},
                             optional(:headers) => %{optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "path optional" do
      assert_value %{
                     "parameters" => [
                       %{"in" => "path", "name" => "X-Test", "schema" => %{"type" => "string"}}
                     ]
                   }
                   |> type(@context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:path) => %{optional(:\"X-Test\") => String.t()},
                             optional(:query) => %{optional(String.t()) => any()},
                             optional(:headers) => %{optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "path required" do
      assert_value %{
                     "parameters" => [
                       %{
                         "in" => "path",
                         "name" => "X-Test",
                         "required" => true,
                         "schema" => %{"type" => "string"}
                       }
                     ]
                   }
                   |> type(@context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             :path => %{\"X-Test\": String.t()},
                             optional(:query) => %{optional(String.t()) => any()},
                             optional(:headers) => %{optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "path missing" do
      assert_value %{}
                   |> type(@context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:query) => %{optional(String.t()) => any()},
                             optional(:headers) => %{optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "requestBody optional" do
      assert_value %{
                     "requestBody" => %{
                       "content" => %{
                         "application/json" => %{
                           "schema" => %{
                             "type" => "string"
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
                     @type :type :: %{
                             optional(:body) => String.t(),
                             optional(:query) => %{optional(String.t()) => any()},
                             optional(:headers) => %{optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "requestBody multiple" do
      assert_value %{
                     "requestBody" => %{
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
                     }
                   }
                   |> type(@context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => integer() | String.t(),
                             optional(:query) => %{optional(String.t()) => any()},
                             optional(:headers) => %{optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "requestBody required" do
      assert_value %{
                     "requestBody" => %{
                       "required" => true,
                       "content" => %{
                         "application/json" => %{
                           "schema" => %{
                             "type" => "string"
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
                     @type :type :: %{
                             :body => String.t(),
                             optional(:query) => %{optional(String.t()) => any()},
                             optional(:headers) => %{optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "requestBody missing" do
      assert_value %{}
                   |> type(@context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:query) => %{optional(String.t()) => any()},
                             optional(:headers) => %{optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "server has variables" do
      assert_value %{}
                   |> type(
                     %OpenAPICompiler.Context{@context | server: @server_complex},
                     __MODULE__
                   )
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:server) => Api.server_parameters(),
                             optional(:query) => %{optional(String.t()) => any()},
                             optional(:headers) => %{optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "server has no variables" do
      assert_value %{}
                   |> type(
                     %OpenAPICompiler.Context{@context | server: @server_simple},
                     __MODULE__
                   )
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:query) => %{optional(String.t()) => any()},
                             optional(:headers) => %{optional(String.t()) => any()},
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end
  end
end
