defmodule OpenAPICompiler.Typespec.ServerTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use OpenAPICompiler.IExCase, async: true

  import OpenAPICompiler.Typespec.Server
  import AssertValue

  doctest OpenAPICompiler.Typespec.Server

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

  def context_complex, do: %OpenAPICompiler.Context{@context | server: @server_complex}
  def context_simple, do: %OpenAPICompiler.Context{@context | server: @server_simple}

  @spec type_def_ast(type :: Macro.t()) :: Macro.t()
  def type_def_ast(type) do
    {:@, [], [{:type, [], [{:"::", [], [:type, type]}]}]}
  end

  describe "typespec/1" do
    test "complex", %{test: test} do
      module_name = :"#{__MODULE__}.ServerTypespecComplex"

      compile_local(
        test,
        quote location: :keep do
          defmodule unquote(module_name) do
            @moduledoc false

            context = unquote(__MODULE__).context_complex()

            require OpenAPICompiler.Typespec.Server
            OpenAPICompiler.Typespec.Server.typespec(context)
          end
        end
      )

      assert_value iex_t(module_name.server_parameters()) == """
                   @type server_parameters() :: %{
                           optional(:env) => :prod | :test | :dev,
                           optional(:port) => String.t()
                         }

                   """
    end

    test "simple", %{test: test} do
      module_name = :"#{__MODULE__}.ServerTypespecSimple"

      compile_local(
        test,
        quote location: :keep do
          defmodule unquote(module_name) do
            @moduledoc false

            context = unquote(__MODULE__).context_simple()

            require OpenAPICompiler.Typespec.Server
            OpenAPICompiler.Typespec.Server.typespec(context)
          end
        end
      )

      assert_value iex_t(module_name.server_parameters()) ==
                     "No type information for OpenAPICompiler.Typespec.ServerTest.ServerTypespecSimple.server_parameters was found or OpenAPICompiler.Typespec.ServerTest.ServerTypespecSimple.server_parameters is private\n"
    end
  end

  describe "type/3" do
    test "complex" do
      assert_value @server_complex
                   |> type(@context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: %{optional(:env) => :prod | :test | :dev, optional(:port) => String.t()}"
    end

    test "simple" do
      assert_raise FunctionClauseError, fn ->
        type(@server_simple, @context, Read)
      end
    end
  end
end
