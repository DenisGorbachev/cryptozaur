if Mix.env() != :prod do
  Code.compiler_options(ignore_module_conflict: true)

  defimpl String.Chars, for: Float do
    def to_string(term) do
      if term == Float.round(term, 8) do
        IO.iodata_to_binary(:io_lib.format("~.8f", [term]))
      else
        # default implementation
        IO.iodata_to_binary(:io_lib_format.fwrite_g(term))
      end
    end
  end

  defimpl Inspect, for: Float do
    def inspect(term, _opts) do
      if term == Float.round(term, 8) do
        IO.iodata_to_binary(:io_lib.format("~.8f", [term]))
      else
        # default implementation
        IO.iodata_to_binary(:io_lib_format.fwrite_g(term))
      end
    end
  end
end
