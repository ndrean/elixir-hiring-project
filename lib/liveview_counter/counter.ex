defmodule LiveviewCounter.Count do
  use GenServer

  alias Phoenix.PubSub

  @name :count_server

  # @start_value 0

  def fly_region do
    System.get_env("FLY_REGION", "unknown")
  end

  def topic do
    "count"
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

  def init(_) do
    start_count = Counter.find(fly_region())
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

  defp make_change(count, change) do
    new_count = count + change
    Counter.update(fly_region(), change)
    PubSub.broadcast(LiveviewCounter.PubSub, topic(), {:count, new_count, :region, fly_region()})
    {:reply, new_count, new_count}
  end
end
