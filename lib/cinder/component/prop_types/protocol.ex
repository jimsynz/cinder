defmodule Cinder.Component.PropType.Protocol do
  @moduledoc """
  Validate that there is an implementation of the protocol for the value.
  """

  @doc "Validate value implements protocol"
  @spec validate(any, module) :: {:ok, any} | {:error, binary}
  def validate(struct, protocol) when is_struct(struct) and is_atom(protocol) do
    with :ok <- validate_is_protocol(protocol),
         :ok <- validate_is_impl_or_any(protocol, struct.__struct__) do
      {:ok, struct}
    end
  end

  def validate(value, protocol) when is_atom(value) and is_atom(protocol) do
    impl =
      if String.starts_with?(to_string(value), "Elixir.") do
        value
      else
        Atom
      end

    with :ok <- validate_is_protocol(protocol),
         :ok <- validate_is_impl_or_any(protocol, impl) do
      {:ok, value}
    end
  end

  def validate(value, protocol) when is_list(value) and is_atom(protocol) do
    with :ok <- validate_is_protocol(protocol),
         :ok <- validate_is_impl_or_any(protocol, List) do
      {:ok, value}
    end
  end

  def validate(value, protocol) when is_tuple(value) and is_atom(protocol) do
    with :ok <- validate_is_protocol(protocol),
         :ok <- validate_is_impl_or_any(protocol, Tuple) do
      {:ok, value}
    end
  end

  def validate(value, protocol) when is_bitstring(value) and is_atom(protocol) do
    with :ok <- validate_is_protocol(protocol),
         :ok <- validate_is_impl_or_any(protocol, BitString) do
      {:ok, value}
    end
  end

  def validate(value, protocol) when is_integer(value) and is_atom(protocol) do
    with :ok <- validate_is_protocol(protocol),
         :ok <- validate_is_impl_or_any(protocol, Integer) do
      {:ok, value}
    end
  end

  def validate(value, protocol) when is_float(value) and is_atom(protocol) do
    with :ok <- validate_is_protocol(protocol),
         :ok <- validate_is_impl_or_any(protocol, Float) do
      {:ok, value}
    end
  end

  def validate(value, protocol) when is_function(value) and is_atom(protocol) do
    with :ok <- validate_is_protocol(protocol),
         :ok <- validate_is_impl_or_any(protocol, Function) do
      {:ok, value}
    end
  end

  def validate(value, protocol) when is_pid(value) and is_atom(protocol) do
    with :ok <- validate_is_protocol(protocol),
         :ok <- validate_is_impl_or_any(protocol, PID) do
      {:ok, value}
    end
  end

  def validate(value, protocol) when is_map(value) and is_atom(protocol) do
    with :ok <- validate_is_protocol(protocol),
         :ok <- validate_is_impl_or_any(protocol, Map) do
      {:ok, value}
    end
  end

  def validate(value, protocol) when is_port(value) and is_atom(protocol) do
    with :ok <- validate_is_protocol(protocol),
         :ok <- validate_is_impl_or_any(protocol, Port) do
      {:ok, value}
    end
  end

  def validate(value, protocol) when is_reference(value) and is_atom(protocol) do
    with :ok <- validate_is_protocol(protocol),
         :ok <- validate_is_impl_or_any(protocol, value) do
      {:ok, value}
    end
  end

  def validate(value, protocol) when is_atom(protocol) do
    with :ok <- validate_is_protocol(protocol),
         :ok <- validate_is_impl(protocol, Any) do
      {:ok, value}
    end
  end

  defp validate_is_protocol(protocol) do
    Protocol.assert_protocol!(protocol)
    :ok
  rescue
    ArgumentError -> {:error, "Expected `#{inspect(protocol)}` to be a protocol"}
  end

  defp validate_is_impl(protocol, impl) do
    Protocol.assert_impl!(protocol, impl)
    :ok
  rescue
    ArgumentError -> {:error, "Expected `#{inspect(impl)}` to implement `#{inspect(protocol)}`"}
  end

  defp validate_is_impl_or_any(protocol, impl) do
    with {:error, error} <- validate_is_impl(protocol, impl),
         {:error, _} <- validate_is_impl(protocol, Any) do
      {:error, error}
    end
  end
end
