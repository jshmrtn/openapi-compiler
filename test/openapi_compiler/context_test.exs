defmodule OpenAPICompiler.ContextTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import OpenAPICompiler.Context

  doctest OpenAPICompiler.Context

  @example_context %OpenAPICompiler.Context{
    schema: nil,
    base_module: Api,
    components_schema_read_module: Read,
    components_schema_write_module: Write,
    external_resources: [],
    server: nil
  }

  describe "inspect/2" do
    test "hides inner variables" do
      assert "#OpenAPICompiler.Context<Elixir.Api>" = inspect(@example_context)
    end
  end

  describe "create/2" do
    test "works from yaml path" do
      path = Application.app_dir(:openapi_compiler, "priv/examples/internal.yaml")

      assert %OpenAPICompiler.Context{
               base_module: API,
               components_schema_read_module: API.Schema.Read,
               components_schema_write_module: API.Schema.Write,
               external_resources: [^path],
               schema: [_],
               server: %{
                 "url" => "https://{env}.localhost:{port}",
                 "variables" => %{
                   "env" => %{"default" => "dev", "enum" => ["dev", "test", "prod"]},
                   "port" => %{"default" => "8080"}
                 }
               }
             } = create([yml_path: path], API)
    end

    test "works from json path" do
      path = Application.app_dir(:openapi_compiler, "priv/examples/internal.json")

      assert %OpenAPICompiler.Context{
               base_module: API,
               components_schema_read_module: API.Schema.Read,
               components_schema_write_module: API.Schema.Write,
               external_resources: [^path],
               schema: [_],
               server: %{
                 "url" => "https://{env}.localhost:{port}",
                 "variables" => %{
                   "env" => %{"default" => "dev", "enum" => ["dev", "test", "prod"]},
                   "port" => %{"default" => "8080"}
                 }
               }
             } = create([json_path: path], API)
    end

    test "errors without schema" do
      assert_raise OpenAPICompiler.InvalidOptsError, "Schema not provided", fn ->
        create([], API)
      end
    end

    test "works from yaml string" do
      yml = """
      openapi: "3.0.0"
      info:
        version: 1.0.0
        title: Swagger Petstore
        license:
          name: MIT
      servers:
        - url: "https://example.com"
      """

      assert %OpenAPICompiler.Context{
               base_module: API,
               components_schema_read_module: API.Schema.Read,
               components_schema_write_module: API.Schema.Write,
               external_resources: [],
               schema: [_],
               server: %{"url" => "https://example.com"}
             } = create([yml: yml], API)
    end

    test "works from json string" do
      json = """
      {
        "openapi": "3.0.0",
        "info": {
          "version": "1.0.0",
          "title": "Swagger Petstore",
          "license": {
            "name": "MIT"
          }
        },
        "servers": [
          {
            "url": "https://example.com"
          }
        ]
      }
      """

      assert %OpenAPICompiler.Context{
               base_module: API,
               components_schema_read_module: API.Schema.Read,
               components_schema_write_module: API.Schema.Write,
               external_resources: [],
               schema: [_],
               server: %{"url" => "https://example.com"}
             } = create([json: json], API)
    end

    test "fails with invalid ref" do
      json = """
      {
        "$ref": "#/foo"
      }
      """

      assert_raise OpenAPICompiler.RefNotFoundError, "Ref #/foo not found", fn ->
        create([json: json], API)
      end
    end

    test "fails with circular ref" do
      json = """
      {
        "foo": {
          "$ref": "#/foo"
        }
      }
      """

      assert_raise OpenAPICompiler.CircularRefError,
                   "Circular refs are only supported for schema components",
                   fn ->
                     create([json: json], API)
                   end
    end

    test "server selection by index" do
      yml = """
      openapi: "3.0.0"
      info:
        version: 1.0.0
        title: Swagger Petstore
        license:
          name: MIT
      servers:
      - url: "https://one.com"
      - url: "https://two.com"
      """

      assert %OpenAPICompiler.Context{
               base_module: API,
               components_schema_read_module: API.Schema.Read,
               components_schema_write_module: API.Schema.Write,
               external_resources: [],
               schema: [_],
               server: %{"url" => "https://two.com"}
             } = create([yml: yml, server: 1], API)
    end

    test "server selection by url" do
      yml = """
      openapi: "3.0.0"
      info:
        version: 1.0.0
        title: Swagger Petstore
        license:
          name: MIT
      servers:
      - url: "https://one.com"
      - url: "https://two.com"
      """

      assert %OpenAPICompiler.Context{
               base_module: API,
               components_schema_read_module: API.Schema.Read,
               components_schema_write_module: API.Schema.Write,
               external_resources: [],
               schema: [_],
               server: %{"url" => "https://two.com"}
             } = create([yml: yml, server: "https://two.com"], API)
    end

    test "server selection by description" do
      yml = """
      openapi: "3.0.0"
      info:
        version: 1.0.0
        title: Swagger Petstore
        license:
          name: MIT
      servers:
      - url: "https://one.com"
        description: One
      - url: "https://two.com"
        description: Two
      """

      assert %OpenAPICompiler.Context{
               base_module: API,
               components_schema_read_module: API.Schema.Read,
               components_schema_write_module: API.Schema.Write,
               external_resources: [],
               schema: [_],
               server: %{"url" => "https://two.com"}
             } = create([yml: yml, server: "Two"], API)
    end

    test "server selection unknown" do
      yml = """
      openapi: "3.0.0"
      info:
        version: 1.0.0
        title: Swagger Petstore
        license:
          name: MIT
      servers:
      - url: "https://one.com"
        description: One
      - url: "https://two.com"
        description: Two
      """

      assert_raise OpenAPICompiler.InvalidOptsError, "Server Foo not found", fn ->
        create([yml: yml, server: "Foo"], API)
      end
    end

    test "allow server override" do
      yml = """
      openapi: "3.0.0"
      info:
        version: 1.0.0
        title: Swagger Petstore
        license:
          name: MIT
      servers:
      - url: "https://one.com"
      """

      assert %OpenAPICompiler.Context{
               base_module: API,
               components_schema_read_module: API.Schema.Read,
               components_schema_write_module: API.Schema.Write,
               external_resources: [],
               schema: [_],
               server: %{"url" => "https://two.com"}
             } = create([yml: yml, server: %{"url" => "https://two.com"}], API)
    end

    test "reject no server" do
      yml = """
      openapi: "3.0.0"
      info:
        version: 1.0.0
        title: Swagger Petstore
        license:
          name: MIT
      """

      assert_raise OpenAPICompiler.InvalidOptsError, "No server was defined", fn ->
        create([yml: yml], API)
      end
    end
  end
end
