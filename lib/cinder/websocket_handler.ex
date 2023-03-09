defmodule Cinder.WebsocketHandler do
  @moduledoc """
  Implements the Cowboy websocket behaviour.
  """

  @behaviour :cowboy_websocket
  alias Spark.Dsl.Extension
  require Logger
  import Cinder.UniqueId

  # These should be configurable in the DSL.
  @config %{
    compress: true,
    idle_timeout: 45_000,
    ping_interval: 30_000
  }

  defp handle_command("connect", %{"data" => %{"requestId" => request_id}} = command, state)
       when is_nil(state.request_id) do
    case Registry.lookup(state.registry, request_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:socket, self()})
        reply_ok(command, %{"requestId" => request_id}, Map.put(state, :request_id, request_id))

      _ ->
        reply_error(command, %{"reason" => "Unknown request id"}, state)
    end
  end

  defp handle_command("transitionTo", %{"data" => %{"target" => target}}, state) do
    GenServer.cast(
      {:via, Registry, {state.registry, state.request_id}},
      {:transition_to, target, %{}}
    )

    noreply(state)
  end

  defp handle_command(_command_name, command, state) do
    reply_error(command, %{"reason" => "Invalid command"}, state)
  end

  @doc false
  @impl true
  def init(request, state) do
    state = Map.new(state)
    app = state.app
    registry = Extension.get_persisted(app, :cinder_engine_registry)
    engine = Extension.get_persisted(app, :cinder_engine)
    state = Map.merge(state, %{registry: registry, request_id: nil, engine: engine})

    {:cowboy_websocket, request, state, Map.take(@config, ~w[compress idle_timeout]a)}
  end

  @doc false
  @impl true
  def websocket_init(state) do
    Process.send_after(self(), :ping, @config.ping_interval)

    {:ok, state}
  end

  @doc false
  @impl true
  def websocket_handle({:text, json}, state) do
    case Jason.decode(json) do
      {:ok, message} -> try_command(message, state)
      _ -> {:stop, state}
    end
  end

  def websocket_handle(:pong, state), do: {:ok, state}

  def websocket_handle(msg, state) do
    Logger.debug("[#{inspect(__MODULE__)}] received frame: #{inspect(msg)}")
    {:ok, state}
  end

  @doc false
  @impl true
  def websocket_info({:rerender, html}, state) do
    send_command("rerender", %{page: IO.iodata_to_binary(html)}, state)
  end

  def websocket_info(:ping, state) do
    Process.send_after(self(), :ping, @config.ping_interval)
    {:reply, :ping, state}
  end

  def websocket_info(_msg, state), do: {:ok, state}

  defp try_command(%{"command" => command_name} = command, state) when is_binary(command_name),
    do: handle_command(command_name, command, state)

  defp try_command(_invalid, state) do
    {:stop, state}
  end

  defp reply_ok(%{"id" => id}, data, state) do
    payload =
      %{
        "replyTo" => id,
        "data" => data,
        "ok" => true
      }
      |> Jason.encode!()

    {:reply, {:text, payload}, state}
  end

  defp reply_error(command, data, state)

  defp reply_error(%{"id" => id}, data, state) do
    payload =
      %{"replyTo" => id, "error" => data, "ok" => false}
      |> Jason.encode!()

    {:reply, {:text, payload}, state}
  end

  defp reply_error(_, _data, state), do: {:stop, state}

  defp noreply(state), do: {:ok, state}

  defp gen_command(command_name, data) do
    %{
      "command" => command_name,
      "id" => unique_id(16),
      "data" => data
    }
  end

  defp send_command(command_name, data, state) do
    {:reply, {:text, Jason.encode!(gen_command(command_name, data))}, state}
  end
end
