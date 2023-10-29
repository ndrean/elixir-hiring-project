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
    case Repo.get_by(Counter, region: region) do
      nil ->
        Repo.insert!(%Counter{region: region, count: 1})

      exists ->
        Counter.changeset(exists, %{count: exists.count + change})
        |> Repo.update!()
    end
  end

  def find(region) do
    case Repo.get_by(Counter, region: region) do
      nil -> 0
      counter -> counter.count
    end
  end

  def total_count do
    Counter.Repo.aggregate(Counter, :sum, :count)
  end
end
