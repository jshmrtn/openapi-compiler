defmodule OpenAPICompiler.Typespec.Server do
  @moduledoc false

  import OpenAPICompiler.Typespec.Utility

  alias OpenAPICompiler.Typespec.Schema

  defmacro typespec(context) do
    quote location: :keep, bind_quoted: [context: context, caller: __MODULE__] do
      %OpenAPICompiler.Context{server: server, schema: schema} = context

      types =
        case server do
          %{} ->
            [caller.type(server, context, __MODULE__)]

          function when is_function(function, 0) ->
            schema
            |> Enum.map(& &1["servers"])
            |> Enum.reject(&is_nil/1)
            |> List.flatten()
            |> Enum.map(&caller.type(&1, context, __MODULE__))
            |> Enum.uniq()
            |> Kernel.++([
              quote do
                map()
              end
            ])
        end

      # server_parameters_type = caller.type(server, context, __MODULE__)
      @type server_parameters :: unquote(Enum.reduce(types, &{:|, [], [&1, &2]}))
    end
  end

  @spec has_variables?(server_definition :: map) :: boolean
  def has_variables?(server_definition)
  def has_variables?(%{"variables" => variables}), do: variables != %{}
  def has_variables?(_server_definition), do: false

  @spec type(server_definition :: map, OpenAPICompiler.Context.t(), atom) :: Macro.t()
  def type(server_definition, context, caller) do
    {:%{}, [],
     server_definition
     |> Map.get("variables", [])
     |> Enum.map(fn {name, definition} ->
       optional_ast(
         true,
         String.to_atom(name),
         definition |> Map.put("type", "string") |> Schema.type(:write, context, caller)
       )
     end)}
  end
end
