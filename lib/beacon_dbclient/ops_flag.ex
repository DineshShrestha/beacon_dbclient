defmodule BeaconDbclient.OpsFlag do
    use Ecto.Schema
    import Ecto.Changeset

    schema "ops_flags" do
        field :key, :string
        field :value, :map, default: %{}
        timestamps() 
    end

    def changeset(flag, attrs) do
        flag
        |> cast(attrs, [:key, :value])
        |> validate_required([:key])
    end
end