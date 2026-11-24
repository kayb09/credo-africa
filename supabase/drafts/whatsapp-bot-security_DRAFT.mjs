const TWILIO_ACCOUNT_SID = /^AC[0-9a-f]{32}$/i;
const TWILIO_MESSAGE_SID = /^(?:SM|MM)[0-9a-f]{32}$/i;
const TWILIO_MEDIA_SID = /^ME[0-9a-f]{32}$/i;
const ALLOWED_MEDIA_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

function compareText(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

function isCanonicalHttpsUrl(value) {
  try {
    const url = new URL(value);
    return (
      url.protocol === "https:" &&
      url.username === "" &&
      url.password === "" &&
      url.hash === "" &&
      url.href === value
    );
  } catch {
    return false;
  }
}

function constantTimeEqual(left, right) {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  let difference = leftBytes.length ^ rightBytes.length;
  const length = Math.max(leftBytes.length, rightBytes.length);

  for (let index = 0; index < length; index += 1) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }

  return difference === 0;
}

export async function verifyTwilioSignature(signature, authToken, webhookUrl, params) {
  if (
    typeof signature !== "string" ||
    signature.length === 0 ||
    typeof authToken !== "string" ||
    authToken.length === 0 ||
    !isCanonicalHttpsUrl(webhookUrl) ||
    !params ||
    typeof params.entries !== "function"
  ) {
    return false;
  }

  const entries = [];
  for (const [key, value] of params.entries()) {
    if (typeof key !== "string" || typeof value !== "string") {
      return false;
    }
    entries.push([key, value]);
  }

  entries.sort(([leftKey, leftValue], [rightKey, rightValue]) =>
    compareText(leftKey, rightKey) || compareText(leftValue, rightValue)
  );
  const payload = webhookUrl + entries.map(([key, value]) => key + value).join("");
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(authToken),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"]
  );
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload));
  const expected = btoa(String.fromCharCode(...new Uint8Array(digest)));

  return constantTimeEqual(signature, expected);
}

export async function authenticateTwilioWebhook(request, { authToken, webhookUrl }) {
  if (request.method !== "POST") {
    return null;
  }

  const contentType = request.headers.get("content-type")?.toLowerCase() ?? "";
  if (!/^application\/x-www-form-urlencoded(?:;|$)/.test(contentType)) {
    return null;
  }

  let params;
  try {
    params = await request.formData();
  } catch {
    return null;
  }
  const valid = await verifyTwilioSignature(
    request.headers.get("x-twilio-signature") ?? "",
    authToken,
    webhookUrl,
    params
  );

  return valid ? params : null;
}

export function validateTwilioMediaUrl(rawUrl, accountSid) {
  if (typeof accountSid !== "string" || !TWILIO_ACCOUNT_SID.test(accountSid)) {
    throw new TypeError("Invalid Twilio account SID");
  }

  let url;
  try {
    url = new URL(rawUrl);
  } catch {
    throw new TypeError("Invalid Twilio media URL");
  }

  if (
    url.protocol !== "https:" ||
    url.hostname !== "api.twilio.com" ||
    (url.port !== "" && url.port !== "443") ||
    url.username !== "" ||
    url.password !== "" ||
    url.search !== "" ||
    url.hash !== ""
  ) {
    throw new TypeError("Twilio media URL must use the approved HTTPS origin");
  }

  const match = url.pathname.match(
    /^\/2010-04-01\/Accounts\/(AC[0-9a-f]{32})\/Messages\/((?:SM|MM)[0-9a-f]{32})\/Media\/(ME[0-9a-f]{32})(?:\.json)?$/i
  );
  if (
    !match ||
    match[1].toLowerCase() !== accountSid.toLowerCase() ||
    !TWILIO_MESSAGE_SID.test(match[2]) ||
    !TWILIO_MEDIA_SID.test(match[3])
  ) {
    throw new TypeError("Twilio media URL does not identify this account's message media");
  }

  return url.href;
}

export async function fetchTwilioMedia(
  rawUrl,
  { accountSid, authToken, maxBytes, fetchImpl = fetch }
) {
  if (
    typeof authToken !== "string" ||
    authToken.length === 0 ||
    !Number.isSafeInteger(maxBytes) ||
    maxBytes <= 0
  ) {
    throw new TypeError("Twilio media credentials and a positive byte limit are required");
  }

  const url = validateTwilioMediaUrl(rawUrl, accountSid);
  const response = await fetchImpl(url, {
    headers: {
      Authorization: `Basic ${btoa(`${accountSid}:${authToken}`)}`,
    },
    redirect: "error",
  });

  if (!response.ok || response.redirected || (response.status >= 300 && response.status < 400)) {
    throw new Error("Twilio media request failed or attempted a redirect");
  }

  const contentType = response.headers.get("content-type")?.split(";", 1)[0].trim().toLowerCase();
  if (!contentType || !ALLOWED_MEDIA_TYPES.has(contentType)) {
    throw new TypeError("Unsupported Twilio media content type");
  }

  const contentLength = response.headers.get("content-length");
  if (contentLength && /^\d+$/.test(contentLength) && Number(contentLength) > maxBytes) {
    throw new RangeError("Twilio media exceeds the configured byte limit");
  }

  if (!response.body) {
    throw new TypeError("Twilio media response has no body");
  }

  const reader = response.body.getReader();
  const chunks = [];
  let totalBytes = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) {
      break;
    }

    totalBytes += value.byteLength;
    if (totalBytes > maxBytes) {
      await reader.cancel();
      throw new RangeError("Twilio media exceeds the configured byte limit");
    }
    chunks.push(value);
  }

  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  return new Blob([bytes], { type: contentType });
}
