defmodule OpenAPICompilerTest do
  @moduledoc false

  use ExUnit.Case, async: true

  doctest OpenAPICompiler

  test "valid response" do
    Tesla.Mock.mock(fn
      %Tesla.Env{url: "https://dev.localhost:8080/valid"} ->
        %Tesla.Env{
          status: 200,
          body: ~S("hello"),
          headers: [{"content-type", "application/json"}]
        }
    end)

    assert {:ok, {200, "hello", _}} =
             Internal.post_id(%{
               path: %{id: "valid"},
               body: %{coutry: "CH", city: "St. Gallen", street: "Neugasse 51"}
             })
  end

  test "invalid return code" do
    Tesla.Mock.mock(fn
      %Tesla.Env{url: "https://dev.localhost:8080/invalid"} ->
        %Tesla.Env{
          status: 400,
          body: ~S({"error": "bad request"}),
          headers: [{"content-type", "application/json"}]
        }
    end)

    assert {:error, {:unexpected_response, _}} =
             Internal.post_id(%{
               path: %{id: "invalid"},
               body: %{coutry: "CH", city: "St. Gallen", street: "Neugasse 51"}
             })
  end
end
