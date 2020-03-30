# credo:disable-for-this-file

defmodule ApiWithExamples do
  use OpenAPICompiler,
    yml_path:
      Application.app_dir(
        :openapi_compiler,
        "priv/examples/openapi-specification/examples/v3.0/api-with-examples.yaml"
      ),
    server: %{"url" => "foo"}
end

defmodule Callback do
  use OpenAPICompiler,
    yml_path:
      Application.app_dir(
        :openapi_compiler,
        "priv/examples/openapi-specification/examples/v3.0/callback-example.yaml"
      ),
    server: %{"url" => "foo"}
end

defmodule Link do
  use OpenAPICompiler,
    yml_path:
      Application.app_dir(
        :openapi_compiler,
        "priv/examples/openapi-specification/examples/v3.0/link-example.yaml"
      ),
    server: %{"url" => "foo"}
end

defmodule PetstoreExpanded do
  use OpenAPICompiler,
    yml_path:
      Application.app_dir(
        :openapi_compiler,
        "priv/examples/openapi-specification/examples/v3.0/petstore-expanded.yaml"
      )
end

defmodule Petstore do
  use OpenAPICompiler,
    yml_path:
      Application.app_dir(
        :openapi_compiler,
        "priv/examples/openapi-specification/examples/v3.0/petstore.yaml"
      )
end

defmodule Uspto do
  use OpenAPICompiler,
    yml_path:
      Application.app_dir(
        :openapi_compiler,
        "priv/examples/openapi-specification/examples/v3.0/uspto.yaml"
      )
end

defmodule Internal do
  use OpenAPICompiler,
    yml_path: Application.app_dir(:openapi_compiler, "priv/examples/internal.yaml")
end
