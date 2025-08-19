defmodule BeaconDbclient.Repo.Migrations.CreateOpsFlags do
  use Ecto.Migration

  def change do
    create table(:ops_flags) do
      add :key, :string, null: false
      add :value, :map, default: %{}
      timestamps()
    end

    create unique_index(:ops_flags, [:key])
  end
end
