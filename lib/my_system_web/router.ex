defmodule MySystemWeb.Router do
  use MySystemWeb, :router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MySystemWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MySystemWeb do
    pipe_through :browser

    live_dashboard "/dashboard", metrics: MySystemWeb.Telemetry
  end
end
