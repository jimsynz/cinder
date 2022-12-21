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

  @type session_id :: UniqueId.unique_id()

  @callback start(String.t()) :: DynamicSupervisor.on_start_child()
  @callback start!(String.t()) :: pid | no_return
  @callback transition_to(String.t(), [String.t()], Route.params()) :: :ok
  @callback render_once(String.t()) :: String.t()
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
      @spec start(String.t()) :: DynamicSupervisor.on_start_child()
      def start(session_id), do: Engine.start(unquote(app), session_id)

      @doc false
      @impl true
      @spec start!(String.t()) :: pid | no_return
      def start!(session_id), do: Engine.start!(unquote(app), session_id)

      @doc false
      @impl true
      @spec transition_to(String.t(), [String.t()], Route.params()) :: :ok
      def transition_to(session_id, path_info, params),
        do: Engine.transition_to(unquote(app), session_id, path_info, params)

      @doc false
      @impl true
      @spec render_once(String.t()) :: String.t()
      def render_once(session_id), do: Engine.render_once(unquote(app), session_id)

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
  @spec start(Cinder.app(), String.t()) :: DynamicSupervisor.on_start_child()
  def start(app, session_id) do
    supervisor = Extension.get_persisted(app, :cinder_engine_supervisor)
    DynamicSupervisor.start_child(supervisor, {Server, session_id})
  end

  @doc false
  @spec start!(Cinder.app(), String.t()) :: pid | no_return()
  def start!(app, session_id) do
    case start(app, session_id) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
      {:error, reason} -> raise "Unable to start Cinder engine server: #{inspect(reason)}"
    end
  end

  @doc false
  @spec transition_to(Cinder.app(), String.t(), [String.t()], Route.params()) :: :ok
  def transition_to(app, session_id, ["/" | _] = path_info, params),
    do: app |> via(session_id) |> GenServer.cast({:transition_to, path_info, params})

  def transition_to(app, session_id, path_info, params),
    do: transition_to(app, session_id, ["/" | path_info], params)

  @doc false
  @spec render_once(Cinder.app(), String.t()) :: String.t() | no_return
  def render_once(app, session_id), do: GenServer.call(via(app, session_id), :render_once)
end
