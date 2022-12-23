defmodule Cinder.WebsocketHandler do
  @moduledoc """
  Implements the Cowboy websocket behaviour.

  """

  @behaviour :cowboy_websocket
  alias Spark.Dsl.Extension

  @doc false
  @impl true
  @spec init(:cowboy_req.req(), list) :: {:cowboy_websocket, :cowboy_req.req(), map}
  def init(request, state) do
    state = Map.new(state)
    app = state.app
    registry = Extension.get_persisted(app, :cinder_engine_registry)
    state = Map.merge(state, %{registry: registry, request_id: nil})

    {:cowboy_websocket, request, state}
  end

  @doc false
  @impl true
  @spec websocket_init(map) :: {:ok, map}
  def websocket_init(state), do: {:ok, state}

  @doc false
  @impl true
  @spec websocket_handle(tuple, map) :: {:ok, map} | {:stop, map}
  def websocket_handle({:text, json}, state) when is_nil(state.request_id) do
    with {:ok, %{"request_id" => request_id}} when is_binary(request_id) <- Jason.decode(json),
         [{pid, _}] <- Registry.lookup(state.registry, request_id) do
      GenServer.cast(pid, {:socket, self()})
      {:ok, state}
    else
      _ -> {:stop, state}
    end
  end

  def websocket_handle(_, state), do: {:ok, state}

  @doc false
  @impl true
  @spec websocket_info(any, map) :: {:ok, map} | {:reply, {:text, String.t()}, map}
  def websocket_info({:rerender, html}, state) do
    {:reply, {:text, Jason.encode!(%{replace_main: html})}, state}
  end

  def websocket_info(_msg, state), do: {:ok, state}
end
