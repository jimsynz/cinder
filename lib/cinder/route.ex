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
  @type cinder_routing_table :: [{Segment.t(), module | nil, cinder_routing_table()}]

  @type route_state ::
          :initial
          | :loading
          | :active
          | :unloading
          | :inactive
          | :error

  @type on_enter :: {:loading, data} | {:active, data} | {:error, data}
  @type on_exit :: {:unloading, data} | {:inactive, data} | {:error, data}
  @type on_error :: {:error, data}

  @callback init(keyword) :: {:ok, data} | {:error, any}
  @callback enter(data, params) :: on_enter()
  @callback exit(data) :: on_exit()
  @callback error(data, params) :: on_error()

  @callback resource(data) :: {:ok, any} | {:error, any}
  @callback transition_complete(Engine.request_id(), route_state, data) :: :ok | {:error, any}

  @doc """
  Initialise a route.

  Options are a keyword list of options, currently the only option passed is the
  `request_id`, which is needed for asynchronous transitions.

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
  Force a route into an error state.

  This is primarily used for the App route when something goes horribly wrong.
  """
  @spec error(t, params) :: {:error, t}
  def error(state, params) do
    {:error, data} = state.module.error(state.data, params)
    {:error, %{state | data: data, state: :error, params: params}}
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
  def transition_complete(app, route_module, request_id, state, data) do
    pubsub = Extension.get_persisted(app, :cinder_engine_pubsub)

    PubSub.broadcast(
      pubsub,
      "cinder_engine_server:#{request_id}",
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
      def init(opts) do
        data =
          opts
          |> Map.new()
          |> Map.put_new(:params, nil)

        {:ok, data}
      end

      @doc false
      @impl true
      @spec enter(Route.data(), Route.params()) :: Route.on_enter()
      def enter(data, params), do: {:active, %{data | params: params}}

      @doc false
      @impl true
      @spec exit(Route.data()) :: Route.on_exit()
      def exit(data), do: {:inactive, %{data | params: nil}}

      @doc false
      @impl true
      @spec error(Route.data(), Route.params()) :: Route.on_error()
      def error(data, params), do: {:error, %{data | params: params}}

      @doc false
      @impl true
      @spec resource(Route.data()) :: {:ok | :error, any}
      def resource(data), do: {:ok, data.params}

      defoverridable init: 1, enter: 2, exit: 1, error: 2, resource: 1

      @doc false
      @impl true
      @spec transition_complete(String.t(), Route.route_state(), Route.data()) :: :ok
      def transition_complete(request_id, state, data),
        do: Cinder.Route.transition_complete(unquote(app), __MODULE__, request_id, state, data)

      @doc false
      @spec __cinder_is__ :: {Cinder.Route, unquote(app)}
      def __cinder_is__, do: {Cinder.Route, unquote(app)}
    end
  end
end
