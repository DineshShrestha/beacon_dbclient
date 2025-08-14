defmodule BeaconDbclient.Plates do
  # import Ecto.Query, only: [from: 2]
  alias BeaconDbclient.{Repo}
  alias BeaconDbclient.Plates.Plate

  def upsert(attrs) do
    plate = String.upcase(Map.fetch!(attrs, "plate"))
    attrs = Map.put(attrs, "plate", plate)

    case Repo.get_by(Plate, plate: plate) do
      nil ->
        %Plate{} |> Plate.changeset(attrs) |> Repo.insert()

      %Plate{} = p ->
        p |> Plate.changeset(attrs) |> Repo.update()
    end
  end

  def check(plate_str, now \\ DateTime.utc_now()) do
    plate = String.upcase(plate_str)

    case Repo.get_by(Plate, plate: plate) do
      nil ->
        {:deny, :not_found}

      %Plate{enabled: false} ->
        {:deny, :disabled}

      %Plate{valid_from: vf, valid_to: vt} ->
        cond do
          not within?(now, vf, vt) -> {:deny, :out_of_window}
          true -> {:allow, :match}
        end
    end
  end

  defp within?(_now, nil, nil), do: true
  defp within?(now, %DateTime{} = vf, nil), do: DateTime.compare(now, vf) != :lt
  defp within?(now, nil, %DateTime{} = vt), do: DateTime.compare(now, vt) != :gt

  defp within?(now, %DateTime{} = vf, %DateTime{} = vt) do
    DateTime.compare(now, vf) != :lt and DateTime.compare(now, vt) != :gt
  end
end
