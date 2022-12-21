defmodule Cinder.Engine do
  @moduledoc """
  The main request engine.

  Handles routing and rendering requests.
  """
  alias Cinder.{
    Engine,
    Engine.Macros,
    Engine.Server,
    Route,
    UniqueId
  }

  alias Spark.Dsl.Extension

  import Macros

  @type request_id :: UniqueId.unique_id()

  @callback start(request_id) :: DynamicSupervisor.on_start_child()
  @callback start!(request_id) :: pid | no_return
  @callback transition_to(request_id, [String.t()], Route.params()) :: :ok
  @callback render_once(request_id, Plug.Conn.t()) :: String.t()
  @callback __cinder_is__ :: {Cinder.Engine, module}

  @spec __using__(keyword) :: Macro.t()
  defmacro __using__(opts) do
    app = Keyword.fetch!(opts, :app)

    quote location: :keep do
      use Supervisor
      @behaviour Cinder.Engine

      @doc false
      @spec start_link(any) :: Supervisor.on_start()
      def start_link(init_arg), do: Supervisor.start_link(__MODULE__, init_arg)

      @doc false
      @impl true
      @spec init(any) ::
              {:ok,
               {Supervisor.sup_flags(),
                [Supervisor.child_spec() | (old_erlang_child_spec :: :supervisor.child_spec())]}}
              | :ignore
      def init(_opts), do: Engine.supervisor_init(unquote(app))

      @doc false
      @impl true
      @spec start(Engine.request_id()) :: DynamicSupervisor.on_start_child()
      def start(request_id), do: Engine.start(unquote(app), request_id)

      @doc false
      @impl true
      @spec start!(Engine.request_id()) :: pid | no_return
      def start!(request_id), do: Engine.start!(unquote(app), request_id)

      @doc false
      @impl true
      @spec transition_to(Engine.request_id(), [String.t()], Route.params()) :: :ok
      def transition_to(request_id, path_info, params),
        do: Engine.transition_to(unquote(app), request_id, path_info, params)

      @doc false
      @impl true
      @spec render_once(Engine.request_id(), Plug.Conn.t()) :: String.t()
      def render_once(request_id, conn), do: Engine.render_once(unquote(app), request_id, conn)

      @doc false

      @impl true
      @spec __cinder_is__ :: {Cinder.Engine, unquote(app)}
      def __cinder_is__, do: {Cinder.Engine, unquote(app)}
    end
  end

  @doc false
  @spec supervisor_init(module) ::
          {:ok,
           {Supervisor.sup_flags(),
            [Supervisor.child_spec() | (old_erlang_child_spec :: :supervisor.child_spec())]}}
          | :ignore
  def supervisor_init(app) do
    registry = Extension.get_persisted(app, :cinder_engine_registry)
    supervisor = Extension.get_persisted(app, :cinder_engine_supervisor)
    plug = Extension.get_persisted(app, :cinder_plug)
    pubsub = Extension.get_persisted(app, :cinder_engine_pubsub)
    port = Extension.get_opt(app, [:cinder], :listen_port, 4000)

    [
      {Registry, [keys: :unique, name: registry]},
      {DynamicSupervisor, name: supervisor, extra_arguments: [app]},
      {Phoenix.PubSub, name: pubsub},
      {Plug.Cowboy, scheme: :http, plug: plug, options: [port: port]}
    ]
    |> Supervisor.init(strategy: :one_for_one)
  end

  @doc false
  @spec start(Cinder.app(), request_id) :: DynamicSupervisor.on_start_child()
  def start(app, request_id) do
    supervisor = Extension.get_persisted(app, :cinder_engine_supervisor)
    DynamicSupervisor.start_child(supervisor, {Server, request_id})
  end

  @doc false
  @spec start!(Cinder.app(), request_id) :: pid | no_return()
  def start!(app, request_id) do
    case start(app, request_id) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
      {:error, reason} -> raise "Unable to start Cinder engine server: #{inspect(reason)}"
    end
  end

  @doc false
  @spec transition_to(Cinder.app(), request_id, [String.t()], Route.params()) :: :ok
  def transition_to(app, request_id, ["/" | _] = path_info, params),
    do: app |> via(request_id) |> GenServer.cast({:transition_to, path_info, params})

  def transition_to(app, request_id, path_info, params),
    do: transition_to(app, request_id, ["/" | path_info], params)

  @doc false
  @spec render_once(Cinder.app(), request_id, Plug.Conn.t()) :: String.t() | no_return
  def render_once(app, request_id, conn),
    do: GenServer.call(via(app, request_id), {:render_once, conn})
end
