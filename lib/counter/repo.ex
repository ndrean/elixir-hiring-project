defmodule Counter.Repo do
  use Ecto.Repo,
    otp_app: :liveview_counter,
    adapter: Ecto.Adapters.SQLite3
end
