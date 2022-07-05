defmodule OpenAPICompiler.Middleware.ServerTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import OpenAPICompiler.Middleware.Server

  alias OpenAPICompiler.Context
  alias Tesla.Env

  doctest OpenAPICompiler.Middleware.Server

  describe "call/3" do
    test "absolte path ignore" do
      assert {:ok, %Env{url: "https://example.com/"}} =
               call(%Env{url: "https://example.com/"}, [], nil)
    end

    test "params" do
      assert {:ok, %Env{url: "https://example.com:8080/foo/"}} =
               call(
                 %Env{
                   url: "/",
                   opts: [server_parameters: %{:host => "example.com", "port" => "8080"}]
                 },
                 [],
                 Context.create(
                   %{
                     schema: [
                       %{
                         "servers" => [
                           %{
                             "url" => "https://{host}:{port}/{path}",
                             "variables" => %{
                               "host" => %{"default" => "localhost"},
                               "port" => %{"default" => "443"},
                               "path" => %{"default" => "foo"}
                             }
                           }
                         ]
                       }
                     ]
                   },
                   __MODULE__
                 )
               )
    end
  end
end
