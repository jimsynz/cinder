defmodule Cinder.Route do
  defstruct state: :initial, data: nil, module: nil, params: %{}

  alias Cinder.{Engine, Route, Route.Segment, Template.Render}

  import Cinder.Engine.Macros

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
  @type assigns :: %{required(atom) => any}

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

  @callback assigns(data) :: assigns
  @callback transition_complete(Engine.request_id(), route_state, data) :: :ok | {:error, any}
  @callback template(route_state | :base) :: Render.t()

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
  Retrieve the route's assigns.

  This function is called whenever a route is being rendered, and the result is
  placed in the template's assigns.
  """
  @spec assigns(t) :: assigns()
  def assigns(state), do: state.module.assigns(state.data)

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
    GenServer.cast(via(app, request_id), {:transition_complete, route_module, state, data})
  end

  @spec __using__(keyword) :: Macro.t()
  defmacro __using__(opts) do
    app =
      opts
      |> Keyword.fetch!(:app)
      |> Macro.expand(__CALLER__)

    quote location: :keep do
      import Cinder.Route.Macros

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
      @spec assigns(Route.data()) :: Route.assigns()
      def assigns(data), do: %{params: data.params}

      deftemplates(unquote(app))

      defoverridable init: 1, enter: 2, exit: 1, error: 2, assigns: 1, template: 1

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
