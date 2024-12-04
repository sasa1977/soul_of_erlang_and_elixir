defmodule MySystemWeb.LoadControl do
  @moduledoc false
  use Phoenix.LiveDashboard.PageBuilder
  import MySystemWeb.CoreComponents

  @impl Phoenix.LiveDashboard.PageBuilder
  def mount(_params, _session, socket) do
    socket = assign(socket, scheduler_utilizations: [], success_values: [])
    if connected?(socket), do: MySystem.LoadControl.subscribe()
    {:ok, form_data(socket)}
  end

  @impl Phoenix.LiveDashboard.PageBuilder
  def menu_link(_session, _capabilities) do
    {:ok, "Load control"}
  end

  @impl Phoenix.LiveDashboard.PageBuilder
  def render(assigns) do
    ~H"""
    <.form for={@form} phx-submit="submit_form">
      <.input field={@form[:jobs]} type="number" min="0" label="jobs" />
      <.input field={@form[:schedulers_online]} type="number" min="1" label="schedulers" />
      <button style="display:none;">Save</button>
    </.form>

    <.jobs_successes_chart points={@success_values} num_points={MySystem.LoadControl.num_points()} />

    <.scheduler_utilization_chart
      points={@scheduler_utilizations}
      num_points={MySystem.LoadControl.num_points()}
    />
    """
  end

  @impl Phoenix.LiveDashboard.PageBuilder
  def handle_event("submit_form", params, socket) do
    with {:ok, string} <- Map.fetch(params, "schedulers_online"),
         {value, ""} <- Integer.parse(string),
         do: MySystem.LoadControl.set_num_schedulers(value)

    with {:ok, string} <- Map.fetch(params, "jobs"),
         {value, ""} <- Integer.parse(string),
         do: MySystem.LoadControl.set_load(value)

    {:noreply, form_data(socket)}
  end

  @impl Phoenix.LiveDashboard.PageBuilder
  def handle_info({:scheduler_utilizations, utilizations}, socket) do
    socket
    |> assign(:scheduler_utilizations, utilizations)
    |> then(&{:noreply, &1})
  end

  def handle_info({MySystem.LoadControl, :success_values, values}, socket),
    do: {:noreply, assign(socket, :success_values, values)}

  defp form_data(socket) do
    form =
      to_form(%{
        "schedulers_online" => MySystem.LoadControl.num_schedulers(),
        "jobs" => MySystem.LoadControl.target_load()
      })

    assign(socket, form: form)
  end

  defp scheduler_utilization_chart(assigns) do
    assigns =
      Map.merge(assigns, %{
        width: assigns.num_points,
        height: 500,
        title: "scheduler usage",
        legends: Enum.map([0, 25, 50, 75, 100], &%{title: "#{&1}%", at: &1 / 100})
      })

    ~H"""
    <.graph {assigns} />
    """
  end

  defp jobs_successes_chart(assigns) do
    max_rate = Enum.max(assigns.points, &>=/2, fn -> 0 end)

    order_of_magnitude =
      if max_rate < 10, do: 1, else: round(:math.pow(10, floor(:math.log10(max_rate)) - 1))

    quantized_max_rate = max(round(max_rate / order_of_magnitude) * order_of_magnitude, 1)
    step = max(quantize(quantized_max_rate / 5, order_of_magnitude), 1)

    points = Enum.map(assigns.points, &(&1 / max(max_rate, 1)))

    legends =
      0
      |> Stream.iterate(&(&1 + step))
      |> Stream.take_while(&(&1 <= max_rate))
      |> Enum.map(&%{title: human_readable_int(&1), at: &1 / max(max_rate, 1)})

    assigns =
      Map.merge(assigns, %{
        width: assigns.num_points,
        height: 500,
        title: "successful jobs/second",
        legends: legends,
        points: points
      })

    ~H"""
    <.graph {assigns} />
    """
  end

  defp quantize(num, quant), do: round(num / quant) * quant

  defp human_readable_int(num) when num > 0 and rem(num, 1000) == 0, do: "#{div(num, 1000)}k"
  defp human_readable_int(num), do: num

  defp graph(assigns) do
    ~H"""
    <span>
      <svg viewBox={"0 0 #{@width + 150} #{@height + 150}"} height={@height} class="chart">
        <style>
          .title { font-size: 30px;}
        </style>

        <g transform="translate(100, 100)">
          <g stroke="black">
            <text
              class="title"
              text-anchor="middle"
              dominant-baseline="central"
              x="300"
              y="-50"
              fill="black"
            >
              {@title}
            </text>
          </g>

          <%= for legend <- @legends do %>
            <g stroke="black">
              <text
                text-anchor="end"
                dominant-baseline="central"
                x="-20"
                y={"#{y(legend.at, @height)}"}
                fill="black"
              >
                {legend.title}
              </text>
            </g>

            <g stroke-width="1" stroke="gray" stroke-dasharray="4">
              <line
                x1="0"
                x2={@width}
                y1={"#{y(legend.at, @height)}"}
                y2={"#{y(legend.at, @height)}"}
              />
            </g>
          <% end %>

          <g stroke-width="2" stroke="black">
            <line x1="0" x2="0" y1="0" y2={@height} />
            <line x1="0" x2={@width} y1={@height} y2={@height} />
          </g>

          <polyline fill="none" stroke="#0074d9" stroke-width="2" points={points(assigns)} />
        </g>
      </svg>
    </span>
    """
  end

  defp points(assigns) do
    assigns.points
    |> moving_averages(10)
    |> Enum.with_index(1)
    |> Enum.map(fn {value, pos} ->
      x = assigns.width - pos
      "#{x},#{y(value, assigns.height)}"
    end)
    |> Enum.join(" ")
  end

  defp moving_averages(values, size) do
    values
    |> Enum.chunk_every(size, 1, :discard)
    |> Enum.map(fn list -> Enum.sum(list) / size end)
  end

  defp y(value, height), do: height - min(round(value * height), height)
end
