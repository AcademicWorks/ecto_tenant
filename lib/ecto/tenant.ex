defmodule Ecto.Tenant do

  @callback tenants :: [Keyword.t]

  defmacro __using__(opts \\ []) do
    quote do

      @otp_app unquote(opts[:otp_app])
      @behaviour Ecto.Tenant

      def tenants do
        Application.get_env(@otp_app, __MODULE__, [])
        |> Keyword.get(:tenants, [])
      end

      def repos do
        Application.get_env(@otp_app, __MODULE__, [])
        |> Keyword.get(:repos, [])
      end

    end
  end

end
