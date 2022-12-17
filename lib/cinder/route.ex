defmodule Cinder.Route do
  alias Cinder.{Engine, Route, Route.Segment}
  alias Phoenix.PubSub
  alias Spark.Dsl.Extension
  defstruct state: :initial, data: nil, module: nil, params: %{}

  @moduledoc """
  Interface for and state of a route.
  """

  @type t :: %Route{
          state: route_state(),
          params: params,
          data: data(),
          module: route_module()
        }

  @type data :: any
  @type route_module :: module
  @type params :: %{required(String.t()) => String.t()}
  @type routing_table :: [{Segment.t(), module | nil, routing_table()}]

  @type route_state ::
          :initial
          | :loading
          | :active
          | :unloading
          | :inactive
          | :error

  @type on_enter :: {:loading, data} | {:active, data} | {:error, data}
  @type on_exit :: {:unloading, data} | {:inactive, data} | {:error, data}

  @callback init(keyword) :: {:ok, data} | {:error, any}
  @callback enter(data, params) :: on_enter()
  @callback exit(data) :: on_exit()

  @callback resource(data) :: {:ok, any} | {:error, any}
  @callback transition_complete(Engine.session_id(), route_state, data) :: :ok | {:error, any}

  @doc """
  Initialise a route.

  Options are a keyword list of options, currently the only option passed is the
  `session_id`, which is needed for asynchronous transitions.

  There may be more options in the future.
  """
  @spec init(route_module, keyword) :: {:ok, t} | {:error, any}
  def init(module, opts) do
    with {:ok, data} <- module.init(opts) do
      {:ok, %Route{state: :initial, data: data, module: module}}
    end
  end

  @doc """
  Attempt to transition into a route.
  """
  @spec enter(t, params) :: {:loading | :active, t} | {:error, any}
  def enter(state, params) when state.state in ~w[loading active]a and state.params == params,
    do: {state.state, state}

  def enter(state, params) when state.state in ~w[initial loading active]a do
    case state.module.enter(state.data, params) do
      {:loading, data} -> {:loading, %{state | data: data, state: :loading, params: params}}
      {:active, data} -> {:active, %{state | data: data, state: :active, params: params}}
      {:error, data} -> {:error, %{state | data: data, state: :error, params: params}}
    end
  end

  def enter(state, _params), do: {:error, {:state_error, state.state}}

  @doc """
  Attempt to transition out of a route.
  """
  @spec exit(t) :: {:unloading | :inactive | :error, t}
  def exit(state) when state.state == :unloading, do: {:unloading, state}

  def exit(state) do
    case state.module.exit(state.data) do
      {:unloading, data} -> {:unloading, %{state | data: data, state: :unloading, params: %{}}}
      {:inactive, data} -> {:inactive, %{state | data: data, state: :inactive, params: %{}}}
      {:error, data} -> {:error, %{state | data: data, state: :error}}
    end
  end

  @doc """
  Retrieve the route's resource.
  """
  @spec resource(t) :: {:ok, any} | {:error, any}
  def resource(state) when state.state == :active, do: state.module.resource(state.data)
  def resource(_state), do: {:error, "Route not active"}

  @doc """
  A subset of the route state used for comparison in the router.
  """
  @spec for_compare(t) :: {params, route_module}
  def for_compare(state), do: {state.params, state.module}

  @doc """
  Complete an asynchronous route transition.

  This is the underlying implementation called by the generated
  `transition_complete/3` callback.
  """
  @spec transition_complete(Cinder.app(), route_module, String.t(), route_state, data()) ::
          :ok | {:error, any}
  def transition_complete(app, route_module, session_id, state, data) do
    pubsub = Extension.get_persisted(app, :cinder_engine_pubsub)

    PubSub.broadcast(
      pubsub,
      "cinder_engine_server:#{session_id}",
      {:transition_complete, route_module, state, data}
    )
  end

  @spec __using__(keyword) :: Macro.t()
  defmacro __using__(opts) do
    app = Keyword.fetch!(opts, :app)

    quote location: :keep do
      @behaviour Route

      @doc false
      @impl true
      @spec init(keyword) :: {:ok | :error, any}
      def init(_opts), do: {:ok, []}

      @doc false
      @impl true
      @spec enter(Route.data(), Route.params()) :: Route.on_enter()
      def enter(data, _params), do: {:active, data}

      @doc false
      @impl true
      @spec exit(Route.data()) :: Route.on_exit()
      def exit(data), do: {:inactive, data}

      @doc false
      @impl true
      @spec resource(Route.data()) :: {:ok | :error, any}
      def resource(_data), do: {:ok, nil}

      defoverridable init: 1, enter: 2, exit: 1, resource: 1

      @doc false
      @impl true
      @spec transition_complete(String.t(), Route.route_state(), Route.data()) :: :ok
      def transition_complete(session_id, state, data),
        do: Cinder.Route.transition_complete(unquote(app), __MODULE__, session_id, state, data)

      @doc false
      @spec __cinder_is__ :: {Cinder.Route, unquote(app)}
      def __cinder_is__, do: {Cinder.Route, unquote(app)}
    end
  end
end
