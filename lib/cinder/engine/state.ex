defmodule Cinder.Engine.State do
  @moduledoc """
  Contains the state of the Cinder routing engine.
  """

  alias Cinder.{Engine, Engine.State, Request, Route}

  defstruct app: nil,
            request_id: nil,
            path_info: [],
            params: %{},
            query_params: %{},
            current_routes: [],
            op_stack: [],
            sockets: [],
            status: :idle,
            http_status: 200

  @type params :: %{required(String.t()) => String.t()}
  @type status :: :idle | :transitioning | :transition_paused
  @type op_stack :: [{:exit, module} | {:enter, params, module} | {:error, params, module}]

  @type t :: %State{
          app: Cinder.app(),
          request_id: Engine.request_id(),
          path_info: [String.t()],
          params: params,
          query_params: %{required(String.t()) => String.t()},
          current_routes: [Route.t()],
          op_stack: op_stack,
          sockets: [pid],
          status: status,
          http_status: pos_integer()
        }

  @doc """
  Convert engine state into a request which can be assigned.
  """
  @spec to_request(t) :: Request.t()
  def to_request(state) when is_struct(state, State) do
    current_route = List.last(state.current_routes)

    current_params =
      state.query_params
      |> Map.merge(Map.get(current_route, :params) || %{})

    %Request{
      app: state.app,
      request_id: state.request_id,
      current_routes: state.current_routes,
      current_route: current_route,
      current_params: current_params,
      pid: self()
    }
  end
end
