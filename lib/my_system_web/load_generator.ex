defmodule MySystemWeb.LoadGenerator do
  @moduledoc false
  use Phoenix.LiveDashboard.PageBuilder

  @impl Phoenix.LiveDashboard.PageBuilder
  def menu_link(_session, _capabilities) do
    {:ok, "Load generator"}
  end

  @impl Phoenix.LiveDashboard.PageBuilder
  def render(assigns) do
    ~H"""
    """
  end
end
