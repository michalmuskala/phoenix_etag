defmodule PhoenixETag do
  def schema_etag(nil), do: nil
  def schema_etag([]), do: []
  def schema_etag(schema_or_schemas) do
    list = Enum.map(List.wrap(schema_or_schemas), fn schema ->
      [schema.__struct__, schema.id, schema.updated_at]
    end)

    binary = :erlang.term_to_binary(list)
    "W/ " <> Base.encode16(:crypto.hash(:md5, binary), case: :lower)
  end

  def render_if_stale(conn, template_or_assigns \\ [])

  def render_if_stale(conn, template) when is_binary(template) or is_atom(template) do
    render_if_stale(conn, template, %{})
  end

  def render_if_stale(conn, assigns) when is_map(assigns) or is_list(assigns) do
    action = Phoenix.Controller.action_name(conn)
    render_if_stale(conn, action, assigns)
  end

  def render_if_stale(conn, template, assigns)
      when is_atom(template) and (is_list(assigns) or is_map(assigns)) do
    format =
      Phoenix.Controller.get_format(conn) ||
      raise "cannot render template #{inspect template} because conn.params[\"_format\"] is not set. " <>
            "Please set `plug :accepts, ~w(html json ...)` in your pipeline."
    template = template_name(template, format)
    do_render_if_stale(conn, template, format, assigns)
  end

  def render_if_stale(conn, template, assigns)
      when is_binary(template) and (is_list(assigns) or is_map(assigns)) do
    case Path.extname(template) do
      "." <> format ->
        do_render_if_stale(conn, template, format, assigns)
      "" ->
        raise "cannot render template #{inspect template} without format. Use an atom if the " <>
              "template format is meant to be set dynamically based on the request format"
    end
  end

  def render_if_stale(conn, view, template)
      when is_atom(view) and (is_binary(template) or is_atom(template)) do
    render_if_stale(conn, view, template, %{})
  end

  def render_if_stale(conn, view, template, assigns)
      when is_atom(view) and (is_binary(template) or is_atom(template)) do
    conn
    |> Phoenix.Controller.put_view(view)
    |> render_if_stale(template, assigns)
  end

  defp do_render_if_stale(conn, template, format, assigns) do
    view = Phoenix.Controller.view_module(conn)
    conn
    |> prepare_assigns(assigns, format)
    |> if_stale(view, template, &Phoenix.Controller.render(&1, template, %{}))
  end

  defp template_name(name, format) when is_atom(name),
    do: Atom.to_string(name) <> "." <> format
  defp template_name(name, _format) when is_binary(name),
    do: name

  defp prepare_assigns(conn, assigns, format) do
    layout =
      case layout(conn, assigns, format) do
        {mod, layout} -> {mod, template_name(layout, format)}
        false -> false
      end

    update_in conn.assigns, &do_prepare_assigns(&1, assigns, layout)
  end

  defp do_prepare_assigns(old, new, layout) do
    old
    |> Map.merge(new)
    |> Map.put(:layout, layout)
  end

  defp layout(conn, assigns, format) do
    if format in Phoenix.Controller.layout_formats(conn) do
      Map.get(assigns, :layout, Phoenix.Controller.layout(conn))
    else
      false
    end
  end

  defp if_stale(conn, view, template, fun) do
    checks = view.stale_checks(template, conn.assigns)
    etag = checks[:etag]
    modified = checks[:last_modified]

    conn =
      conn
      |> put_etag(etag)
      |> put_last_modified(modified)

    if stale?(conn, etag, modified) do
      fun.(conn)
    else
      Plug.Conn.send_resp(conn, 304, "")
    end
  end

  defp put_etag(conn, nil),
    do: conn
  defp put_etag(conn, etag),
    do: Plug.Conn.put_resp_header(conn, "etag", etag)

  defp put_last_modified(conn, nil),
    do: conn
  defp put_last_modified(conn, modified) do
    Plug.Conn.put_resp_header(conn, "last-modified", format_date(modified))
  end

  defp stale?(conn, etag, modified) do
    modified_since = List.first Plug.Conn.get_req_header(conn, "if-modified-since")
    none_match     = List.first Plug.Conn.get_req_header(conn, "if-none-match")

    if get_or_head?(conn) and (modified_since || none_match) do
      modified_since?(modified_since, modified) or none_match?(none_match, etag)
    else
      true
    end
  end

  defp get_or_head?(%{method: method}), do: method in ["GET", "HEAD"]

  defp modified_since?(header, last_modified) do
    if header && last_modified do
      modified_since = :httpd_util.convert_request_date(header)
      last_modified = DateTime.to_unix(last_modified)
      last_modified > modified_since
    else
      false
    end
  end

  defp none_match?(none_match, etag) do
    if none_match && etag do
      none_match = Plug.Conn.Utils.list(none_match)
      not(etag in none_match) and not("*" in none_match)
    else
      false
    end
  end

  defp format_date(datetime) do
    datetime
    |> NaiveDateTime.to_erl
    |> :httpd_util.rfc1123_date
    |> List.to_string
  end

  defp parse_date(string) do
    case :httpd_util.convert_request_date(String.to_charlist(string)) do
      :bad_date ->
        0 # in case of bad date we consider content stale
      date ->
        date
        |> NaiveDateTime.from_erl!
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.to_unix
    end
  end

end
