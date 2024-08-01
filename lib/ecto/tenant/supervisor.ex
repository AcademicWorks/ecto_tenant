defmodule Ecto.Tenant.Supervisor do
  @moduledoc false

  def child_spec(config) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [config]},
      type: :supervisor
    }
  end

  def start_link(config \\ []) do
    repo_module = Keyword.fetch!(config, :repo_module)

    repo_module.dynamic_repo_configs()
    |> Enum.map(fn repo ->
      %{
        id: {repo_module, repo[:name]},
        start: {repo_module, :start_link, [repo]},
        type: :supervisor
      }
    end)
    |> Supervisor.start_link(strategy: :one_for_one, name: __MODULE__)
  end

  def stop do
    Supervisor.stop(__MODULE__)
  end

end
