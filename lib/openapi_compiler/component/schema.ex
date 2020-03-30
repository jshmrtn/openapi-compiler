defmodule OpenAPICompiler.Component.Schema do
  @moduledoc false

  defmacro define_module(context, mode) do
    quote location: :keep, bind_quoted: [context: context, mode: mode] do
      module_key = :"components_schema_#{mode}_module"
      %OpenAPICompiler.Context{schema: schema} = %{^module_key => module} = context

      defmodule module do
        require OpenAPICompiler.Typespec

        for root <- schema,
            {name, value} <- root["components"]["schemas"] || [] do
          OpenAPICompiler.Typespec.type(name, value, mode, context)
        end

        case @type do
          [] -> @moduledoc false
          _ -> @moduledoc "TODO"
        end
      end
    end
  end
end
