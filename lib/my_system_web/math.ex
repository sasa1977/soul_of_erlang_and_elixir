defmodule MySystemWeb.Math do
  use MySystemWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket = assign(socket, number: "", operations: [])
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="sumForm">
      <form phx-submit="sum_submitted">
        <input type="number" name="number" value={@number} />
      </form>

      <div>
        <%= for operation <- @operations do %>
          <div>∑(1..{operation.input}) = {operation.result}</div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("sum_submitted", params, socket) do
    str_input = Map.fetch!(params, "number")

    operation =
      case Integer.parse(str_input) do
        :error -> outcome(str_input, "invalid input")
        {_number, rest} when byte_size(rest) > 0 -> outcome(str_input, "invalid input")
        {number, ""} when number < 0 -> outcome(str_input, "invalid input")
        {number, ""} -> start_sum(number)
      end

    socket = update(socket, :operations, &[operation | &1])

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:sum, pid, result}, socket),
    do: {:noreply, set_result(socket, pid, result)}

  def handle_info({:DOWN, _ref, :process, pid, _reason}, socket),
    do: {:noreply, set_result(socket, pid, :error)}

  defp start_sum(number) do
    pid = MySystem.Math.sum(number)
    %{pid: pid, input: number, result: :calculating}
  end

  defp set_result(socket, pid, result) do
    update(socket, :operations, fn operations ->
      case Enum.split_with(operations, &match?(%{pid: ^pid, result: :calculating}, &1)) do
        {[operation], rest} -> [%{operation | result: result} | rest]
        _other -> operations
      end
    end)
  end

  defp outcome(input, result),
    do: %{pid: nil, input: input, result: result}
end
