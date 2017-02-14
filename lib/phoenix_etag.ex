defmodule PhoenixEtag do
  def schema_etag(nil), do: nil
  def schema_etag([]), do: []
  def schema_etag(schema_or_schemas) do
    list = Enum.map(List.wrap(models), fn model ->
      [model.__struct__, model.id, model.updated_at]
    end)

    binary = :erlang.term_to_binary(list)
    :crypto.hash(:md5, binary)
    |> Base.encode16(case: :lower)
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

  def render_if_stale(conn, template assins)
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

  def render_if_stale(conn, view, template assigns)
      when is_atom(view) and (is_binary(template) or is_atom(template)) do
    conn
    |> Phoenix.Controller.put_view(view)
    |> render_if_stale(template, assigns)
  end

  defp do_render_if_stale(conn, template, format, assigns) do
    view = Phoenix.Controller.view_name(conn)
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

    update_in conn.assigns, &prepare_assigns(&1, assigns, layout, view)
  end

  defp prepare_assigns(old, new, layout, view) do
    old
    |> Map.merge(new)
    |> Map.put(:layout, layout)
    |> Map.put(:view, view)
  end

  defp layout(conn, assigns, format) do
    if format in layout_formats(conn) do
      Map.get(assigns, :layout, Phoenix.Controller.layout(conn))
    else
      false
    end
  end

  defp if_stale(conn, view, template, format, fun) do
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
    modifed = modifed |> NaiveDateTime.to_erl |> :cowboy_clock.rfc1123
    put_resp_header(conn, "last-modified", modifed)
  end

  defp stale?(conn, etag, modified) do
    modified_since = List.first get_req_header(conn, "if-modified-since")
    none_match     = List.first get_req_header(conn, "if-none-match")

    if modified_since || none_match do
      modified_since?(modified_since, modified) or none_match?(none_match, etag)
    else
      true
    end
  end

  defp modified_since?(header, last_modified) do
    if header && last_modified do
      modified_since = :cowboy_http.rfc1123_date(header)
      modified_since = :calendar.datetime_to_gregorian_seconds(modified_since)
      last_modified  = :calendar.datetime_to_gregorian_seconds(last_modified)
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
end
