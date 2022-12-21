defmodule Cinder.Template do
  @moduledoc """
  This is a temporary template engine.

  Ultimately I don't think EEx is going to do the job.
  """
  alias Cinder.Template

  @callback render(assigns :: %{required(atom) => any}) :: String.t()
  @callback __cinder_is__ :: {Cinder.Template, Cinder.app()}

  @doc false
  @spec hash(Path.t()) :: binary | nil
  def hash(path) do
    if File.exists?(path) do
      path
      |> File.read!()
      |> :erlang.md5()
    end
  end

  @doc false
  @spec __using__(keyword) :: Macro.t()
  defmacro __using__(opts) do
    app = Keyword.fetch!(opts, :app)

    quote location: :keep do
      @behaviour Cinder.Template

      require EEx

      case Keyword.fetch(unquote(opts), :path) do
        {:ok, path} ->
          @template_path path
          @template_hash Template.hash(path)

          def __mix_recompile__? do
            Template.hash(@template_path) != @template_hash
          end

          if File.exists?(path) do
            EEx.function_from_file(:def, :render, path, [:assigns])
          else
            EEx.function_from_string(:def, :render, "<%= yield() %>", [:assigns])
          end

        :error ->
          raise "Must pass template path"
      end

      def yield(slot \\ :default)

      def yield(:default) do
        "do yield here"
      end

      def yield(_other), do: nil

      @doc false
      @spec __cinder_is__ :: {Cinder.Template, unquote(app)}
      def __cinder_is__, do: {Cinder.Template, unquote(app)}
    end
  end
end
