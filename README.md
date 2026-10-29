# Quolle Ruby SDK

Official Ruby client for the [Quolle](https://quolle.com) email API.

## Install

```bash
gem install quolle
```

Or in your Gemfile:

```ruby
gem "quolle"
```

Requires Ruby 3.3+. No third-party dependencies.

## Quick start

```ruby
require "quolle"

quolle = Quolle.new(api_key: "qle_...") # or set QUOLLE_API_KEY

result = quolle.emails.send(
  from: "hello@mail.yourdomain.com",
  to: "customer@example.com",
  subject: "Welcome!",
  html: "<h1>Thanks for signing up</h1>"
)

puts "Queued: #{result['id']}"
```

`emails.create(...)` does exactly the same thing and doesn't shadow Ruby's
`Object#send`, so prefer it if you use `send` for dynamic dispatch. Pass
`type: "marketing"` for marketing mail (adds unsubscribe headers); the default
is transactional.

## Sending

### Multiple recipients

```ruby
quolle.emails.send(
  from: "hello@mail.yourdomain.com",
  to: ["a@example.com", "b@example.com"],
  subject: "Announcement",
  html: "<p>Hello everyone</p>"
)
```

### Templates

```ruby
quolle.emails.send(
  from: "hello@mail.yourdomain.com",
  to: "customer@example.com",
  template: "welcome-email",
  variables: { firstName: "Amaka", planName: "Starter" }
)
```

### Scheduled send

```ruby
quolle.emails.send(
  from: "hello@mail.yourdomain.com",
  to: "customer@example.com",
  subject: "Your weekly digest",
  html: "<p>Here's what happened this week.</p>",
  scheduled_at: "2026-12-25T09:00:00.000Z"
)
```

### Idempotency

```ruby
quolle.emails.send(
  from: "billing@mail.yourdomain.com",
  to: "customer@example.com",
  subject: "Invoice #1234",
  html: "<p>Your invoice is attached.</p>",
  idempotency_key: "order_invoice_12345"
)
```

### Batch

Up to 100 emails in one all-or-nothing request:

```ruby
result = quolle.emails.send_batch([
  { from: "hello@mail.yourdomain.com", to: "a@example.com", subject: "Hi Alice", html: "<p>Hi Alice</p>" },
  { from: "hello@mail.yourdomain.com", to: "b@example.com", subject: "Hi Bob", html: "<p>Hi Bob</p>" }
])
puts "Queued #{result['queued']}"
```

### Attachments

Pass `attachments:` — an array of hashes with `filename`, base64 `content`, and an
optional `contentType`. Up to 20 files, 10 MB total.

```ruby
require "base64"

quolle.emails.send(
  from: "billing@mail.yourdomain.com",
  to: "customer@example.com",
  subject: "Your invoice",
  html: "<p>Invoice attached.</p>",
  attachments: [
    {
      filename: "invoice.pdf",
      content: Base64.strict_encode64(File.binread("invoice.pdf")),
      contentType: "application/pdf"
    }
  ]
)
```

## Retrieve & cancel

```ruby
email = quolle.emails.get("a1b2c3d4-...")
puts email["status"] # queued | sending | sent | delivered | bounced | failed

quolle.emails.cancel("a1b2c3d4-...") # only while status == "scheduled"
```

## Error handling

```ruby
begin
  quolle.emails.send(
    from: "hello@mail.yourdomain.com", to: "customer@example.com",
    subject: "Welcome!", html: "<h1>Welcome</h1>"
  )
rescue Quolle::Error => e
  puts e.status_code # e.g. 402
  puts e.code        # e.g. "monthly_quota_exceeded" — branch on this
  puts e.message     # e.g. "Monthly limit reached"
  puts e.data        # extra fields, e.g. {"limit" => 3000}
end
```

## Testing your integration

Send to a reserved test address to simulate any outcome without touching your
sending reputation: `delivered@test.quolle.com`, `bounced@test.quolle.com`,
`complained@test.quolle.com`, `suppressed@test.quolle.com`.

## Verifying webhooks

Confirm an incoming webhook really came from Quolle. Pass the **raw** request body, the `Quolle-Signature` header, and your signing secret (`whsec_…`):

```ruby
begin
  event = quolle.webhooks.verify(
    request.body.read,                  # raw body
    request.env["HTTP_QUOLLE_SIGNATURE"],
    "whsec_your_signing_secret"
  )
  # event["event"] == "email.delivered"
rescue Quolle::Error
  halt 400
end
```

HMAC-SHA256 with a 5-minute timestamp window (replay protection).

## Domains, API keys and webhooks

These need a **full-access** API key. A sending-only key gets `403` with code `restricted_api_key`, so a key you ship in an app can't create keys or change your domains.

```ruby
# Domains
created = quolle.domains.create("mail.example.com")    # created["dnsRecords"] to publish
quolle.domains.verify(created["domain"]["id"])          # check DNS now
quolle.domains.list.each { |d| puts "#{d["domain"]} #{d["status"]}" }

# API keys
new_key = quolle.api_keys.create(name: "web app", scope: "sending", domains: ["mail.example.com"])
puts new_key["key"]                                      # shown once
quolle.api_keys.remove(new_key["id"])

# Webhook endpoints
hook = quolle.webhooks.create(url: "https://example.com/hooks/quolle", events: %w[email.delivered email.bounced])
# hook["secret"] (whsec_…) is shown once; store it for quolle.webhooks.verify(...)
quolle.webhooks.test(hook["id"])
quolle.webhooks.deliveries(hook["id"], status: "failed").each { |d| quolle.webhooks.redeliver(hook["id"], d["id"]) }
new_secret = quolle.webhooks.rotate_secret(hook["id"])["secret"]
```

## Automatic retries

Transient failures — HTTP 429 (rate limit) and 5xx, plus network errors — are retried automatically with exponential backoff, honoring the `Retry-After` header. To avoid double-sending, a POST is only retried on a 5xx/network error when you pass an idempotency key; a 429 is always safe to retry (the request was never processed). Quota limits are the exception: `daily_quota_exceeded` and `warmup_limit_exceeded` (and any `Retry-After` over 60 seconds) are raised immediately, because they reset at a fixed time, not in seconds; check `e.code` and queue the send for later. Tune with `max_retries:` on `Quolle.new` (default 3).

## License

MIT
