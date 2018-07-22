defmodule Mix.Tasks.Helpers do
  def notify(message, type \\ "info") do
    #    if (Mix.shell.cmd("which notify-send") == 0) do
    #      0 = Mix.shell.cmd("notify-send --expire-time 1440000 Leverex '#{message}'")
    #    end
    if Mix.shell().cmd("which zenity") == 0 do
      0 = Mix.shell().cmd("(sleep 1 && wmctrl -F -a 'Leverex notification' -b add,above) & (zenity --#{type} --text='#{message}' --title='Leverex notification')")
    end

    # TODO: implement desktop notification for OSX
  end

  def read_json(filename) do
    case File.read(filename) do
      {:ok, content} -> {:ok, Poison.decode!(content, keys: :atoms)}
      {:error, :enoent} -> {:ok, %{}}
      {:error, reason} -> {:error, %{message: "Can't read #{filename}", reason: reason}}
    end
  end

  def write_json(filename, content) do
    File.mkdir_p!(Path.dirname(filename))

    case File.write(filename, Poison.encode!(content, pretty: true)) do
      :ok -> {:ok, true}
      {:error, reason} -> {:error, %{message: "Can't write #{filename}", reason: reason}}
    end
  end
end
