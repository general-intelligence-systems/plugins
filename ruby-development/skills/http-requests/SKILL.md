---
name: http-requests
description: Make HTTP requests in Ruby using the http.rb gem (the "http" gem) with its chainable API and pattern matching on responses. Use this skill whenever the user writes Ruby code that calls a REST/HTTP API, fetches a URL, posts JSON or form data, streams a download, or mentions http.rb, HTTP.get, Net::HTTP alternatives, persistent connections, or handling HTTP responses with case/in — even for a one-line request. Also use it when reviewing or refactoring existing Ruby HTTP client code. Prefer http.rb over Net::HTTP for new code unless the user says otherwise.
---

# HTTP Requests in Ruby with http.rb

http.rb (`gem "http"`) is the preferred Ruby HTTP client: a chainable API over a native
llhttp parser — not a Net::HTTP wrapper. This guide targets **v6.x**, which requires
**Ruby 3.2+**. Pattern matching and `base_uri` are v6 features; on older gem versions
(5.x) fall back to explicit `response.status.success?` checks.

```ruby
# Gemfile
gem "http"

require "http"
```

## Requests in 30 Seconds

```ruby
response = HTTP.get("https://api.example.com/users")

response.to_s          # body as String (reads it fully)
response.parse         # auto-parses by Content-Type (JSON => Hash/Array)
response.status        # HTTP::Response::Status — 200, comparable, .success?
response.headers       # HTTP::Headers
response.content_type  # HTTP::ContentType — .mime_type, .charset
```

All verbs are class methods: `HTTP.get`, `.post`, `.put`, `.patch`, `.delete`, `.head`, `.options`.

Request bodies and query strings go through keyword options:

```ruby
HTTP.get("https://example.com/search", params: { q: "ruby", page: 2 })
HTTP.post("https://example.com/users", json: { name: "Ada" })          # JSON body + header
HTTP.post("https://example.com/login", form: { user: "ada", pass: "x" })
HTTP.post("https://example.com/upload",
          form: { avatar: HTTP::FormData::File.new("/path/pic.png") })  # multipart
HTTP.post("https://example.com/raw", body: "raw bytes")
```

## Chainable Configuration

Every chainable method returns a session, so options compose left to right:

```ruby
HTTP.headers(accept: "application/json")
    .auth("Bearer #{token}")            # raw Authorization header value
    .timeout(10)                        # seconds, global per request
    .follow                             # follow redirects (off by default!)
    .get("https://api.example.com/me")
```

Common chainables:

| Method | Purpose |
|---|---|
| `.headers(hash)` | Set request headers |
| `.auth("Bearer x")` | Set `Authorization` header verbatim |
| `.basic_auth(user:, pass:)` | HTTP Basic auth |
| `.timeout(5)` or `.timeout(connect: 2, write: 2, read: 5)` | Global or per-operation timeouts |
| `.follow` / `.follow(max_hops: 3)` | Follow redirects — **not** followed unless you ask |
| `.via(host, port)` | HTTP proxy |
| `.cookies(key: "value")` | Send cookies |
| `.accept(:json)` | Shorthand for the Accept header |
| `.encoding("utf-8")` | Force response body encoding |
| `.base_uri(url)` | Prefix for relative request paths (see below) |
| `.persistent(url)` | Keep-alive connection (see below) |

Store a configured session in a constant or method and reuse it — don't rebuild the
chain at every call site:

```ruby
API = HTTP.headers(accept: "application/json").timeout(10).follow
API.get("https://api.example.com/users")
```

## Pattern Matching on Responses

`HTTP::Response` implements `deconstruct_keys`, so `case/in` is the idiomatic way to
branch on a response. Available keys: `status`, `version`, `headers`, `body`,
`request`, `proxy_headers`.

```ruby
case HTTP.get("https://api.example.com/users")
in { status: 200..299, body: }
  JSON.parse(body.to_s)
in { status: 404 }
  nil
in { status: 429, headers: { retry_after: } }
  raise RateLimited, "retry after #{retry_after}s"
in { status: 400.. }
  raise "request failed"
end
```

Notes on how the matching works:

- `status:` holds an `HTTP::Response::Status`, which is `Comparable` against
  integers — so `200`, `200..299`, and `500..` all match directly.
- `HTTP::Response::Status` itself deconstructs to `{ code:, reason: }`, so nested
  patterns work: `in { status: { code: 418, reason: } }`.
- `HTTP::Headers` deconstructs header names to lowercased, underscored symbols
  (`Content-Type` → `content_type:`, `Retry-After` → `retry_after:`); values are the
  header strings, so regexes work: `in { headers: { content_type: /json/ } }`.
- `HTTP::ContentType` deconstructs to `{ mime_type:, charset: }`.
- `HTTP::URI` deconstructs to `{ scheme:, host:, port:, path:, query:, fragment:, user:, password: }` —
  useful for matching `response.uri` after redirects.
- Array form: `response.deconstruct` yields `[status_code, headers_hash, body_string]`,
  so `in [200, _, body]` also works — but note it reads the body eagerly; prefer the
  hash form.

Pattern matching does not replace exception handling: connection failures and timeouts
raise before you have a response (see Error Handling).

## Base URI

Avoid repeating scheme + host; relative paths resolve per RFC 3986:

```ruby
api = HTTP.base_uri("https://api.example.com/v1")
api.get("users")     # GET https://api.example.com/v1/users
api.get("users/1")   # GET https://api.example.com/v1/users/1
```

## Persistent Connections

`HTTP.persistent` keeps the TCP/TLS connection open across requests to the same origin:

```ruby
HTTP.persistent("https://api.example.com") do |http|
  users = http.get("/v1/users").parse
  posts = http.get("/v1/posts").parse
end   # connection closed when the block exits
```

Two rules that bite people:

1. **Fully read every response body** before issuing the next request on a persistent
   connection — call `.to_s`, `.parse`, or `.flush` (flush discards). An unread body
   leaves the connection in a broken state.
2. The block form closes the connection for you. Without a block you must call
   `http.close` yourself.

Combine with `base_uri`, and redirects across origins are handled transparently (a
separate persistent connection per origin):

```ruby
HTTP.base_uri("https://api.example.com/v1").persistent { |http| http.get("users") }
```

## Thread Safety

- **Configured sessions are thread-safe.** A chain like
  `HTTP.headers(...).timeout(10).auth(...)` returns an `HTTP::Session` that creates a
  fresh client per request — share it freely across threads.
- **Persistent sessions are NOT thread-safe.** `HTTP.persistent(...)` pools one client
  per origin. For threads, wrap it in the `connection_pool` gem:

```ruby
pool = ConnectionPool.new(size: 5) { HTTP.persistent("https://api.example.com") }
pool.with { |http| http.get("/v1/users").to_s }
```

## Streaming Responses

Don't call `.to_s` on large downloads — stream with `readpartial`:

```ruby
response = HTTP.get("https://example.com/big-file.iso")
File.open("big-file.iso", "wb") do |file|
  while (chunk = response.body.readpartial)
    file.write(chunk)
  end
end
```

`readpartial` returns `nil` at end of body. A body can only be streamed once.

## Error Handling

Transport failures raise; HTTP error *statuses* do not — check them yourself (pattern
matching above, or predicates):

```ruby
begin
  response = HTTP.timeout(5).get(url)
  case response
  in { status: 200..299 } then response.parse
  in { status: }          then raise "HTTP #{status}"
  end
rescue HTTP::TimeoutError    # request exceeded .timeout
  retry_or_give_up
rescue HTTP::ConnectionError # DNS failure, refused, TLS errors
  handle_unreachable
rescue HTTP::Error           # base class for all http.rb errors
  handle_generic
end
```

Status predicates when you don't need full pattern matching:
`status.success?` (2xx), `status.client_error?` (4xx), `status.server_error?` (5xx),
plus per-code helpers like `status.not_found?`, `status.unauthorized?`.

## Rules of Thumb

- Always set a `.timeout` on anything production-facing; the default is no timeout.
- Redirects are **not** followed by default — add `.follow` for browser-like behavior.
- Use `json:` / `form:` / `params:` options rather than hand-building bodies and
  query strings.
- Use `case/in` pattern matching to branch on status; reserve `rescue` for transport
  errors.
- Reuse a configured session; use `persistent` (with `connection_pool` under threads)
  when hammering one host.
