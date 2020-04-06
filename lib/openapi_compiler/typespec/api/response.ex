defmodule OpenAPICompiler.Typespec.Api.Response do
  @moduledoc false

  alias OpenAPICompiler.Typespec.Schema

  defmacro base_typespecs do
    quote location: :keep do
      @type response(possible_responses) ::
              {:ok, possible_responses} | {:error, {:unexpected_response, Tesla.Env.t()} | any}
    end
  end

  defmacro typespec(name, definition, context) do
    quote location: :keep,
          bind_quoted: [name: name, definition: definition, context: context, caller: __MODULE__] do
      type = caller.type(definition, context, __MODULE__)
      options_name = :"#{name}_options"

      @type unquote(options_name)() :: unquote(type)
      @type unquote(name)() :: response(unquote(options_name))
    end
  end

  @spec type(definition :: map, context :: OpenAPICompiler.Context.t(), caller :: atom) ::
          Macro.t()
  def type(definition, context, caller) do
    definition
    |> Map.get("responses", %{})
    |> Enum.flat_map(fn {code, media_types} ->
      media_types
      |> Map.get("content", %{})
      |> Enum.map(fn
        {_media_type, media_type_definition = %{}} ->
          media_type_definition["schema"]

        _ ->
          nil
      end)
      |> Enum.uniq()
      |> Enum.map(&{code, &1})
      |> case do
        [] -> [{code, nil}]
        other -> other
      end
    end)
    |> Enum.map(fn
      {code, nil} ->
        {code,
         quote location: :keep do
           any()
         end}

      {code, type} ->
        {code, Schema.type(type, :read, context, caller)}
    end)
    |> Enum.map(fn
      {"default", typespec} ->
        quote location: :keep do
          {Tesla.Env.status(), unquote(typespec)}
        end

      {code, typespec} ->
        code = String.to_integer(code)

        quote location: :keep do
          {unquote(code), unquote(typespec)}
        end
    end)
    |> Enum.reduce(
      quote location: :keep do
        any()
      end,
      fn
        value, {:any, _, _} -> value
        value, acc -> {:|, [], [value, acc]}
      end
    )
  end
end
