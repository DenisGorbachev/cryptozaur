defmodule Cryptozaur.DriverSupervisor do
  use Supervisor
  import OK, only: [success: 1, failure: 1]

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = [
      {Registry, [keys: :unique, name: Cryptozaur.Drivers]},
      {Registry, [keys: :unique, name: Cryptozaur.WebsocketStreams]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def get_public_driver(module) do
    get_driver(:public, :secret, module)
  end

  def get_driver(key, secret, module) do
    driver_id = driver_id(key, module)

    if driver_exists?(driver_id) do
      success(via(driver_id))
    else
      create_driver(key, secret, module)
    end
  end

  defp driver_exists?(id) do
    Registry.lookup(Cryptozaur.Drivers, id) != []
  end

  defp create_driver(key, secret, module) do
    #    debug ">> DriverSupervisor.create_driver(#{inspect key}, #{inspect "secret"}, #{inspect Atom.to_string(module)})"
    id = driver_id(key, module)
    tuple = via(id)
    start = {module, :start_link, [%{key: key, secret: secret}, [name: tuple]]}

    result =
      case Supervisor.start_child(__MODULE__, {id, start, :transient, :infinity, :worker, [module]}) do
        success(_) ->
          success(tuple)

        #      {:error, {:already_started, _pid}} -> {:error, :process_already_exists}
        # because of concurrent access it may happen so let it pass
        failure({:already_started, _}) ->
          success(tuple)

        other ->
          failure(other)
      end

    #    debug "<< DriverSupervisor.create_driver(#{inspect key}, #{inspect "secret"}, #{inspect Atom.to_string(module)}) = #{inspect result}"
    result
  end

  defp via(id) do
    {:via, Registry, {Cryptozaur.Drivers, id}}
  end

  defp driver_id(key, module) do
    {key, module}
  end
end
