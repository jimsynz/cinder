defmodule Cinder.Plug.SetSecretKeyBase do
  @moduledoc """
  Set the conn's `secret_key_base`.

  Fetches the secret value from the Application configuration.
  """

  @behaviour Plug
  @type opts :: %{required(:app) => Cinder.app(), optional(atom) => any}

  alias Cinder.Secret

  @doc false
  @impl true
  @spec init(keyword) :: opts
  def init(opts) do
    opts
    |> Map.new()
  end

  @doc false
  @impl true
  @spec call(Plug.Conn.t(), opts) :: Plug.Conn.t()
  def call(conn, opts) do
    secret = Secret.get_secret(opts.app, [:cinder], :secret_key_base)
    %{conn | secret_key_base: secret}
  end
end
