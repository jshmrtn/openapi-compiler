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
                           optional(:body) => any(),
                           optional(:query) => foo_query(),
                           optional(:headers) => foo_header(),
                           optional(:opts) => Tesla.Env.opts()
                         }
      
                   """
    end
  end

  describe "type/4" do
    test "query optional" do
      assert_value %{
                     "parameters" => [
                       %{"in" => "query", "name" => "test", "schema" => %{"type" => "string"}}
                     ]
                   }
                   |> type(:test, @context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => any(),
                             optional(:query) => test_query(),
                             optional(:headers) => test_header(),
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
                   |> type(:test, @context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => any(),
                             :query => test_query(),
                             optional(:headers) => test_header(),
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "query missing" do
      assert_value %{}
                   |> type(:test, @context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => any(),
                             optional(:query) => test_query(),
                             optional(:headers) => test_header(),
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
                   |> type(:test, @context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => any(),
                             optional(:query) => test_query(),
                             optional(:headers) => test_header(),
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
                   |> type(:test, @context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => any(),
                             optional(:query) => test_query(),
                             :headers => test_header(),
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "header missing" do
      assert_value %{}
                   |> type(:test, @context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => any(),
                             optional(:query) => test_query(),
                             optional(:headers) => test_header(),
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
                   |> type(:test, @context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => any(),
                             optional(:path) => test_path(),
                             optional(:query) => test_query(),
                             optional(:headers) => test_header(),
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
                   |> type(:test, @context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => any(),
                             :path => test_path(),
                             optional(:query) => test_query(),
                             optional(:headers) => test_header(),
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "path missing" do
      assert_value %{}
                   |> type(:test, @context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => any(),
                             optional(:query) => test_query(),
                             optional(:headers) => test_header(),
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
                   |> type(:test, @context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => test_request_body(),
                             optional(:query) => test_query(),
                             optional(:headers) => test_header(),
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
                   |> type(:test, @context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => test_request_body(),
                             optional(:query) => test_query(),
                             optional(:headers) => test_header(),
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
                   |> type(:test, @context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             :body => test_request_body(),
                             optional(:query) => test_query(),
                             optional(:headers) => test_header(),
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "requestBody missing" do
      assert_value %{}
                   |> type(:test, @context, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => any(),
                             optional(:query) => test_query(),
                             optional(:headers) => test_header(),
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "server has variables" do
      assert_value %{}
                   |> type(
                     :test,
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
                             optional(:body) => any(),
                             optional(:query) => test_query(),
                             optional(:headers) => test_header(),
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end

    test "server has no variables" do
      assert_value %{}
                   |> type(
                     :test,
                     %OpenAPICompiler.Context{@context | server: @server_simple},
                     __MODULE__
                   )
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     """
                     @type :type :: %{
                             optional(:body) => any(),
                             optional(:query) => test_query(),
                             optional(:headers) => test_header(),
                             optional(:opts) => Tesla.Env.opts()
                           }<NOEOL>
                     """
    end
  end

  describe "parameters_type/5" do
    test "query is a list" do
      assert_value %{
                     "parameters" => [
                       %{
                         "in" => "query",
                         "name" => "foo",
                         "required" => true,
                         "schema" => %{"type" => "string"}
                       }
                     ]
                   }
                   |> parameters_type("query", @context, true, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: %{:foo => String.t(), optional(String.t()) => any()}"
    end

    test "headers is a list" do
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
                   |> parameters_type("header", @context, true, __MODULE__)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: %{<<_::48>> => String.t(), optional(String.t()) => any()}"
    end
  end
end
