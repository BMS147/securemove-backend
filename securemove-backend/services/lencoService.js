const crypto = require('crypto');

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

function getLencoConfig() {
  // LENCO_BASE_URL is the API host only, e.g. https://api.lenco.co
  // Versioned paths (/access/v1, /access/v2) are appended by each function.
  const apiHost = (process.env.LENCO_BASE_URL || 'https://api.lenco.co').replace(/\/$/, '');
  const secretKey = process.env.LENCO_SECRET_KEY || '';

  // Strip any trailing path segments the user may have included (e.g. /sandbox, /access/v2)
  const host = apiHost.replace(/\/(sandbox|access\/v\d+).*$/, '');

  return {
    enabled: Boolean(secretKey),
    secretKey,
    publicKey: process.env.LENCO_PUBLIC_KEY || '',
    // Endpoint roots derived from host
    v2Url: `${host}/access/v2`,
    v1Url: `${host}/access/v1`,
    country: (process.env.LENCO_COUNTRY || 'zm').toLowerCase(),
    bearer: (process.env.LENCO_BEARER || 'merchant').toLowerCase(),
  };
}

// ---------------------------------------------------------------------------
// Collection — initiate
// ---------------------------------------------------------------------------

/**
 * Initiate a mobile money collection via Lenco.
 *
 * Returns { collectionId, ourReference, status, raw }
 *   collectionId — Lenco's UUID for this collection; store as transaction_reference.
 */
async function initiateCollection({ amount, reference, phone, operator }) {
  const config = getLencoConfig();
  ensureConfigured(config);

  const url = `${config.v2Url}/collections/mobile-money`;

  const normalizedPhone = normalizeMsisdn(phone);
  const normalizedOperator = operator.toLowerCase();

  const requestBody = {
    amount,
    reference,
    phone: normalizedPhone,
    operator: normalizedOperator,
    country: config.country,
    bearer: config.bearer,
  };

  console.log('[Lenco] initiateCollection →', JSON.stringify({
    url,
    body: requestBody,
  }, null, 2));

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.secretKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(requestBody),
  });

  const data = await readJson(response);

  console.log('[Lenco] initiateCollection ←', JSON.stringify({
    status: response.status,
    ok: response.ok,
    body: data,
  }, null, 2));

  // Lenco always returns HTTP 200 for collection requests (even failures).
  // The JSON body's `status` boolean is the real success indicator.
  if (!response.ok || data.status === false) {
    const message = data.message || data.error || `Lenco returned HTTP ${response.status}`;
    const errorCode = data.errorCode ? ` (errorCode ${data.errorCode})` : '';
    throw new Error(`Lenco collection request failed: ${message}${errorCode}`);
  }

  const payload = data.data;
  if (!payload || !payload.id) {
    throw new Error(`Lenco collection request returned no data: ${JSON.stringify(data)}`);
  }

  return {
    collectionId: payload.id,
    ourReference: payload.reference || reference,
    status: normalizeLencoStatus(payload.status),
    reason: payload.reasonForFailure || null,
    raw: data,
  };
}

// ---------------------------------------------------------------------------
// Collection — poll status (webhook fallback)
// ---------------------------------------------------------------------------

/**
 * Check the status of a Lenco collection by OUR reference string.
 * Endpoint: GET /access/v2/collections/status/:reference
 * Called by the polling endpoint when the webhook has not fired yet.
 */
async function getCollectionStatus(ourReference) {
  const config = getLencoConfig();
  ensureConfigured(config);

  const url = `${config.v2Url}/collections/status/${encodeURIComponent(ourReference)}`;

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${config.secretKey}`,
    },
  });

  const data = await readJson(response);

  if (!response.ok || data.status === false) {
    const message = data.message || data.error || `Lenco returned HTTP ${response.status}`;
    throw new Error(`Lenco status check failed: ${message}`);
  }

  const collection = data.data || {};

  console.log('[Lenco] getCollectionStatus ←', JSON.stringify({
    ourReference,
    lencoStatus: collection.status,
    reasonForFailure: collection.reasonForFailure ?? null,
    operator: collection.mobileMoneyDetails?.operator ?? null,
    phone: collection.mobileMoneyDetails?.phone ?? null,
  }, null, 2));

  return {
    ourReference,
    status: normalizeLencoStatus(collection.status),
    reason: collection.reasonForFailure || null,
    financialTransactionId: collection.transactionReference || collection.nipSessionId || null,
    raw: data,
  };
}

// ---------------------------------------------------------------------------
// Webhook signature verification
// ---------------------------------------------------------------------------

/**
 * Verify the X-Lenco-Signature header on incoming webhook requests.
 *
 * Lenco's documented algorithm:
 *   webhookHashKey = SHA-256(LENCO_SECRET_KEY)            [hex string]
 *   signature      = HMAC-SHA-512(webhookHashKey, JSON.stringify(body))  [hex string]
 *
 * The body to sign is the parsed-then-re-stringified JSON (not raw bytes).
 * Uses constant-time comparison to prevent timing attacks.
 *
 * @param {Buffer|string} rawBody  - Raw request body (Buffer from express.raw)
 * @param {string}        receivedSignature - Value of X-Lenco-Signature header
 */
function verifyWebhookSignature(rawBody, receivedSignature) {
  const secretKey = process.env.LENCO_SECRET_KEY || '';
  if (!secretKey || !receivedSignature) return false;

  try {
    // Parse then re-stringify so we sign the canonical JSON Lenco uses
    const bodyString = JSON.stringify(JSON.parse(rawBody.toString('utf8')));

    const webhookHashKey = crypto
      .createHash('sha256')
      .update(secretKey)
      .digest('hex');

    const expected = crypto
      .createHmac('sha512', webhookHashKey)
      .update(bodyString)
      .digest('hex');

    const expectedBuf = Buffer.from(expected, 'hex');
    const receivedBuf = Buffer.from(String(receivedSignature), 'hex');

    if (expectedBuf.length !== receivedBuf.length) return false;
    return crypto.timingSafeEqual(expectedBuf, receivedBuf);
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Lenco expects local-format Zambian numbers (0XXXXXXXXX, 10 digits).
 * All Lenco API examples and sandbox test accounts use local format.
 * E.164 inputs (260XXXXXXXXX / +260XXXXXXXXX) are converted back to local format.
 */
function normalizeMsisdn(phone) {
  const digits = String(phone).replace(/\D/g, '');
  if (digits.startsWith('260') && digits.length === 12) return '0' + digits.slice(3); // E.164 → local
  if (digits.startsWith('0'))  return digits;                                          // already local
  if (digits.length === 9)     return '0' + digits;                                   // bare 9-digit → local
  return digits;
}

function normalizeLencoStatus(status) {
  switch (String(status || '').toLowerCase()) {
    case 'successful':
    case 'success':
    case 'completed':
      return 'successful';
    case 'failed':
    case 'failure':
    case 'declined':
      return 'failed';
    case 'pending':
    case 'pay-offline':
    default:
      return 'pending';
  }
}

function ensureConfigured(config) {
  if (!config.enabled) {
    throw new Error(
      'Lenco is not configured. Ensure LENCO_SECRET_KEY and LENCO_BASE_URL are set in .env, ' +
      'and MOBILE_MONEY_MODE=lenco.'
    );
  }
}

async function readJson(response) {
  const text = await response.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    return { message: text };
  }
}

module.exports = {
  getLencoConfig,
  initiateCollection,
  getCollectionStatus,
  verifyWebhookSignature,
};
