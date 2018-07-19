defmodule Cryptozaur.Metronome do
  @moduledoc false

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  def init(opts) do
    # ".000000" part is necessary, because Ecto returns datetimes with 6-numbers-precision
    from = Keyword.get(opts, :from, ~N[2017-01-01 00:00:00.000000])
    to = from
    {:ok, {from, to}}
  end

  def tick(pid, seconds \\ 1) do
    GenServer.call(pid, {:tick, seconds})
  end

  def from(pid, seconds \\ 0) do
    GenServer.call(pid, {:from, seconds})
  end

  def to(pid) do
    GenServer.call(pid, {:to})
  end

  # alias
  def now(pid), do: to(pid)

  # alias
  def offset(pid, seconds \\ 0), do: from(pid, seconds)

  def distance(pid) do
    GenServer.call(pid, {:distance})
  end

  def handle_call({:tick, seconds}, _from, {from, to}) do
    next_to = NaiveDateTime.add(to, seconds)
    {:reply, next_to, {from, next_to}}
  end

  def handle_call({:from, seconds}, _from, {from, to}) do
    {:reply, NaiveDateTime.add(from, seconds), {from, to}}
  end

  def handle_call({:to}, _from, {from, to}) do
    {:reply, to, {from, to}}
  end

  def handle_call({:offset, seconds}, _from, {from, to}) do
    {:reply, NaiveDateTime.add(from, seconds), {from, to}}
  end

  def handle_call({:distance}, _from, {from, to}) do
    {:reply, Timex.to_unix(to) - Timex.to_unix(from), {from, to}}
  end
end
