# WhatsApp webhook remediation draft

The recovered [whatsapp-bot source](../../supabase/functions/whatsapp-bot/index.ts) remains unchanged evidence of the deployed version. The helper in [whatsapp-bot-security_DRAFT.mjs](../../supabase/drafts/whatsapp-bot-security_DRAFT.mjs) is not integrated or deployable by itself.

Before any future function deployment:

1. Configure the exact externally visible HTTPS callback URL in server-side `TWILIO_WEBHOOK_URL`; do not derive it from untrusted forwarded headers.
2. Parse only Twilio’s expected URL-encoded POST body and validate `X-Twilio-Signature` with the server-side `TWILIO_AUTH_TOKEN` before any database or storage operation. Return a generic 403 on failure.
3. Replace every caller-supplied media `fetch()` with `fetchTwilioMedia()`, passing the configured account SID and a product-approved byte limit. The helper allows only the configured Twilio account’s HTTPS Media endpoint, rejects redirects, and accepts only JPEG/PNG/WebP content.
4. Confirm Twilio’s actual callback URL, media URL format, content types, maximum upload size, and response behavior in a non-production environment. If Twilio media delivery requires redirects, implement a separately validated redirect flow that never forwards Twilio credentials to another host.
5. Add an end-to-end function test proving that invalid signatures, forged sender values, disallowed URLs, redirects, unsupported types, and oversized payloads cause no database/storage writes or credential-bearing external requests.

The isolated Node tests cover the helper’s signature, origin, redirect, content-type, and size checks. They do not prove the integration points above. Do not deploy from this branch.
