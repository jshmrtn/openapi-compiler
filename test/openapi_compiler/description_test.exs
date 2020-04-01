defmodule OpenAPICompiler.DescriptionTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import OpenAPICompiler.Description
  import AssertValue

  doctest OpenAPICompiler.Description

  @context %OpenAPICompiler.Context{
    schema: nil,
    base_module: Api,
    components_schema_read_module: Read,
    components_schema_write_module: Write,
    external_resources: [],
    server: nil
  }

  describe "description/1" do
    test "full" do
      assert_value description(%OpenAPICompiler.Context{
                     @context
                     | schema: [
                         %{
                           "info" => %{
                             "title" => "Full",
                             "version" => "1.0.0",
                             "description" => "Bla Bla",
                             "termsOfService" => "Don't be evil",
                             "license" => %{
                               "name" => "MIT",
                               "url" => "https://opensource.org/licenses/MIT"
                             },
                             "contact" => %{
                               "name" => "Mr. Test",
                               "email" => "test@test.com",
                               "url" => "https://example.com"
                             }
                           }
                         }
                       ]
                   }) == """
                   Full - `1.0.0`


                   Bla Bla


                   Terms of Service: Don't be evil


                   License: [MIT](https://opensource.org/licenses/MIT)


                   Mr. Test - [test@test.com](mailto:test@test.com) - https://example.com
                   """
    end

    test "license simple " do
      assert_value description(%OpenAPICompiler.Context{
                     @context
                     | schema: [
                         %{
                           "info" => %{
                             "title" => "License Simple",
                             "version" => "1.0.0",
                             "license" => %{
                               "name" => "MIT"
                             }
                           }
                         }
                       ]
                   }) == """
                   License Simple - `1.0.0`


                   License: MIT
                   """
    end

    test "light" do
      assert_value description(%OpenAPICompiler.Context{
                     @context
                     | schema: [%{"info" => %{"title" => "Light", "version" => "1.0.0"}}]
                   }) == "Light - `1.0.0`\n"
    end
  end
end
