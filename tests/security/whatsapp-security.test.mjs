import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import test from "node:test";
import {
  authenticateTwilioWebhook,
  fetchTwilioMedia,
  validateTwilioMediaUrl,
  verifyTwilioSignature,
} from "../../supabase/drafts/whatsapp-bot-security_DRAFT.mjs";

const webhookUrl = "https://example.supabase.co/functions/v1/whatsapp-bot";
const accountSid = `AC${"a".repeat(32)}`;
const token = "local-test-token";
const mediaUrl =
  `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages/SM${"b".repeat(32)}/Media/ME${"c".repeat(32)}`;

function compareText(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

function signatureFor(params) {
  const entries = [...params.entries()].sort(([leftKey, leftValue], [rightKey, rightValue]) =>
    compareText(leftKey, rightKey) || compareText(leftValue, rightValue)
  );
  const payload = webhookUrl + entries.map(([key, value]) => key + value).join("");
  return createHmac("sha1", token).update(payload).digest("base64");
}

test("accepts a correctly signed Twilio form request", async () => {
  const params = new URLSearchParams([
    ["From", "whatsapp:+10000000001"],
    ["Body", "sales 10"],
  ]);
  assert.equal(
    await verifyTwilioSignature(signatureFor(params), token, webhookUrl, params),
    true
  );
});

test("rejects tampered form fields, missing signatures, and non-HTTPS callback URLs", async () => {
  const signedParams = new URLSearchParams([["Body", "sales 10"]]);
  const changedParams = new URLSearchParams([["Body", "sales 1000"]]);
  const signature = signatureFor(signedParams);

  assert.equal(await verifyTwilioSignature(signature, token, webhookUrl, changedParams), false);
  assert.equal(await verifyTwilioSignature("", token, webhookUrl, signedParams), false);
  assert.equal(await verifyTwilioSignature(signature, token, "http://example.test/hook", signedParams), false);
});

test("authenticates before returning parsed webhook parameters", async () => {
  const params = new URLSearchParams([["Body", "help"]]);
  const valid = new Request(webhookUrl, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      "x-twilio-signature": signatureFor(params),
    },
    body: params,
  });
  const invalid = new Request(webhookUrl, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: params,
  });

  assert.equal((await authenticateTwilioWebhook(valid, { authToken: token, webhookUrl })).get("Body"), "help");
  assert.equal(await authenticateTwilioWebhook(invalid, { authToken: token, webhookUrl }), null);
});

test("accepts only canonical HTTPS Twilio media URLs for the configured account", () => {
  assert.equal(validateTwilioMediaUrl(mediaUrl, accountSid), mediaUrl);
  assert.throws(() => validateTwilioMediaUrl("http://api.twilio.com/path", accountSid), /approved HTTPS origin/);
  assert.throws(() => validateTwilioMediaUrl(mediaUrl.replace("api.twilio.com", "attacker.test"), accountSid));
  assert.throws(() =>
    validateTwilioMediaUrl(mediaUrl, `AC${"d".repeat(32)}`)
  );
  assert.throws(() => validateTwilioMediaUrl(`${mediaUrl}?next=https://attacker.test`, accountSid));
});

test("fetches media only with redirects disabled and returns bounded image content", async () => {
  let requestedUrl;
  let requestedOptions;
  const blob = await fetchTwilioMedia(mediaUrl, {
    accountSid,
    authToken: token,
    maxBytes: 16,
    fetchImpl: async (url, options) => {
      requestedUrl = url;
      requestedOptions = options;
      return new Response(new Uint8Array([1, 2, 3]), {
        headers: { "content-type": "image/jpeg" },
      });
    },
  });

  assert.equal(requestedUrl, mediaUrl);
  assert.equal(requestedOptions.redirect, "error");
  assert.equal(requestedOptions.headers.Authorization, `Basic ${btoa(`${accountSid}:${token}`)}`);
  assert.equal(blob.type, "image/jpeg");
  assert.equal(blob.size, 3);
});

test("rejects media redirects, unsupported types, and oversized payloads", async () => {
  const base = { accountSid, authToken: token, maxBytes: 2 };
  await assert.rejects(
    fetchTwilioMedia(mediaUrl, {
      ...base,
      fetchImpl: async (_url, options) => {
        assert.equal(options.redirect, "error");
        return new Response(null, { status: 302, headers: { location: "https://attacker.test" } });
      },
    }),
    /redirect/
  );
  await assert.rejects(
    fetchTwilioMedia(mediaUrl, {
      ...base,
      fetchImpl: async () => new Response("x", { headers: { "content-type": "text/html" } }),
    }),
    /content type/
  );
  await assert.rejects(
    fetchTwilioMedia(mediaUrl, {
      ...base,
      fetchImpl: async () => new Response(new Uint8Array([1, 2, 3]), { headers: { "content-type": "image/png" } }),
    }),
    /byte limit/
  );
});
