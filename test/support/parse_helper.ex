defmodule ParseHelper do
  @moduledoc false
  defmacro it_parses(input, ast) do
    quote do
      test "it parses #{inspect(unquote(input))} correctly" do
        assert unquote(ast) == :cinder_handlebars.parse(unquote(input))
      end
    end
  end
end
