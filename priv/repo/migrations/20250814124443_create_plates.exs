defmodule BeaconDbclient.Repo.Migrations.CreatePlates do
  use Ecto.Migration

  def change do
    create table(:plates) do
      add :plate, :string, null: false
      add :owner, :string
      add :enabled, :boolean, default: true, null: false
      add :valid_from, :utc_datetime_usec
      add :valid_to, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:plates, [:plate])
  end
end
