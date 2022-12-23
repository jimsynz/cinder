defmodule Cinder.Engine.State do
  @moduledoc false
  alias Cinder.{Engine, Engine.State, Route}

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
end
