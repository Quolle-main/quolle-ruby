# Changelog

All notable changes to this package. Versions follow [Semantic Versioning](https://semver.org).

## 1.2.0 — 2026-10-29

### Added
- `quolle.domains`: `list`, `create`, `get`, `records`, `verify`, `remove`. Add a sending domain, get its DNS records, check DNS on demand, and see verification and warm-up state.
- `quolle.api_keys`: `list`, `create`, `remove`. Create keys (full access or sending-only, optionally limited to some domains, optionally expiring) and revoke them.
- `quolle.webhooks` manages endpoints as well as verifying deliveries: `list`, `create`, `get`, `update`, `remove`, `test`, `deliveries`, `redeliver`, `rotate_secret`, `events`.

These need a full-access API key; a sending-only key gets `restricted_api_key`. Requires Quolle API support for API-key access to `/v1/keys` and `/v1/webhooks` (live from 29 Oct 2026).

## 1.1.0 — 2026-10-29

### Added
- `Quolle::Error#code`: the API's machine-readable error code.
- `emails.create` (same as `emails.send`, which shadows `Object#send`).
- `type:` / `message_type:` for marketing mail.

### Changed
- Quota limits are no longer retried. `daily_quota_exceeded` and `warmup_limit_exceeded` (and any 429 whose `Retry-After` is over 60 seconds) are raised at once with their code, instead of the client waiting, possibly for hours, before failing. Ordinary rate limits are still retried.
- **Requires Ruby 3.3+** (was 2.7). Older Rubies are past end of life; Bundler keeps them on 1.0.x.
- A 2xx response that isn't JSON now raises instead of returning `{}`.

### Fixed
- Ids are path-encoded (form encoding turned spaces into `+`).

## 1.0.0

First release, with attachments.
