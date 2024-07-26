defmodule Ecto.Tenant.Application do
  use Application

  @impl true
  def start(_, _) do
    opts = [strategy: :one_for_one, name: Ecto.Tenant.Supervisor]

    Repo.repos()
    |> Enum.map(fn repo ->
      %{
        id: {Repo, repo[:name]},
        start: {Repo, :start_link, [repo]},
        type: :supervisor
      }
    end)
    |> Supervisor.start_link(opts)
  end
end
