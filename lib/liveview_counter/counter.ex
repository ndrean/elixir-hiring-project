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
    {:ok, start_count}
  end

  def handle_call(:current, _from, count) do
    {:reply, count, count}
  end

  def handle_call(:incr, _from, count) do
    make_change(count, +1)
  end

  def handle_call(:decr, _from, count) do
    make_change(count, -1)
  end

  def handle_call({:find_count, region}, _from, count) do
    c = Counter.find_count(region)
    # c = :erpc.call(primary_node(), fn -> Counter.find_count(region) end)
    {:reply, c, count}
  end

  def handle_call(:total, _from, count) do
    t = Counter.total_count()
    # t = :erpc.call(primary_node(), &Counter.total_count/0)
    {:reply, t, count}
  end

  defp make_change(count, change) when is_integer(count) and is_integer(change) do
    new_count = count + change
    region = fly_region()
    Counter.update(region, change)
    # :erpc.call(primary_node(), fn -> Counter.update(region, change) end)
    :ok = PubSub.broadcast(LiveviewCounter.PubSub, topic(), {:count, new_count, :region, region})
    {:reply, new_count, new_count}
  end
end
