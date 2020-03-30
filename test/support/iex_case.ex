defmodule OpenAPICompiler.IExCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  setup do
    Application.ensure_all_started(:iex)
    IEx.configure(colors: [enabled: false])
    Code.append_path(Application.app_dir(:openapi_compiler, "priv/test/compile"))
    Code.compiler_options(ignore_module_conflict: true)

    :ok
  end

  using do
    quote location: :keep do
      defmacro compile_local(test, code) do
        quote location: :keep do
          require IEx.Helpers

          path = Application.app_dir(:openapi_compiler, "priv/test/lib/#{unquote(test)}.ex")
          File.mkdir_p!(Path.dirname(path))

          File.write!(path, Macro.to_string(unquote(code)))

          IEx.Helpers.c(path, Application.app_dir(:openapi_compiler, "priv/test/compile"))
        end
      end

      defmacro iex_b(term) do
        quote location: :keep do
          import ExUnit.CaptureIO

          require IEx.Helpers

          capture_io(fn -> IEx.Helpers.b(unquote(term)) end)
        end
      end

      defmacro iex_h(term) do
        quote location: :keep do
          import ExUnit.CaptureIO

          require IEx.Helpers

          capture_io(fn -> IEx.Helpers.h(unquote(term)) end)
        end
      end

      defmacro iex_t(term) do
        quote location: :keep do
          import ExUnit.CaptureIO

          require IEx.Helpers

          capture_io(fn -> IEx.Helpers.t(unquote(term)) end)
        end
      end
    end
  end
end
