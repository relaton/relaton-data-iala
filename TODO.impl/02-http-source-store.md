# 02 — IalaFetcher::Http, Source, YamlStore seams

**Priority:** P0 (gated by 01; every fetcher depends on these).

## Why

Three seams make the fetcher testable and keep I/O in one place. Port
them from OIML verbatim except for the module name.

## Scope

### `lib/iala_fetcher/http.rb`

Mirror `OimlFetcher::Http`. Provide:

- `IalaFetcher::Http::Error`, `TooManyRedirects`, `BadStatus`, `Timeout`
- `IalaFetcher::Http::NetHttp` (default) — follows up to 5 redirects,
  raises on 4xx/5xx, honours `read_timeout` / `open_timeout` kwargs.
- `IalaFetcher::Http::Fake` — fixture-table adapter for specs.
- `IalaFetcher::Http.backend = NetHttp.new` (default assignment).

### `lib/iala_fetcher/source.rb`

Mirror `OimlFetcher::Source`. Provide class methods:

- `.url(url)`     → `{ "type" => "website", "content" => url }`
- `.iala(path)`   → resolves relative paths against `IalaFetcher::BASE_URL`
- `.local(path)`  → `{ "type" => "file", "content" => path }`

### `lib/iala_fetcher/yaml_store.rb`

Mirror `OimlFetcher::YamlStore`. Owns all `File.write` for `data/`:

- `#write(name, hash, overwrite: true)` — round-trips through
  `Relaton::Bib::Item.from_hash` → `#to_yaml`, UTF-8 encoded.
- `#write_raw(name, yaml, overwrite: true)` — bypass for hand-formatted YAML.
- `#read(name)` — `YAML.safe_load` with `Date`, `Time` permitted.
- `#patch(name)` — read-modify-write with `YAML.dump`.
- `#exist?(name)`, `#each_yaml`, `#path_for(name)`.

### Acceptance

- [ ] `spec/iala_fetcher/http_spec.rb` — NetHttp follows a 302, raises on 404, raises on timeout (use webmock, not doubles).
- [ ] `spec/iala_fetcher/source_spec.rb` — `.url`, `.iala("relative")`, `.iala("https://…")`, `.local` return correct shapes.
- [ ] `spec/iala_fetcher/yaml_store_spec.rb` — `write` produces a UTF-8 file that round-trips; `patch` mutates safely; `exist?` and `each_yaml` enumerate correctly.
- [ ] No `require_relative`, no `send` to private, no `instance_variable_set/get`.
- [ ] Real `Relaton::Bib::Item` instances in specs — never `double()`.

### Out of scope

- Fetcher logic that *uses* these seams (next tasks).
