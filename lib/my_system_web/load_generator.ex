defmodule MySystemWeb.LoadGenerator do
  @moduledoc false
  use Phoenix.LiveDashboard.PageBuilder
  import MySystemWeb.CoreComponents

  @impl Phoenix.LiveDashboard.PageBuilder
  def mount(_params, _session, socket) do
    {:ok, schedulers_online_form(socket)}
  end

  @impl Phoenix.LiveDashboard.PageBuilder
  def menu_link(_session, _capabilities) do
    {:ok, "Load generator"}
  end

  @impl Phoenix.LiveDashboard.PageBuilder
  def render(assigns) do
    ~H"""
    <.form for={@schedulers_online} phx-change="schedulers_online" phx-submit="schedulers_online">
      <.input field={@schedulers_online[:schedulers_online]} type="number" min="1" label="schedulers" />
    </.form>
    """
  end

  @impl Phoenix.LiveDashboard.PageBuilder
  def handle_event("schedulers_online", params, socket) do
    with {:ok, string} <- Map.fetch(params, "schedulers_online"),
         {value, ""} <- Integer.parse(string) do
      :erlang.system_flag(:schedulers_online, value)
      :erlang.system_flag(:dirty_cpu_schedulers_online, value)
    end

    {:noreply, schedulers_online_form(socket)}
  end

  defp schedulers_online_form(socket) do
    form = to_form(%{"schedulers_online" => :erlang.system_info(:schedulers_online)})
    assign(socket, schedulers_online: form)
  end
end
