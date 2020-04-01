defmodule OpenAPICompiler.Typespec.Server do
  @moduledoc false

  import OpenAPICompiler.Typespec.Utility

  alias OpenAPICompiler.Typespec.Schema

  defmacro typespec(context) do
    quote location: :keep, bind_quoted: [context: context, caller: __MODULE__] do
      %OpenAPICompiler.Context{server: server} = context

      if caller.has_variables?(server) do
        server_parameters_type = caller.type(server, context, __MODULE__)
        @type server_parameters :: unquote(server_parameters_type)
      end
    end
  end

  @spec has_variables?(server_definition :: map) :: boolean
  def has_variables?(server_definition)
  def has_variables?(%{"variables" => variables}), do: variables != %{}
  def has_variables?(_), do: false

  @spec type(server_definition :: map, OpenAPICompiler.Context.t(), atom) :: Macro.t()
  def type(%{"variables" => variables}, context, caller) when variables != %{} do
    {:%{}, [],
     Enum.map(variables, fn {name, definition} ->
       optional_ast(
         true,
         String.to_atom(name),
         definition |> Map.put("type", "string") |> Schema.type(:write, context, caller)
       )
     end)}
  end
end
