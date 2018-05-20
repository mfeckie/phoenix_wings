defmodule ChannelServerWeb.PageController do
  use ChannelServerWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
