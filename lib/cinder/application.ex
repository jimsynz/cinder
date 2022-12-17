defmodule Cinder.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    []
    |> maybe_start_app()
    |> Supervisor.start_link(strategy: :one_for_one, name: Cinder.Supervisor)
  end

  defp maybe_start_app(children) do
    case Code.ensure_compiled(Example.App) do
      {:module, _} -> children ++ [Example.App]
      _ -> children
    end
  end
end
