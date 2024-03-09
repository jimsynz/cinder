defmodule Cinder.Helpers do
  @moduledoc false
  alias Spark.Error.DslError

  @doc "Convert a list of somethings into a sentence"
  @spec to_sentence(Enumerable.t(), keyword) :: String.t()
  def to_sentence(inputs, options \\ []) do
    sep = Keyword.get(options, :sep, ", ")
    last = Keyword.get(options, :last, " or ")
    mapper = Keyword.get(options, :mapper, &Function.identity/1)

    inputs
    |> Enum.map(mapper)
    |> Enum.reverse()
    |> case do
      [item] ->
        to_string(item)

      [head | tail] ->
        tail =
          tail
          |> Enum.reverse()
          |> Enum.join(sep)

        tail <> last <> head
    end
  end

  def assert_cinder_behaviour(app_module, module, behaviour) do
    if Spark.implements_behaviour?(module, behaviour) do
      :ok
    else
      module_file =
        "lib"
        |> Path.join(Macro.underscore(module))
        |> then(&"#{&1}.ex")

      {:error,
       DslError.exception(
         module: app_module,
         path: [:cinder],
         message: """
         Module `#{inspect(module)}` not available.

         This module is needed to implement the `#{inspect(behaviour)}` behaviour.
         You can (minimally) implement by creating the `#{module_file}` file with
         the following contents:

         ```
         defmodule #{inspect(module)} do
           use #{inspect(behaviour)}, app: #{inspect(app_module)}
         end
         ```

         See the docs for `#{inspect(behaviour)}` for more information.
         """
       )}
    end
  end
end
