defmodule OpenAPICompiler.Typespec.UtilityTest do
  @moduledoc false

  use ExUnit.Case

  import OpenAPICompiler.Typespec.Utility
  import AssertValue

  doctest OpenAPICompiler.Typespec.Utility

  @spec type_def_ast(type :: Macro.t()) :: Macro.t()
  def type_def_ast(type) do
    {:@, [], [{:type, [], [{:"::", [], [:type, type]}]}]}
  end

  describe "type_name/1" do
    test "works" do
      assert :foo_bar_baz = type_name("fooBarBaz")
    end
  end

  describe "optional_ast/3" do
    test "optional true" do
      assert_value {:%{}, [],
                    [
                      optional_ast(
                        true,
                        :foo,
                        quote location: :keep do
                          any()
                        end
                      )
                    ]}
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: %{optional(:foo) => any()}"
    end

    test "optional false" do
      assert_value {:%{}, [],
                    [
                      optional_ast(
                        false,
                        :foo,
                        quote location: :keep do
                          any()
                        end
                      )
                    ]}
                   |> type_def_ast
                   |> Macro.to_string()
                   |> Code.format_string!()
                   |> IO.iodata_to_binary() == "@type :type :: %{foo: any()}"
    end
  end
end
