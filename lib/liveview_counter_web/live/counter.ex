defmodule LiveviewCounterWeb.Counter do
  use Phoenix.LiveView

  alias LiveviewCounter.Count
  alias Phoenix.PubSub
  alias LiveviewCounter.Presence

  @topic Count.topic()
  @init "init"
  @presence_topic "presence"

  def mount(_params, _session, socket) do
    :ok = PubSub.subscribe(LiveviewCounter.PubSub, @topic)
    :ok = LiveviewCounterWeb.Endpoint.subscribe(@presence_topic)
    :ok = LiveviewCounterWeb.Endpoint.subscribe(@init)

    # capture the tracker_id to avoid double counting
    {:ok, tracker_id} =
      if connected?(socket),
        do:
          Presence.track(self(), @presence_topic, socket.id, %{
            region: fly_region()
          }),
        else: {:ok, nil}

    # avoid unnecessary DB calls by doing this once the WS mounted,
    # hence a guard is needed in the template (if @counts...)
    {present, init_counts, total} =
      case connected?(socket) do
        true -> init_state()
        false -> {%{}, 0, 0}
      end

    {:ok,
     assign(socket,
       total: total,
       counts: init_counts,
       present: present,
       region: fly_region(),
       tracker_id: tracker_id
     )}
  end

  def fly_region do
    System.get_env("FLY_REGION", "unknown")
  end

  def init_state do
    list = Presence.list(@presence_topic)
    present = presence_by_region(list, nil)
    init_c = init_counts_by_region(present)
    init_tot = Counter.total_count()
    # signal to other users
    :ok = PubSub.broadcast(LiveviewCounter.PubSub, @init, init_c)
    {present, init_c, init_tot}
  end

  def handle_event("inc", _, %{assigns: %{counts: counts}} = socket) do
    c = Count.incr()
    {:noreply, assign(socket, counts: Map.put(counts, fly_region(), c))}
  end

  def handle_event("dec", _, %{assigns: %{counts: counts}} = socket) do
    c = Count.decr()
    {:noreply, assign(socket, counts: Map.put(counts, fly_region(), c))}
  end

  def handle_event("ping", _, socket) do
    {:reply, %{}, socket}
  end

  def handle_info(
        {:count, count, :region, region},
        %{assigns: %{counts: counts}} = socket
      ) do
    new_counts = Map.put(counts, region, count) |> dbg()

    {:noreply, assign(socket, counts: new_counts)}
  end

  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}} = _msg,
        %{assigns: %{present: present}} = socket
      ) do
    adds = presence_by_region(joins, socket.assigns.tracker_id)
    subtracts = presence_by_region(leaves, socket.assigns.tracker_id) |> dbg()

    new_present =
      Map.merge(present, adds, fn _k, v1, v2 ->
        v1 + v2
      end)

    new_present =
      Map.merge(new_present, subtracts, fn _k, v1, v2 ->
        v1 - v2
      end)

    counts = update_counts_on_leave(new_present, subtracts, socket.assigns.counts)

    {:noreply, assign(socket, present: new_present, counts: counts)}
  end

  # whenever a user mounts, he broadcasts new counts to update the view.
  # In case of large JSON, this should be improved.
  # perhaps <https://github.com/Miserlou/live_json>?

  def handle_info(counts, socket) when is_map(counts) do
    {:noreply, assign(socket, counts: counts)}
  end

  def presence_by_region(presence, tracker_id) do
    presence
    |> Enum.map(&elem(&1, 1))
    |> Enum.flat_map(&Map.get(&1, :metas))
    |> Enum.filter(&Map.has_key?(&1, :region))
    # don't count twice the user by filtering on the tracker_id
    |> Enum.filter(&(Map.get(&1, :phx_ref) != tracker_id))
    |> Enum.group_by(&Map.get(&1, :region))
    |> Enum.sort_by(&elem(&1, 0))
    |> Map.new(fn {k, v} -> {k, length(v)} end)
  end

  # produce a list of maps %{region => total_clicks} by querying the DB
  def init_counts_by_region(present) do
    displayed_locations = Map.keys(present)

    Enum.zip(
      displayed_locations,
      Enum.map(displayed_locations, &Counter.find(&1))
    )
    |> Enum.into(%{})
  end

  # count total clicks of on-line users via the socket state
  def total_present(counts) do
    case counts do
      0 -> 0
      c -> Enum.sum(Map.values(c))
    end
  end

  def update_counts_on_leave(new_present, subtracts, counts) do
    key =
      case Map.keys(subtracts) |> length() do
        0 -> ""
        1 -> Map.keys(subtracts) |> hd()
      end

    case Map.get(new_present, key) do
      0 ->
        {_, counts} = Map.pop(counts, key)
        counts

      _ ->
        counts
    end
  end

  def clicks(counts, region) do
    Map.get(counts, to_string(region), 0)
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>The count of on-line users is: <%= total_present(@counts) %></h1>
      <button phx-click="dec">-</button>
      <button phx-click="inc">+</button>

      <div>
        Connected to <strong><%= @region || "?" %></strong>
      </div>
      <table>
        <tr>
          <th>Region</th>
          <th>Users</th>
          <th>Clicks</th>
        </tr>
        <%= if @counts !=0 do %>
          <tr :for={{k, v} <- @present}>
            <%= if v !=0  do %>
              <th class="region"><%!-- <img src={"https://fly.io/ui/images/#{k}.svg"} /> --%>
                <%= k %></th>
              <td><%= v %></td>
              <td><%= Map.get(@counts, to_string(k), 0) %></td>
            <% end %>
          </tr>
        <% end %>
      </table>
    </div>
    <div>
      <p><% inspect(@present) %></p>
      <%!-- <p>Latency <span id="rtt" phx-hook="RTT" phx-update="ignore"></span></p> --%>
    </div>
    """
  end
end
