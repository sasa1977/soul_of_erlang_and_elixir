defmodule MySystemWeb.LoadControl do
  @moduledoc false
  use Phoenix.LiveDashboard.PageBuilder
  import MySystemWeb.CoreComponents

  @impl Phoenix.LiveDashboard.PageBuilder
  def mount(_params, _session, socket) do
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
      <.input field={@form[:schedulers_online]} type="number" min="1" label="schedulers" />
      <.input field={@form[:jobs]} type="number" min="0" label="jobs" />
      <button style="display:none;">Save</button>
    </.form>
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

  defp form_data(socket) do
    form =
      to_form(%{
        "schedulers_online" => MySystem.LoadControl.num_schedulers(),
        "jobs" => MySystem.LoadControl.target_load()
      })

    assign(socket, form: form)
  end
end
