defmodule OpenAPICompiler.Typespec.SchemaTest do
  @moduledoc false

  use ExUnit.Case
  use OpenAPICompiler.IExCase, async: true

  import OpenAPICompiler.Typespec.Schema
  import AssertValue

  doctest OpenAPICompiler.Typespec.Schema

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

  describe "typespec/4" do
    test "works", %{test: test} do
      module_name = :"#{__MODULE__}.Typespec"

      compile_local(
        test,
        quote location: :keep do
          defmodule unquote(module_name) do
            @moduledoc false

            require OpenAPICompiler.Typespec.Schema

            OpenAPICompiler.Typespec.Schema.typespec(
              "Address",
              %{"type" => "string"},
              :read,
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

      assert_value iex_t(module_name.address()) ==
                     "Beam code not available for OpenAPICompiler.Typespec.SchemaTest.Typespec or debug info is missing, cannot load typespecs\n"
    end
  end

  describe "type/4/nullable" do
    test "true" do
      assert_value %{"type" => "string", "nullable" => true}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: String.t() | nil"
    end

    test "false" do
      assert_value %{"type" => "string", "nullable" => false}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: String.t()"
    end
  end

  describe "type/4/$ref" do
    test "local read" do
      assert_value %{__ref__: ["components", "schemas", "foo"]}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: foo()"
    end

    test "remote read" do
      assert_value %{__ref__: ["components", "schemas", "foo"]}
                   |> type(:read, @context, Write)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: Read.foo()"
    end

    test "local write" do
      assert_value %{__ref__: ["components", "schemas", "foo"]}
                   |> type(:write, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: Write.foo()"
    end

    test "remote write" do
      assert_value %{__ref__: ["components", "schemas", "foo"]}
                   |> type(:write, @context, Write)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: foo()"
    end

    test "not schema" do
      assert_value %{:__ref__ => ["components", "responses", "foo"], "type" => "string"}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: String.t()"
    end
  end

  describe "type/4/string" do
    test "format byte" do
      assert_value %{"type" => "string", "format" => "byte"}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: binary()"
    end

    test "format binary" do
      assert_value %{"type" => "string", "format" => "binary"}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: binary()"
    end

    test "enum read" do
      assert_value %{"type" => "string", "enum" => ["foo", "bar", "ädsagf"]}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: String.t()"
    end

    test "enum write" do
      assert_value %{"type" => "string", "enum" => ["foo", "bar", "ädsagf"]}
                   |> type(:write, @context, Write)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: :ädsagf | :bar | :foo"
    end

    test "format unknown" do
      assert_value %{"type" => "string", "format" => "unknown"}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: String.t()"
    end

    test "default" do
      assert_value %{"type" => "string"}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: String.t()"
    end
  end

  describe "type/4/boolean" do
    test "default" do
      assert_value %{"type" => "boolean"}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: boolean()"
    end
  end

  describe "type/4/number" do
    test "float" do
      assert_value %{"type" => "number", "format" => "float"}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: float()"
    end

    test "double" do
      assert_value %{"type" => "number", "format" => "double"}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: float()"
    end

    test "default" do
      assert_value %{"type" => "number"}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: float() | integer()"
    end
  end

  describe "type/4/integer" do
    test "default" do
      assert_value %{"type" => "integer"}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: integer()"
    end
  end

  describe "object" do
    test "default" do
      assert_value %{"type" => "object"}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: map()"
    end

    test "with properties" do
      assert_value %{
                     "type" => "object",
                     "required" => ["firstName"],
                     "properties" => %{
                       "firstName" => %{"type" => "string"},
                       "lastName" => %{"type" => "string"}
                     }
                   }
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: %{:firstName => String.t(), optional(:lastName) => String.t()}"
    end

    test "readOnly read" do
      assert_value %{
                     "type" => "object",
                     "properties" => %{
                       "firstName" => %{"type" => "string", "readOnly" => true}
                     }
                   }
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: %{optional(:firstName) => String.t()}"
    end

    test "readOnly write" do
      assert_value %{
                     "type" => "object",
                     "properties" => %{
                       "firstName" => %{"type" => "string", "readOnly" => true}
                     }
                   }
                   |> type(:write, @context, Write)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: %{}"
    end

    test "writeOnly read" do
      assert_value %{
                     "type" => "object",
                     "properties" => %{
                       "firstName" => %{"type" => "string", "writeOnly" => true}
                     }
                   }
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: %{}"
    end

    test "writeOnly write" do
      assert_value %{
                     "type" => "object",
                     "properties" => %{
                       "firstName" => %{"type" => "string", "writeOnly" => true}
                     }
                   }
                   |> type(:write, @context, Write)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: %{optional(:firstName) => String.t()}"
    end
  end

  describe "type/4/array" do
    test "default" do
      assert_value %{"type" => "array"}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: list()"
    end

    test "with items" do
      assert_value %{
                     "type" => "array",
                     "items" => %{"type" => "string"}
                   }
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: list(String.t())"
    end
  end

  describe "type/4/oneOf" do
    test "default" do
      assert_value %{"oneOf" => [%{"type" => "string"}, %{"type" => "integer"}]}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: integer() | String.t()"
    end
  end

  describe "allOf" do
    test "overwrite normal type" do
      assert_value %{"allOf" => [%{"type" => "string"}, %{"type" => "integer"}]}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: integer()"
    end

    test "combine normal type" do
      assert_value %{"allOf" => [%{"type" => "string"}, %{"nullable" => "true"}]}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: String.t()"
    end

    test "combine map" do
      assert_value %{
                     "allOf" => [
                       %{
                         "type" => "object",
                         "required" => ["firstName"],
                         "properties" => %{
                           "lastName" => %{"type" => "string"}
                         }
                       },
                       %{
                         "type" => "object",
                         "required" => ["lastName"],
                         "properties" => %{
                           "firstName" => %{"type" => "integer"},
                           "lastName" => %{"type" => "string"}
                         }
                       }
                     ]
                   }
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: %{firstName: integer(), lastName: String.t()}"
    end
  end

  describe "anyOf" do
    test "generates valid output" do
      assert_value %{
                     "anyOf" => [
                       %{
                         "type" => "object",
                         "required" => ["firstName"],
                         "properties" => %{"firstName" => %{"type" => "string"}}
                       },
                       %{
                         "type" => "object",
                         "required" => ["lastName"],
                         "properties" => %{"lastName" => %{"type" => "string"}}
                       }
                     ]
                   }
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: %{optional(:firstName) => String.t(), optional(:lastName) => String.t()}"
    end
  end

  describe "type/4/fallback to object" do
    test "default" do
      assert_value %{}
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: map()"
    end

    test "with properties" do
      assert_value %{
                     "properties" => %{
                       "firstName" => %{"type" => "string"}
                     }
                   }
                   |> type(:read, @context, Read)
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() ==
                     "@type :type :: %{optional(:firstName) => String.t()}"
    end
  end

  describe "type/4/unknown type" do
    test "default" do
      assert_raise OpenAPICompiler.UnknownTypeError, "Unknown Type foo", fn ->
        %{"type" => "foo"}
        |> type(:read, @context, Read)
        |> type_def_ast
        |> Macro.to_string()
      end
    end
  end
end
