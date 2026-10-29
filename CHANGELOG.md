# Changelog

All notable changes to this package. Versions follow [Semantic Versioning](https://semver.org).

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
