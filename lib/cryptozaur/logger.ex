defmodule Cryptozaur.Logger do
  import Logger

  defmacro log_enter(context, level \\ :debug) do
    quote do
      set_context(unquote(context))
      log(unquote(level), build_entry_message())
    end
  end

  defmacro debug_enter(context), do: quote(do: log_enter(unquote(context), :debug))
  defmacro info_enter(context), do: quote(do: log_enter(unquote(context), :info))
  defmacro warn_enter(context), do: quote(do: log_enter(unquote(context), :warn))
  defmacro error_enter(context), do: quote(do: log_enter(unquote(context), :error))

  defmacro log_step(data, level \\ :debug) do
    quote do
      log(unquote(level), build_step_message(unquote(data)), event: %{data: to_data(unquote(data))})
    end
  end

  defmacro debug_step(data), do: quote(do: log_step(unquote(data), :debug))
  defmacro info_step(data), do: quote(do: log_step(unquote(data), :info))
  defmacro warn_step(data), do: quote(do: log_step(unquote(data), :warn))
  defmacro error_step(data), do: quote(do: log_step(unquote(data), :error))

  defmacro log_conditional_breakpoint(data, keys, now, _level \\ :debug) do
    quote do
      breakpoints = Application.get_env(:cryptozaur, :breakpoints, [])

      if unquote(now) in breakpoints and Application.get_env(:cryptozaur, :env) == :backtest do
        [["now", unquote(now)] | unquote(keys) |> Enum.map(&[Atom.to_string(&1), Map.get(unquote(data), &1)])]
        |> TableRex.Table.new(["key", "value"])
        |> TableRex.Table.render!()
        |> IO.puts()

        if !Application.put_env(:cryptozaur, :breakpoints_skip_notification, false), do: Mix.Tasks.Helpers.notify("Breakpoint", "info")
        step = Task.async(fn -> IO.gets("(Enter) to continue, (number) to advance X minutes: ") end) |> Task.await(:infinity) |> String.trim()

        if String.length(step) > 0 do
          step =
            case Integer.parse(step) do
              {result, _suffix} -> result
              :error -> 60
            end

          breakpoints = [NaiveDateTime.add(unquote(now), step * 60) | breakpoints]
          Application.put_env(:cryptozaur, :breakpoints_skip_notification, true)
          Application.put_env(:cryptozaur, :breakpoints, breakpoints)
        end
      end
    end
  end

  defmacro debug_conditional_breakpoint(data, keys, now), do: quote(do: log_conditional_breakpoint(unquote(data), unquote(keys), unquote(now), :debug))
  defmacro info_conditional_breakpoint(data, keys, now), do: quote(do: log_conditional_breakpoint(unquote(data), unquote(keys), unquote(now), :info))
  defmacro warn_conditional_breakpoint(data, keys, now), do: quote(do: log_conditional_breakpoint(unquote(data), unquote(keys), unquote(now), :warn))
  defmacro error_conditional_breakpoint(data, keys, now), do: quote(do: log_conditional_breakpoint(unquote(data), unquote(keys), unquote(now), :error))

  defmacro breakpoint(data, keys, now, level \\ :info) do
    quote do
      Application.put_env(:cryptozaur, :breakpoints, Application.get_env(:cryptozaur, :breakpoints, []) ++ [unquote(now)])
      log_conditional_breakpoint(unquote(data), unquote(keys), unquote(now), unquote(level))
    end
  end

  defmacro log_return(result \\ nil, level \\ :debug) do
    quote do
      log(unquote(level), build_exit_message(unquote(result)), event: %{result: to_data(unquote(result))})
      unquote(result)
    end
  end

  defmacro debug_return(result \\ nil), do: quote(do: log_return(unquote(result), :debug))
  defmacro info_return(result \\ nil), do: quote(do: log_return(unquote(result), :info))
  defmacro warn_return(result \\ nil), do: quote(do: log_return(unquote(result), :warn))
  defmacro error_return(result \\ nil), do: quote(do: log_return(unquote(result), :error))

  defmacro log_exit(result \\ nil, level \\ :debug) do
    quote do
      log(unquote(level), build_exit_message(unquote(result)), event: %{result: to_data(unquote(result))})
    end
  end

  defmacro debug_exit(result \\ nil), do: quote(do: log_exit(unquote(result), :debug))
  defmacro info_exit(result \\ nil), do: quote(do: log_exit(unquote(result), :info))
  defmacro warn_exit(result \\ nil), do: quote(do: log_exit(unquote(result), :warn))
  defmacro error_exit(result \\ nil), do: quote(do: log_exit(unquote(result), :error))

  defmacro source do
    quote do
      %{module: module, function: {name, arity}} = __ENV__
      "#{truncate_module_name(module)}.#{name}/#{arity}"
    end
  end

  defmacro build_entry_message, do: quote(do: ">> #{source()}")
  defmacro build_step_message(data), do: quote(do: "~~ #{to_data_string(unquote(data))} #{source()}")
  defmacro build_exit_message(data), do: quote(do: "<< #{to_data_string(unquote(data))} #{source()}")

  defmacro to_data_string(nil), do: quote(do: "")
  defmacro to_data_string(string) when is_binary(string), do: quote(do: unquote(string))
  defmacro to_data_string(map) when is_map(map), do: quote(do: "#{Map.get(unquote(map), :message)} #{inspect(unquote(map) |> Map.drop([:message]))}" |> String.trim())
  defmacro to_data_string(data), do: quote(do: "#{inspect(unquote(data))}")

  defmacro to_data(nil), do: quote(do: %{data: nil})
  defmacro to_data(string) when is_binary(string), do: quote(do: %{message: unquote(string)})
  defmacro to_data(map) when is_map(map), do: quote(do: unquote(map))
  defmacro to_data(data), do: quote(do: %{data: inspect(unquote(data))})

  def truncate_module_name(name), do: name |> Atom.to_string() |> String.replace_prefix("Elixir.", "")

  def set_context(context) when is_map(context), do: Logger.reset_metadata(context: inspect(context), timber_context: %{custom: %{application: deep_convert_dates(context)}})
  def set_context(_), do: raise("Only Map is allowed to be a context")

  def deep_convert_dates(%_{} = model) do
    Map.from_struct(model) |> deep_convert_dates()
  end

  def deep_convert_dates(map) when is_map(map) do
    map
    |> Enum.reduce(%{}, fn
      {k, %DateTime{} = v}, acc ->
        Map.put(acc, k, DateTime.to_iso8601(v))

      {k, %NaiveDateTime{} = v}, acc ->
        Map.put(acc, k, NaiveDateTime.to_iso8601(v))

      {k, v}, acc when is_map(v) ->
        new_v = deep_convert_dates(v)
        Map.put(acc, k, new_v)

      {k, v}, acc ->
        Map.put(acc, k, v)
    end)
  end

  def deep_convert_dates(data), do: data
end
