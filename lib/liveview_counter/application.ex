defmodule LiveviewCounter.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    require Logger
    Logger.info(Application.get_env(:liveview_counter, :dns_cluster_query))

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
      # {DNSCluster, query: Application.get_env(:liveview_counter, :dns_cluster_query) || :ignore},
      {DNSCluster, query: "liveview-counter.internal"},
      {Phoenix.PubSub, name: LiveviewCounter.PubSub},
      LiveviewCounterWeb.Endpoint,
      LiveviewCounter.Count,
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
