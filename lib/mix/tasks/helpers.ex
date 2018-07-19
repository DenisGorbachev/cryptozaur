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
end
