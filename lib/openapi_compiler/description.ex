defmodule OpenAPICompiler.Description do
  @moduledoc false

  @doc false
  @spec description(context :: OpenAPICompiler.Context.t()) :: String.t()
  def description(context)

  def description(%{schema: schema}) do
    info =
      schema
      |> Enum.map(& &1["info"])
      |> Enum.reduce(%{}, &Map.merge/2)

    """
    #{info["title"]} - `#{info["version"]}`
    """
    |> add_description_text(not is_nil(info["description"]), fn -> info["description"] end)
    |> add_description_text(not is_nil(info["termsOfService"]), fn ->
      "Terms of Service: " <> info["termsOfService"]
    end)
    |> add_description_text(not is_nil(info["license"]), fn ->
      "License: " <>
        if is_nil(info["license"]["url"]) do
          info["license"]["name"]
        else
          "[#{info["license"]["name"]}](#{info["license"]["url"]})"
        end
    end)
    |> add_description_text(not is_nil(info["contact"]), fn ->
      [
        info["contact"]["name"],
        unless is_nil(info["contact"]["email"]) do
          "[#{info["contact"]["email"]}](mailto:#{info["contact"]["email"]})"
        end,
        info["contact"]["url"]
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" - ")
    end)
  end

  defp add_description_text(acc, false, _), do: acc

  defp add_description_text(acc, true, callback) do
    """
    #{acc}

    #{callback.()}
    """
  end
end
