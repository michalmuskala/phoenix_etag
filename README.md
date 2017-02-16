# PhoenixETag

Conditional request (ETag & modified-since) support for Phoenix.

Based heavily on code from [hex_web](https://github.com/hexpm/hex_web).

## Usage

The library provides a replacement function for `Phoenix.Controller.render/1-4`
called `PhoenixETag.render_if_stale/1-4` accepting exactly the same arguments.
When called the function expects the view to implement an additional callback:
`stale_checks/2` similar to `render/2` that is responsible for returning the
etag value and/or last modified value for the current resource.

Additional helper `PhoenixETag.schema_etag/1` is provided for generating etag
values of of a single or multiple schema structs.

```elixir
# controller

def show(conn, %{"id" => id}) do
  data = MyApp.load_data(id)
  PhoenixETag.render_if_stale(conn, :show, data: data)
end

# view

def stale_checks("show." <> format, %{data: data}) do
  [etag: PhoenixETag.schema_etag(data) <> "-" <> format, 
   last_modified: data.updated_at]
end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `phoenix_etag` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:phoenix_etag, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/phoenix_etag](https://hexdocs.pm/phoenix_etag).

