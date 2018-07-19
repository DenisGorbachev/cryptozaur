defmodule Cryptozaur.Utils do
  alias Cryptozaur.{Repo, Connector}

  @max_substitutions_in_prepare_statement 65535

  defmacro amazing_success(value) do
    quote do
      {:ok, unquote(value)}
    end
  end

  defmacro extreme_failure(reason) do
    quote do
      {:error, unquote(reason)}
    end
  end

  def drop_milliseconds(datetime) do
    with amazing_success(datetime_without_milliseconds) <- NaiveDateTime.from_erl(NaiveDateTime.to_erl(datetime)) do
      datetime_without_milliseconds
    else
      :error -> :error
    end
  end

  def seconds_to_millis(seconds) do
    round(seconds * 1000)
  end

  def now do
    NaiveDateTime.utc_now() |> drop_milliseconds()
  end

  def epoch do
    ~N[1970-01-01 00:00:00.000000]
  end

  def now_in_seconds do
    Timex.to_unix(Timex.now())
  end

  def to_unix(datetime) do
    Timex.to_unix(datetime)
  end

  def from_now(period) do
    to = now()
    from = NaiveDateTime.add(to, -period)
    {from, to}
  end

  def get_strategy_module_by_type(type) do
    String.to_existing_atom("Elixir.Cryptozaur.Strategies.#{type}")
  end

  def save_bulk(objects, insert_all_opts \\ [], transaction_opts \\ [timeout: :infinity, pool_timeout: :infinity])
  def save_bulk([], _insert_all_opts, _transaction_opts), do: amazing_success(0)

  def save_bulk([%{__struct__: _model} | _] = objects, insert_all_opts, transaction_opts) do
    Repo.transaction(fn -> do_save_bulk(objects, insert_all_opts) end, transaction_opts)
  end

  def do_save_bulk([%{__struct__: model} | _] = objects, insert_all_opts) do
    objects
    |> Enum.map(&to_map_without_id/1)
    |> Enum.chunk_every(chunk_size(model))
    |> Enum.map(&Repo.insert_all(model, &1, insert_all_opts))
    |> Enum.reduce(0, &(&2 + elem(&1, 0)))
  end

  def chunk_size(model) do
    Integer.floor_div(@max_substitutions_in_prepare_statement, length(model.fields))
  end

  def align_to_resolution(naive_datetime, resolution) do
    {:ok, datetime} = DateTime.from_naive(naive_datetime, "Etc/UTC")
    timestamp = DateTime.to_unix(datetime)
    remainder = rem(timestamp, resolution)
    {:ok, datetime} = DateTime.from_unix(timestamp - remainder)
    DateTime.to_naive(datetime)
  end

  def milliseconds_from_beginning_of_day(datetime) do
    timestamp = Timex.to_unix(datetime)
    rem(timestamp, 24 * 60 * 60) * 1000
  end

  def max_date(a, b) do
    if NaiveDateTime.compare(a, b) == :gt, do: a, else: b
  end

  def min_date(a, b) do
    if NaiveDateTime.compare(a, b) == :lt, do: a, else: b
  end

  def date_gte(a, b) do
    NaiveDateTime.compare(a, b) in [:gt, :eq]
  end

  def date_lte(a, b) do
    NaiveDateTime.compare(a, b) in [:lt, :eq]
  end

  def date_gt(a, b) do
    NaiveDateTime.compare(a, b) == :gt
  end

  def date_lt(a, b) do
    NaiveDateTime.compare(a, b) == :lt
  end

  def closest_to_zero(a, b) do
    if abs(a) < abs(b), do: a, else: b
  end

  def precise_amount_without_dust(symbol, amount, price) do
    [exchange, base, _quote] = to_list(symbol)
    amount = precise_amount(symbol, amount)
    dust = Connector.get_min_amount(exchange, base, price)

    if abs(amount) >= dust do
      amount
    else
      0.0
    end
  end

  def precise_amount(symbol, amount) do
    [exchange, base, quote] = to_list(symbol)
    precise_amount(exchange, base, quote, amount)
  end

  def precise_amount(exchange, base, quote, amount) do
    precision = Connector.get_amount_precision(exchange, base, quote)

    cond do
      amount > 0.0 -> Float.floor(amount, precision)
      amount < 0.0 -> Float.ceil(amount, precision)
      amount == 0.0 -> 0.0
    end
  end

  def precise_price(symbol, price) do
    [exchange, base, quote] = to_list(symbol)
    precise_price(exchange, base, quote, price)
  end

  def precise_price(exchange, base, quote, price) do
    precision = Connector.get_price_precision(exchange, base, quote)
    Float.round(price, precision)
  end

  def to_pair(symbol) do
    [_exchange, base, quote] = to_list(symbol)
    "#{base}:#{quote}"
  end

  def to_exchange(symbol) do
    [exchange, _base, _quote] = to_list(symbol)
    exchange
  end

  def to_list(symbol) do
    symbol |> String.split(":")
  end

  def get_base(symbol) do
    to_list(symbol) |> Enum.at(1)
  end

  def get_quote(symbol) do
    to_list(symbol) |> Enum.at(2)
  end

  def as_maps([%{__struct__: struct} | _] = structs) do
    structs |> Enum.map(&Map.take(&1, apply(struct, :fields, [])))
  end

  def to_maps(structs) do
    structs |> Enum.map(&to_map(&1))
  end

  def to_map(%{__meta__: __meta__} = struct) do
    association_fields = struct.__struct__.__schema__(:associations)
    waste_fields = association_fields ++ [:__meta__]
    struct |> Map.from_struct() |> Map.drop(waste_fields)
  end

  def to_map_without_id(struct) do
    struct |> to_map() |> Map.drop([:id])
  end

  def to_float(term) when is_number(term) do
    # yeah, that's the official way
    term / 1
  end

  def to_float(term) when is_binary(term) do
    {result, _} = Float.parse(term)
    result
  end

  def to_integer(term) when is_float(term) do
    round(term)
  end

  def to_integer(term) when is_binary(term) do
    {result, _} = Integer.parse(term)
    result
  end

  def defaults(map, defaults) do
    Map.merge(defaults, map, fn _key, default, value -> if is_empty(value), do: default, else: value end)
  end

  def default(value, default) do
    if value, do: value, else: default
  end

  def is_empty(value) when is_binary(value), do: String.length(value) == 0
  def is_empty(value) when is_integer(value), do: value == 0
  def is_empty(value) when is_float(value), do: value == 0.0

  # normalize return value for OK
  def mkdir(path) do
    case File.mkdir(path) do
      :ok -> {:ok, path}
      {:error, :eexist} -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  def format_float(float, precision) do
    :erlang.float_to_binary(float, decimals: precision)
  end

  def format_amount(exchange, base, quote, amount) do
    format_float(amount, Connector.get_amount_precision(exchange, base, quote))
  end

  def format_price(exchange, base, quote, price) do
    format_float(price, Connector.get_price_precision(exchange, base, quote))
  end

  def all_ok(enum, default) do
    Enum.find(enum, amazing_success(default), &match?(extreme_failure(_), &1))
  end

  def from_satoshi(price, quote) do
    if quote in ["BTC", "ETH"] and price > 1.0, do: price * 0.00000001, else: price
  end

  def bangify(result) do
    case result do
      {:ok, value} -> value
      {:error, error} -> raise error
    end
  end

  def parse!(json) do
    try do
      Poison.Parser.parse!(json)
    rescue
      e in Poison.SyntaxError -> raise %{e | message: "#{e.message} (trying to parse \"#{json}\")"}
    end
  end

  def parse(json) do
    try do
      amazing_success(Poison.Parser.parse!(json))
    rescue
      e in Poison.SyntaxError -> extreme_failure(e.message)
    end
  end

  def execute_for_symbols(module, args) do
    Application.get_env(:cryptozaur, :symbols, [])
    |> Enum.map(&Task.async(module, :execute, [&1 | args]))
    |> Enum.map(&Task.await(&1, :infinity))
  end

  def difference_normalized_by_midpoint(a, b) do
    (b - a) / ((a + b) / 2)
  end

  def difference_normalized_by_startpoint(a, b) do
    (b - a) / a
  end

  def sign(value) do
    if value > 0.0, do: 1.0, else: -1.0
  end

  def identity(value) do
    value
  end

  def between(low, current, high) do
    low <= current and current <= high
  end

  def not_more_than(a, b) do
    min(a, b)
  end

  def not_more_than_with_dust(a, b, symbol, price) do
    [exchange, base, _quote] = to_list(symbol)
    dust = Connector.get_min_amount(exchange, base, price)
    if a - b < dust, do: a, else: min(a, b)
  end

  def not_less_than(a, b) do
    max(a, b)
  end

  def not_less_than_with_dust(a, b, symbol, price) do
    [exchange, base, _quote] = to_list(symbol)
    dust = Connector.get_min_amount(exchange, base, price)
    if a - b > -dust, do: a, else: max(a, b)
  end

  def key(map, value) when is_map(map) do
    map
    |> Enum.find(fn {_key, val} -> val == value end)
    |> elem(0)
  end

  def value(list, key, default \\ nil) when is_list(list) do
    value = List.keyfind(list, key, 0)
    if value, do: elem(value, 1), else: default
  end

  def pluck(enumerable, key) do
    Enum.map(enumerable, &Map.get(&1, key))
  end

  def pluck_all(enumerable, keys) do
    Enum.map(enumerable, &Map.take(&1, keys))
  end

  def apply_mfa({module, function, arguments}, extra_arguments) do
    apply(module, function, arguments ++ extra_arguments)
  end

  def metacall(module, name, data, params, now) do
    module = Map.get(params, "#{name}_module", Atom.to_string(module)) |> String.to_atom()
    function = Map.get(params, "#{name}_function") |> String.to_atom()
    params = Map.get(params, "#{name}_params", %{})
    module = (Code.ensure_loaded(module) && function_exported?(module, function, 3) && module) || Cryptozaur.Strategy
    apply(module, function, [data, params, now])
  end

  def atomize_keys(map) do
    for {key, val} <- map, into: %{}, do: {String.to_atom(key), val}
  end

  def ensure_atoms_map([]), do: []
  def ensure_atoms_map(%{__struct__: _} = value), do: value

  def ensure_atoms_map(value) do
    if is_map(value) || Keyword.keyword?(value) do
      Enum.into(value, %{}, fn {k, v} ->
        {ensure_atom(k), ensure_atoms_map(v)}
      end)
    else
      value
    end
  end

  def ensure_atom(value) when is_bitstring(value), do: String.to_atom(value)
  def ensure_atom(value) when is_atom(value), do: value

  def pluralize(string, count, suffix \\ "s"), do: string <> if(count == 1, do: "", else: suffix)

  def unwrap(tuple) do
    {:ok, result} = tuple
    result
  end

  def check_success(tuple, error) do
    case tuple do
      amazing_success(result) -> amazing_success(result)
      _ -> extreme_failure(error)
    end
  end

  def check_success_true(tuple, error) do
    case tuple do
      amazing_success(true) -> amazing_success(true)
      _ -> extreme_failure(error)
    end
  end

  # Integer.parse, Map.fetch, ...
  def check_success_unwrapped(result, error) do
    case result do
      :error -> extreme_failure(error)
      result -> amazing_success(result)
    end
  end

  def check_if(value, error) do
    if value, do: amazing_success(value), else: extreme_failure(error)
  end

  def is_struct(map) do
    Map.has_key?(map, :__struct__)
  end

  def increment_nonce(state) do
    Map.get_and_update(state, :nonce, fn nonce -> {nonce, nonce + 1} end)
  end

  def is_backtest() do
    Application.get_env(:cryptozaur, :env) == :test or Application.get_env(:cryptozaur, Cryptozaur.Backtester) != nil
  end

  def ohlc4(candle) do
    (candle.open + candle.high + candle.low + candle.close) / 4
  end

  def amount_from_capital(symbol, capital, price) do
    precise_amount_without_dust(symbol, capital / price, price)
  end

  def embed_with_key(map, key) do
    map |> Enum.map(&{"#{key}_#{elem(&1, 0)}", elem(&1, 1)}) |> Enum.into(%{})
  end

  def ensure_all_candles_present(list, resolution) do
    [head | tail] = list
    [head | tail |> Enum.flat_map_reduce(head, &ensure_candle_present(&1, &2, resolution)) |> elem(0)]
  end

  def ensure_candle_present(%{__struct__: struct_module} = current_candle, previous_candle, resolution) do
    gap = NaiveDateTime.diff(current_candle.timestamp, previous_candle.timestamp) / resolution
    if gap - Float.round(gap) != 0.0, do: raise("Gap is not a whole number (#{gap})")
    gap = to_integer(gap)

    candles =
      if gap > 1 do
        for i <- 2..gap do
          struct(
            struct_module,
            open: previous_candle.close,
            high: previous_candle.close,
            low: previous_candle.close,
            close: previous_candle.close,
            timestamp: previous_candle.timestamp |> NaiveDateTime.add((i - 1) * resolution)
          )
        end ++ [current_candle]
      else
        [current_candle]
      end

    {candles, current_candle}
  end
end

defmodule Cryptozaur.Utils.Stream do
  def time(from, to, resolution \\ 1, comparator \\ &Cryptozaur.Utils.date_lte/2) do
    from = Cryptozaur.Utils.align_to_resolution(from, resolution)
    to = Cryptozaur.Utils.align_to_resolution(to, resolution)

    Stream.unfold(from, fn timestamp ->
      if comparator.(timestamp, to) do
        {timestamp, NaiveDateTime.add(timestamp, resolution)}
      else
        nil
      end
    end)
  end
end
