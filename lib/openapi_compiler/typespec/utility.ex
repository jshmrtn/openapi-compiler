defmodule OpenAPICompiler.Typespec.Utility do
  @moduledoc false

  @spec type_name(name :: String.t()) :: atom
  def type_name(name) do
    name
    |> Macro.underscore()
    |> String.to_atom()
  end

  @spec optional_ast(optional? :: bool, name :: Macro.t(), type :: Macro.t()) :: Macro.t()
  def optional_ast(optional?, name, type)

  def optional_ast(false, name, type) do
    {name, type}
  end

  def optional_ast(true, name, type) do
    {{:optional, [], [name]}, type}
  end
end
