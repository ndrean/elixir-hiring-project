defmodule LiveviewCounter.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    LiveviewCounter.Release.migrate()

    # topologies = [
    #   epdm: [
    #     strategy: Cluster.Strategy.LocalEpmd
    #   ]
    # ]

    children = [
      # {Cluster.Supervisor, [topologies, [name: LiveViewCounter.ClusterSupervisor]]},
      Counter.Repo,
      LiveviewCounterWeb.Telemetry,
      {DNSCluster, query: System.get_env("DNS_CLUSTER_QUERY") || :ignore},
      {Phoenix.PubSub, name: LiveviewCounter.PubSub},
      LiveviewCounterWeb.Endpoint,
      LiveviewCounter.Presence
    ]

    opts = [strategy: :one_for_one, name: LiveviewCounter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    LiveviewCounterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
