defmodule LiveviewCounterWeb.Counter do
  use Phoenix.LiveView
  # use LiveviewCounterWeb, :live_view

  alias LiveviewCounter.Count
  alias Phoenix.PubSub
  alias LiveviewCounter.Presence
  alias LiveviewCounter.Flags

  @topic Count.topic()
  @init "init"
  @presence_topic "presence"

  def mount(_params, _session, socket) do
    :ok = PubSub.subscribe(LiveviewCounter.PubSub, @topic)
    :ok = LiveviewCounterWeb.Endpoint.subscribe(@presence_topic)
    :ok = LiveviewCounterWeb.Endpoint.subscribe(@init)

    region = LiveviewCounter.Count.fly_region()

    # avoid unnecessary DB calls by doing this once the WS mounted,
    # hence a guard is needed in the template (if @counts...)
    {tracker_id, primary_node_name, present, init_counts, total, nb_online} =
      case connected?(socket) do
        true ->
          LiveviewCounter.Count.start_link(region)
          init_state(socket.id, region)

        false ->
          {nil, "", %{}, %{}, 0, 0}
      end

    {:ok,
     socket
     |> assign(
       total: total,
       counts: init_counts,
       present: present,
       region: region,
       tracker_id: tracker_id,
       nb_online: nb_online,
       primary: primary_node_name
     )}
  end

  def fly_region do
    Count.fly_region()
  end

  def get_primary_node_name(region, primary) when region == primary do
    case Node.list() do
      [] ->
        Node.self()

      list ->
        list |> Enum.sort() |> List.first()
    end
  end

  def get_primary_node_name(region, primary) when region != primary do
    case Node.list() do
      [] ->
        Process.sleep(1_000)
        get_primary_node_name(region, primary)

      list ->
        list
        |> Enum.filter(fn node ->
          :erpc.call(node, fn ->
            fly_region() == primary
          end)
        end)
        |> Enum.sort()
        |> List.first()
    end
  end

  def init_state(id, region) do
    # capture the tracker_id to avoid double counting

    {:ok, tracker_id} =
      Presence.track(self(), @presence_topic, id, %{
        region: fly_region()
      })

    primary = LiveviewCounter.Count.primary_region()

    primary_node_name = get_primary_node_name(region, primary)
    list = Presence.list(@presence_topic)
    present = presence_by_region(list, nil)
    init_c = init_counts_by_region(primary_node_name, present)
    init_tot = Count.total_count(primary_node_name)
    # signal to other users
    :ok = PubSub.broadcast(LiveviewCounter.PubSub, @init, init_c)
    {tracker_id, primary_node_name, present, init_c, init_tot, 0}
  end

  @spec handle_event(<<_::24, _::_*8>>, any(), any()) :: {:noreply, any()} | {:reply, %{}, any()}
  def handle_event("inc", _, socket) do
    %{assigns: %{counts: counts, primary: primary, region: region}} = socket
    c = Count.incr(primary, region)
    {:noreply, assign(socket, counts: Map.put(counts, region, c))}
  end

  def handle_event("dec", _, socket) do
    %{assigns: %{counts: counts, primary: primary, region: region}} = socket
    c = Count.decr(primary, region)
    {:noreply, assign(socket, counts: Map.put(counts, region, c))}
  end

  def handle_event("ping", _, socket) do
    {:reply, %{}, socket}
  end

  # msg sent from the GenServer Counter
  def handle_info({:count, count, :region, region}, socket) do
    %{assigns: %{counts: counts}} = socket
    new_counts = Map.put(counts, region, count)

    {:noreply, assign(socket, counts: new_counts)}
  end

  def handle_info(
        %{event: "presence_diff", payload: %{joins: joins, leaves: leaves}},
        socket
      ) do
    %{assigns: %{present: present, tracker_id: tracker_id}} = socket
    adds = presence_by_region(joins, tracker_id)
    subtracts = presence_by_region(leaves, tracker_id)

    new_present =
      Map.merge(present, adds, fn _k, v1, v2 ->
        v1 + v2
      end)

    new_present =
      Map.merge(new_present, subtracts, fn _k, v1, v2 ->
        v1 - v2
      end)

    nb_online = online_users(new_present)
    counts = update_counts_on_leave(new_present, subtracts, socket.assigns.counts)

    {:noreply,
     socket
     |> assign(present: new_present, counts: counts, nb_online: nb_online)}
  end

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
  def init_counts_by_region(primary, present) when is_map(present) do
    displayed_locations = Map.keys(present)

    Enum.zip(
      displayed_locations,
      Enum.map(displayed_locations, &Count.find_count(primary, &1))
    )
    |> Enum.into(%{})
  end

  def online_users(present) when is_map(present) do
    Map.values(present) |> Enum.sum()
  end

  # count total clicks of on-line users via the socket state
  def total_clicks(counts) when is_map(counts) do
    Map.values(counts) |> Enum.sum()
  end

  def update_counts_on_leave(new_present, subtracts, counts)
      when is_map(subtracts) and is_map(new_present) do
    # find the region of the user who left
    key =
      case Map.keys(subtracts) |> length() do
        0 -> ""
        1 -> Map.keys(subtracts) |> hd()
      end

    # remove from the map "counts" the data of the region if there is no more user in this region
    case Map.get(new_present, key) do
      0 ->
        {_, counts} = Map.pop(counts, key)
        counts

      _ ->
        counts
    end
  end

  def total_clicks_region(counts, region) when is_map(counts) do
    Map.get(counts, to_string(region), 0)
  end

  def render(assigns) do
    ~H"""
    <div class=" text-gray-800 p-6">
      <h1 class="text-3xl font-bold mb-4">
        Total clicks: <%= total_clicks(@counts) %>
      </h1>
      <h2 class="mb-4 text-xl">Online users: <strong><%= @nb_online %></strong></h2>
      <hr />
      <br />
      <div class="flex justify-center">
        <button
          class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
          phx-click="dec"
        >
          <Heroicons.LiveView.icon name="hand-thumb-down" type="outline" class="h-6 w-6" />
        </button>
        <button
          class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded ml-2"
          phx-click="inc"
        >
          <Heroicons.LiveView.icon name="hand-thumb-up" type="outline" class="h-6 w-6" />
        </button>
      </div>
      <div class="mt-4">
        Connected to <%= Flags.show_city(@region) %> &nbsp <%= Flags.show_flag(@region) %>
      </div>
      <table class="w-full mt-4 border-collapse border border-gray-500">
        <tr>
          <th class="border border-gray-500 p-2">Region</th>
          <th class="border border-gray-500 p-2">Users</th>
          <th class="border border-gray-500 p-2">Clicks</th>
        </tr>
        <%= if @counts !=0 do %>
          <tr :for={{k, v} <- @present}>
            <%= if v !=0  do %>
              <th class="region border border-gray-500 p-2 text-3xl">
                <%!-- <img src={"https://fly.io/ui/images/#{k}.svg"} /> --%>
                <%= Flags.get_flag(k) %> &nbsp <%= k %>
              </th>
              <td class="border border-gray-500 p-2"><%= v %></td>
              <td class="border border-gray-500 p-2"><%= total_clicks_region(@counts, k) %></td>
            <% end %>
          </tr>
        <% end %>
      </table>
      <br />
      <p>Latency:-- <span id="rtt" phx-hook="RTT" phx-update="ignore"></span></p>
    </div>
    """
  end
end
