defmodule Counter do
  use Ecto.Schema
  alias Counter.Repo

  schema "counters" do
    field(:count, :integer)
    field(:region, :string)

    timestamps()
  end

  def changeset(counter \\ %Counter{}, params \\ %{}) do
    counter
    |> Ecto.Changeset.cast(params, [:count, :region])
  end

  def update(region, change) do
    binding() |> dbg()

    case Repo.get_by(Counter, region: region) do
      nil ->
        %Counter{}
        |> Counter.changeset(%{region: region, count: 1})
        |> Repo.insert!()

      exists ->
        exists
        |> Counter.changeset(%{count: exists.count + change})
        |> Repo.update!()
    end
    |> dbg()
  end

  def find_count(region) do
    case Repo.get_by(Counter, region: region) do
      nil -> 0
      counter -> counter.count
    end
  end

  def total_count do
    Counter.Repo.aggregate(Counter, :sum, :count)
  end
end
