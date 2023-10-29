defmodule LiveviewCounterWeb.Router do
  use LiveviewCounterWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LiveviewCounterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # plug :get_forwarded_for
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LiveviewCounterWeb do
    pipe_through :browser
    live "/", Counter

    # get "/", PageController, :home
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:liveview_counter, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LiveviewCounterWeb.Telemetry
    end
  end

  # def get_forwarded_for(conn, _) do
  #   forwarded_for =
  #     conn
  #     |> Plug.Conn.get_req_header("x-forwarded-for")
  #     |> List.first()

  #   result =
  #     if forwarded_for do
  #       forwarded_for
  #       |> String.split(",")
  #       |> Enum.map(&String.trim/1)
  #       |> List.first()
  #     else
  #       conn.remote_ip
  #       |> :inet_parse.ntoa()
  #       |> to_string()
  #     end

  #   conn
  #   |> Plug.Conn.put_session(:forwarded, result)
  # end
end
