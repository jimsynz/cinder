defmodule Mix.Tasks.Cinder.Serve do
  @moduledoc """
  Start a Cinder application with the server running.

  This task passes any arguments to `mix run`.
  """

  @shortdoc "Start a Cinder server"

  use Mix.Task

  alias Mix.Tasks.Run

  @impl true
  def run(args) do
    Application.put_env(:cinder, :start_server, true, persistent: true)

    args =
      if Code.ensure_loaded?(IEx) && IEx.started?() do
        args
      else
        args ++ ["--no-halt"]
      end

    Run.run(args)
  end
end
