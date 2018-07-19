defimpl String.Chars, for: Tuple do
  def to_string(term) do
    "{#{:erlang.tuple_to_list(term) |> Enum.map(&String.Chars.to_string(&1)) |> Enum.join(", ")}}"
  end
end
