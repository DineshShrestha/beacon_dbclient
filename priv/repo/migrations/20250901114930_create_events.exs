defmodule BeaconDbclient.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :device_id, :string, null: false
      add :plate, :string, null: false
      add :confidence, :float
      add :snapshot_url, :text
      add :decision, :string, null: false
      add :reason, :string
      add :meta, :map, default: %{}
      timestamps(type: :utc_datetime_usec)
    end

    create index(:events, [:plate])
    create index(:events, [:inserted_at])
  end
end
