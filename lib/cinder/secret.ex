defmodule Cinder.Secret do
  @moduledoc """
  A behaviour for retrieving secrets.

  Some configuration options in Cinder are not supposed to be just hard-coded in
  the configuration (eg `cinder.secret_key_base`) and should instead be stored
  somewhere else like the Application or System environment.

  If you implement this behaviour then you can use your module as the argument
  to the secret in the DSL and `secret/1` will be called when needed.

  The default implementation is `Cinder.Secret.AnonFn` which allows you to place
  anonymous functions in your DSL.
  """

  alias Spark.Dsl.Extension

  @callback secret(secret_name :: atom, options :: list) :: {:ok, String.t()} | :error

  @doc false
  @spec __using__(any) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      @behaviour Cinder.Secret
    end
  end

  @doc """
  Attempt to retrieve a secret from the configuration.

  ## Example

  ```elixir
  Example.App
  |> Cinder.Secret.fetch_secret([:cinder], :secret_key_base)
  {:ok, "Marty McFly"}
  ```
  """
  @spec fetch_secret(module, [atom], atom) :: {:ok, String.t()} | :error
  def fetch_secret(app, dsl_path, option_name) do
    app
    |> Extension.get_opt(dsl_path, option_name)
    |> case do
      value when is_binary(value) -> {:ok, value}
      {module, opts} -> module.secret(option_name, opts)
    end
  end

  @doc """
  Attempt to retrieve a secret from the configuration (or default).
  """
  @spec get_secret(module, [atom], atom, String.t() | nil) :: String.t() | nil
  def get_secret(app, dsl_path, option_name, default \\ nil) do
    case fetch_secret(app, dsl_path, option_name) do
      {:ok, value} -> value
      :error -> default
    end
  end
end
