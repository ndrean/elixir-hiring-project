defmodule LiveviewCounter.Count do
  use GenServer

  alias Phoenix.PubSub

  @name :count_server

  # @start_value 0

  def fly_region, do: System.fetch_env!("FLY_REGION")

  def primary_region, do: System.fetch_env!("PRIMARY_REGION")

  def topic, do: "count"

  def primary_node do
    case Node.list() do
      [] ->
        Node.self()

      list ->
        case Enum.find(list, fn node -> :erpc.call(node, &fly_region/0) == primary_region() end) do
          nil -> Node.self()
          node -> node
        end
    end
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: @name)
  end

  def incr() do
    GenServer.call(@name, :incr)
  end

  def decr() do
    GenServer.call(@name, :decr)
  end

  def current() do
    GenServer.call(@name, :current)
  end

  def find_count(region) do
    GenServer.call(@name, {:find_count, region})
  end

  def total_count do
    GenServer.call(@name, :total)
  end

  def init(_) do
    start_count = Counter.find_count(fly_region())
    p_node = primary_node() |> dbg()
    {:ok, {start_count, p_node}}
  end

  def handle_call(:current, _from, {count, p_node}) do
    {:reply, count, {count, p_node}}
  end

  def handle_call(:incr, _from, {count, p_node}) do
    make_change(p_node, count, +1)
  end

  def handle_call(:decr, _from, {count, p_node}) do
    make_change(p_node, count, -1)
  end

  def handle_call({:find_count, region}, _from, {count, p_node}) do
    # c = Counter.find_count(region)
    p_node |> dbg()
    p1 = primary_node()
    if p1 === p_node, do: true, else: false |> dbg()
    c = :erpc.call(p1, fn -> Counter.find_count(region) end)
    {:reply, c, {count, p_node}}
  end

  def handle_call(:total, _from, {count, p_node}) do
    # t = Counter.total_count()
    p1 = primary_node()
    if p1 === p_node, do: true, else: false |> dbg()
    t = :erpc.call(p1, &Counter.total_count/0)
    {:reply, t, {count, p_node}}
  end

  defp make_change(p_node, count, change) when is_integer(count) and is_integer(change) do
    new_count = count + change
    # Counter.update(fly_region(), change)
    region = fly_region()
    p1 = primary_node()
    if p1 === p_node, do: true, else: false |> dbg()
    :erpc.call(p1, fn -> Counter.update(region, change) end)
    :ok = PubSub.broadcast(LiveviewCounter.PubSub, topic(), {:count, new_count, :region, region})
    {:reply, new_count, {new_count, p_node}}
  end
end
