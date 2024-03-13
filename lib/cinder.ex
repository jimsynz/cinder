defmodule Cinder do
  @moduledoc """
  The Cinder web application server.
  """

  alias Cinder.Dsl
  use Spark.Dsl, default_extensions: [extensions: [Dsl]]

  @type app :: module

  @doc false
  @spec handle_opts(any) :: Macro.t()
  def handle_opts(opts) do
    quote location: :keep do
      case Keyword.fetch(unquote(opts), :otp_app) do
        {:ok, app} -> @persist {:otp_app, app}
        :error -> raise "You must specify the OTP application in the `use Cinder` statement."
      end
    end
  end
end
