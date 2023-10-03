defmodule Cinder.Engine do
  @moduledoc """
  The main request engine.

  Handles routing and rendering requests.
  """
  alias Cinder.{
    Engine,
    Engine.Macros,
    Engine.Server,
    Helpers,
    Route,
    UniqueId
  }

  alias Spark.Dsl.Extension

  import Macros

  require Logger

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
               {Supervisor.sup_flags(), [Supervisor.child_spec() | :supervisor.child_spec()]}}
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
      @spec transition_to(Engine.request_id(), String.t() | [String.t()], Route.params()) :: :ok
      def transition_to(request_id, path_info, params \\ %{}),
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
    pubsub = Extension.get_persisted(app, :cinder_pubsub)

    [
      {Registry, [keys: :unique, name: registry]},
      {DynamicSupervisor, name: supervisor, extra_arguments: [app]},
      {Phoenix.PubSub, name: pubsub}
    ]
    |> maybe_start_server(app)
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

  def transition_to(app, request_id, path_info, params) when is_list(path_info),
    do: transition_to(app, request_id, ["/" | path_info], params)

  def transition_to(app, request_id, path_info, params) when is_binary(path_info),
    do: app |> via(request_id) |> GenServer.cast({:transition_to, path_info, params})

  @doc false
  @spec render_once(Cinder.app(), request_id, Plug.Conn.t()) :: String.t() | no_return
  def render_once(app, request_id, conn),
    do: GenServer.call(via(app, request_id), {:render_once, conn})

  defp maybe_start_server(children, app) do
    if start_server?(app) do
      plug = Extension.get_persisted(app, :cinder_plug)
      port = Extension.get_opt(app, [:cinder], :listen_port, 4000)
      listen_addresses = Extension.get_opt(app, [:cinder], :bind_address)

      Logger.info(fn ->
        cowboy_vsn = Application.spec(:cowboy, :vsn)

        endpoints =
          listen_addresses
          |> addresses_to_urls(port)
          |> Helpers.to_sentence(last: " and ")

        "Starting `#{inspect(app)}` with cowboy #{cowboy_vsn} at #{endpoints} (http)"
      end)

      listeners =
        listen_addresses
        |> Enum.map(fn address ->
          {Plug.Cowboy,
           scheme: :http,
           plug: plug,
           options: [
             port: port,
             ip: IP.Address.to_tuple(address),
             ref: {Cinder.Plug, to_string(address)},
             dispatch: [
               {:_,
                [
                  {"/ws", Cinder.WebsocketHandler, [app: app]},
                  {:_, Plug.Cowboy.Handler, {plug, [app: app]}}
                ]}
             ]
           ]}
        end)

      Enum.concat(children, listeners)
    else
      children
    end
  end

  defp start_server?(app) do
    otp_app = Extension.get_persisted(app, :otp_app)

    Application.get_env(otp_app, :start_server, false) ||
      Application.get_env(:cinder, :start_server, false)
  end

  defp addresses_to_urls(addresses, port) do
    addresses
    |> Enum.map(fn address ->
      %URI{scheme: "http", host: to_string(address), path: "/", port: port}
      |> to_string()
    end)
  end
end
