defmodule BeaconDbclient.DBSafe do
  @danger ~r/^\s*(update|delete|truncate|drop|alter)\b/i

  def check!(sql, safe_mode? \\ true)
  def check!(_sql, false), do: :ok

  def check!(sql, true) do
    if Regex.match?(@danger, sql) do
      if String.match?(sql, ~r/\bwhere\b/i),
        do: :ok,
        else: raise("Blocked dangerous query (no WHERE) in safe mode")
    else
      :ok
    end
  end
end
