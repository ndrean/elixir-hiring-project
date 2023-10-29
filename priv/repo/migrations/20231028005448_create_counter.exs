defmodule Counter.Repo.Migrations.CreateCounter do
  use Ecto.Migration

  def change do
    create table(:counters) do
      add :count, :integer
      add :region, :string

      timestamps()
    end
  end
end
