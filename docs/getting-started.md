# Getting Started

This gem is a Ruby client for the [Saasu](https://www.saasu.com/) accounting
API. It ships two namespaces in one gem:

- **`Saasu`** — the original, stable, hash-based client. Every existing app
  keeps working unchanged. See [The Saasu namespace](saasu-legacy.md).
- **`Saasi`** — the typed successor: snake_case attributes, type coercion,
  client-side validation, typed nested objects. New code should prefer it.
  See [The Saasi namespace](saasi.md) and the [migration guide](migration.md).

Both namespaces share the same configuration, HTTP client, and authentication —
`Saasi` classes delegate all HTTP to their `Saasu` counterparts, so there is
exactly one way requests are made regardless of which API you use.

## Installation

```ruby
# Gemfile
gem 'saasu2'
```

```
$ bundle
```

Requirements: Ruby 3.x and ActiveModel >= 6.1 (installed automatically as a
dependency).

## Configuration

Create an initializer (e.g. `config/initializers/saasu.rb` in Rails):

```ruby
require 'saasu'

Saasu::Config.configure do |c|
  c.username = 'username@email.com'   # your Saasu login
  c.password = 'password'
  c.file_id  = 1234                   # https://secure.saasu.com/a/net/webservicessettings.aspx
end

# Identical — Saasi.configure is an alias for the same config:
Saasi.configure do |c|
  c.file_id = 1234
end
```

All options:

| Option | Default | Purpose |
|---|---|---|
| `username` | — | Saasu login for the OAuth password grant |
| `password` | — | |
| `file_id` | — | The Saasu file (organisation) every request targets; appended as `FileId=` to each request |
| `api_url` | `https://api.saasu.com/` | Override for testing/sandboxes |
| `scope` | `'full'` | OAuth scope string; supports context scopes, e.g. `'view fileid:1234'`. Note: Saasu currently ignores incoming scopes ("may [support them] in the future"); the granted token's scope lists the file ids your login can access |
| `two_factor_code` | `nil` | When set, authentication uses the `token-2fa` endpoint with this verification code |

Configuration is process-global: one set of credentials and one `file_id` per
process. To discover which files your login can access, call
`Saasu::FileIdentity.all` (or `Saasi::FileIdentity.all`).

## Authentication — you don't manage it

The client authenticates lazily on the first request (OAuth password grant),
caches the access token, tracks its expiry, and refreshes it transparently
with the refresh token when it lapses. There is nothing to call and no token
to store. Two useful entry points exist anyway:

```ruby
Saasu::Auth.ping   # GET authorisation/ping — cheap connectivity/credentials check
```

Authentication failures raise a `RuntimeError` asking you to check your
username and password. Two lifecycle details worth knowing: **refresh tokens
expire after 12 months**, after which the next authentication falls back to a
fresh password grant (automatic, since the gem holds your credentials), and
accounts with **two-factor authentication** need a handshake:

```ruby
Saasu::Auth.request_two_factor_code   # => true — the API SMSes a code to the account's mobile
Saasu::Config.two_factor_code = '123456'  # code the user received
Saasu::Auth.ping                      # any request now authenticates via token-2fa
```

A plain request against a 2FA-protected account raises
`Saasu::TwoFactorRequiredError` (also aliased as `Saasi::TwoFactorRequiredError`).

## First requests

```ruby
# Typed (recommended for new code)
invoice = Saasi::Invoice.find(1234)
invoice.transaction_date          # => #<Date 2026-08-06> — a real Date
invoice.line_items.first.quantity # => BigDecimal — typed nested objects

# Legacy (hash-based; still fully supported)
invoice = Saasu::Invoice.find(1234)
invoice['TransactionDate']        # => "2026-08-06T00:00:00" — raw API string
invoice.transaction_date          # same string, via the generated reader
```

## Error handling

All HTTP errors are raised from one place, whichever namespace you use:

```ruby
begin
  Saasi::Invoice.find(999_999)
rescue Saasi::NotFoundError            # 404 (Saasi::NotFoundError == Saasu::NotFoundError)
  ...
rescue Saasi::Error => e               # any other non-2xx (== Saasu::Error)
  e.status                             # => 400
  e.body                               # => parsed error body from the API
end
```

Both error classes subclass `RuntimeError`, so pre-existing
`rescue RuntimeError` code keeps working.

`Saasi` adds one client-side error: `Saasi::ValidationError`, raised by
`save`/`create` *before any HTTP* when the model is invalid. It carries
`#model` and `#errors` (a standard `ActiveModel::Errors`).

## Where to next

- [The Saasi namespace](saasi.md) — typed models, validation, nested objects
- [The Saasu namespace](saasu-legacy.md) — the hash API and its compatibility guarantees
- [Migration guide](migration.md) — moving code from `Saasu::` to `Saasi::`
- [Resource reference](resources.md) — every resource, its operations and filters
- [Model relationships](models.md) — entity-relationship diagram
