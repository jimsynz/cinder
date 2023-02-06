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
    idle_timeout: :infinity,
    ping_interval: 60_000
  }

  @doc false
  @impl true
  # @spec init(:cowboy_req.req(), list) :: {:cowboy_websocket, :cowboy_req.req(), map, map}
  def init(request, state) do
    state = Map.new(state)
    app = state.app
    registry = Extension.get_persisted(app, :cinder_engine_registry)
    engine = Extension.get_persisted(app, :cinder_engine)
    state = Map.merge(state, %{registry: registry, request_id: nil, engine: engine})

    if is_integer(@config.ping_interval) and @config.ping_interval > 0 do
      :timer.send_interval(@config.ping_interval, :ping)
    end

    {:cowboy_websocket, request, state, Map.take(@config, ~w[compress idle_timeout]a)}
  end

  @doc false
  @impl true
  # @spec websocket_init(map) :: {:ok, map}
  def websocket_init(state), do: {:ok, state}

  @doc false
  @impl true
  # @spec websocket_handle(tuple, map) :: {:ok, map} | {:stop, map}
  def websocket_handle({:text, json}, state) when is_nil(state.request_id) do
    json
    |> Jason.decode()
    |> case do
      {:ok, json} -> connect_socket(json, state)
      _ -> {:stop, state}
    end
  end

  def websocket_handle(msg, state) do
    Logger.debug("[#{inspect(__MODULE__)}] received frame: #{inspect(msg)}")
    {:ok, state}
  end

  @doc false
  @impl true
  # @spec websocket_info(any, map) :: {:ok, map} | {:reply, {:text, String.t()}, map}
  def websocket_info({:rerender, html}, state) do
    {:reply, {:text, Jason.encode!(%{replace_main: IO.chardata_to_string(html)})}, state}
  end

  def websocket_info(:ping, state), do: {:reply, {:ping, []}, state}

  def websocket_info(_msg, state), do: {:ok, state}

  defp connect_socket(%{"request_id" => request_id} = json, state) do
    case Registry.lookup(state.registry, request_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:socket, self()})
        {:reply, {:text, Jason.encode!(%{status: :connected, request_id: request_id})}, state}

      _ ->
        json
        |> Map.delete("request_id")
        |> connect_socket(state)
    end
  end

  defp connect_socket(%{"path" => path}, state) do
    request_id = unique_id()
    state.engine.start!(request_id)
    state.engine.transition_to(request_id, path)
    GenServer.cast({:via, Registry, {state.registry, request_id}}, {:socket, self()})

    {:reply, {:text, Jason.encode!(%{status: :connected, request_id: request_id})},
     %{state | request_id: request_id}}
  end
end
