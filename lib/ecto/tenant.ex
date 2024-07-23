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

      def tenant_config(name) do
        Enum.find(tenants(), & &1[:name] == name)
      end

      def repos do
        Application.get_env(@otp_app, __MODULE__, [])
        |> Keyword.get(:repos, [])
      end

      def repo_config(name) do
        base_config = Application.get_env(@otp_app, __MODULE__, [])

        config = if name == __MODULE__ do
          base_config
        else
          config = Enum.find(repos(), & &1[:name] == name) ||
            raise ArgumentError, "repo #{inspect name} not found"
          Keyword.merge(base_config, config)
        end

        Keyword.drop(config, [:tenants, :repos])
      end

    end
  end

end
