defmodule LiveviewCounter.Count do
  use GenServer

  alias Phoenix.PubSub

  @name :count_server

  # @start_value 0

  def fly_region, do: System.get_env("FLY_REGION", "unknown")

  def primary_region, do: System.get_env("PRIMARY_REGION", "unknown")

  def topic, do: "count"

  def start_link(region) do
    GenServer.start_link(__MODULE__, region, name: @name)
  end

  def incr(primary, region) do
    GenServer.call(@name, {:incr, primary, region})
  end

  def decr(primary, region) do
    GenServer.call(@name, {:decr, primary, region})
  end

  # def current() do
  #   GenServer.call(@name, :current)
  # end

  def find_count(primary, region) do
    GenServer.call(@name, {:find_count, primary, region})
  end

  def total_count(primary) do
    GenServer.call(@name, {:total, primary})
  end

  def init(region) do
    c = Counter.find_count(region) |> dbg()
    {:ok, c}
  end

  # def handle_call(:current, _from, count) do
  #   {:reply, count, count}
  # end

  def handle_call({:incr, primary, region}, _from, count) do
    make_change(primary, region, count, +1)
  end

  def handle_call({:decr, primary, region}, _from, count) do
    make_change(primary, region, count, -1)
  end

  def handle_call({:find_count, primary, region}, _from, count) do
    c = :erpc.call(primary, fn -> Counter.find_count(region) end)
    {:reply, c, count}
  end

  def handle_call({:total, primary}, _from, count) do
    t = :erpc.call(primary, &Counter.total_count/0)
    {:reply, t, count}
  end

  defp make_change(primary, region, count, change)
       when is_integer(count) and is_integer(change) do
    new_count = count + change
    :erpc.call(primary, fn -> Counter.update(region, change) end)
    :ok = PubSub.broadcast(LiveviewCounter.PubSub, topic(), {:count, new_count, :region, region})
    {:reply, new_count, new_count}
  end
end
