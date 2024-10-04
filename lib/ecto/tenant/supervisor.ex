defmodule Ecto.Tenant.Supervisor do
  @moduledoc false

  defmacro __using__(opts \\ []) do

    quote bind_quoted: [opts: opts] do

      defmodule Supervisor do

        @repo opts[:repo]

        def child_spec(config \\ []) do
          %{
            id: {__MODULE__, @repo},
            start: {__MODULE__, :start_link, [config]},
            type: :supervisor
          }
        end

        def start_link(config_arg \\ []) do
          repo_config = @repo.config()
          |> Keyword.drop([:repos, :tenants])

          children = case @repo.dynamic_repo_configs() do
            [] -> [single_repo_child(repo_config, config_arg)]
            dyn_repo_configs -> dynamic_repo_children(repo_config, dyn_repo_configs, config_arg)
          end

          Elixir.Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
        end

        def stop do
          Elixir.Supervisor.stop(__MODULE__)
        end

        defp single_repo_child(repo_config, config_arg) do
          config = Keyword.merge(repo_config, config_arg)
          %{
            id: __MODULE__,
            start: {@repo, :start_link, [config]}
          }
        end

        defp dynamic_repo_children(repo_config, dyn_repo_configs, config_arg) do
          Enum.map(dyn_repo_configs, fn dyn_repo_config ->
            config =
              repo_config
              |> Keyword.merge(dyn_repo_config)
              |> Keyword.merge(config_arg)

            {name, config} = Keyword.pop!(config, :name)
            config = Keyword.put(:name, {:global, {@repo, name}})

            %{
              id: {__MODULE__, name},
              start: {@repo, :start_link, [config]},
            }
          end)
        end

      end

    end

  end

end
