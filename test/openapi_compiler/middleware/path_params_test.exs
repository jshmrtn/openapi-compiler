defmodule OpenAPICompiler.Middleware.PathParamsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import OpenAPICompiler.Middleware.PathParams

  alias Tesla.Env

  doctest OpenAPICompiler.Middleware.PathParams

  describe "call/3" do
    test "params" do
      assert {:ok, %Env{url: "/users/7"}} =
               call(
                 %Env{
                   url: UriTemplate.from_string("/users/{id}"),
                   opts: [path_parameters: %{id: "7"}]
                 },
                 [],
                 nil
               )
    end

    test "no params" do
      assert {:ok, %Env{url: "/users/{id}"}} = call(%Env{url: "/users/{id}"}, [], nil)
    end
  end
end
