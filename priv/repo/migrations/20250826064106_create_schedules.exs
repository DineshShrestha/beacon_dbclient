defmodule BeaconDbclient.Repo.Migrations.CreateSchedules do
  use Ecto.Migration

  def change do
    create table(:schedules) do
      add :key, :string, null: false
      add :tz, :string, null: false, default: "Europe/Oslo"
      add :weekly, :map, null: false, default: %{}
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:schedules, [:key])
  end
end
