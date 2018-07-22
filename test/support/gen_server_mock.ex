defmodule GenServerMock do
  use GenServer

  def start_link(mocks, init_handler) do
    GenServer.start_link(__MODULE__, {mocks, init_handler})
  end

  def init({mocks, init_handler}) do
    init_handler.()

    {:ok, mocks}
  end

  def handle_call(request, _, mocks) do
    result = List.keytake(mocks, request, 0)

    if result do
      {{_request, response}, updated_mocks} = result
      {:reply, response, updated_mocks}
    else
      {:error, "No mock for request: #{inspect(request)}"}
    end
  end
end
