const crypto = require('crypto');

const UAT_BASE_URL = 'https://openapiuat.airtel.africa';
const PRODUCTION_BASE_URL = 'https://openapi.airtel.africa';

function getAirtelConfig() {
  const environmentMode = (process.env.AIRTEL_ENVIRONMENT_MODE || 'staging').trim().toLowerCase();
  return {
    enabled: Boolean(process.env.AIRTEL_CLIENT_ID && process.env.AIRTEL_CLIENT_SECRET),
    baseUrl: (process.env.AIRTEL_BASE_URL || getDefaultBaseUrl(environmentMode)).replace(/\/$/, ''),
    clientId: process.env.AIRTEL_CLIENT_ID,
    clientSecret: process.env.AIRTEL_CLIENT_SECRET,
    country: (process.env.AIRTEL_COUNTRY || process.env.AIRTEL_X_COUNTRY || 'ZM').toUpperCase(),
    currency: (process.env.AIRTEL_CURRENCY || process.env.AIRTEL_X_CURRENCY || 'ZMW').toUpperCase(),
  };
}

async function createAccessToken() {
  const config = getAirtelConfig();
  ensureConfigured(config);

  const response = await fetch(`${config.baseUrl}/auth/oauth2/token`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      client_id: config.clientId,
      client_secret: config.clientSecret,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      client_id: config.clientId,
      client_secret: config.clientSecret,
      grant_type: 'client_credentials',
    }),
  });

  const data = await readJson(response);
  if (!response.ok) {
    throw new Error(getAirtelMessage(data) || 'Unable to create Airtel access token');
  }

  const accessToken = data.access_token || data.accessToken;
  if (!accessToken) {
    throw new Error('Airtel token response did not include an access token');
  }

  return accessToken;
}

async function requestPayment({ amount, phoneNumber, externalId, reference }) {
  const config = getAirtelConfig();
  ensureConfigured(config);

  const accessToken = await createAccessToken();
  const transactionId = String(reference || buildTransactionId(externalId));
  const response = await fetch(`${config.baseUrl}/merchant/v1/payments/`, {
    method: 'POST',
    headers: {
      Accept: '*/*',
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'X-Country': config.country,
      'X-Currency': config.currency,
    },
    body: JSON.stringify({
      reference: `SecureMove booking ${externalId}`,
      subscriber: {
        country: config.country,
        currency: config.currency,
        msisdn: normalizeMsisdn(phoneNumber),
      },
      transaction: {
        amount: amount.toFixed(2),
        country: config.country,
        currency: config.currency,
        id: transactionId,
      },
    }),
  });

  const data = await readJson(response);
  if (!response.ok) {
    throw new Error(getAirtelMessage(data) || 'Airtel payment request was not accepted');
  }

  return {
    referenceId: transactionId,
    provider: 'airtel',
    status: normalizeAirtelStatus(data),
    raw: data,
  };
}

async function getPaymentStatus(transactionId) {
  const config = getAirtelConfig();
  ensureConfigured(config);

  const accessToken = await createAccessToken();
  const response = await fetch(`${config.baseUrl}/standard/v1/payments/${encodeURIComponent(transactionId)}`, {
    method: 'GET',
    headers: {
      Accept: '*/*',
      Authorization: `Bearer ${accessToken}`,
      'X-Country': config.country,
      'X-Currency': config.currency,
    },
  });

  const data = await readJson(response);
  if (!response.ok) {
    throw new Error(getAirtelMessage(data) || 'Unable to fetch Airtel payment status');
  }

  return {
    referenceId: transactionId,
    status: normalizeAirtelStatus(data),
    reason: data.message || data.status?.message || null,
    financialTransactionId:
      data.data?.transaction?.airtel_money_id ||
      data.data?.transaction?.reference_id ||
      data.transaction?.airtel_money_id ||
      null,
    externalId: data.data?.transaction?.id || data.transaction?.id || null,
    raw: data,
  };
}

function normalizeMsisdn(phoneNumber) {
  const digits = String(phoneNumber).replace(/\D/g, '');
  if (digits.startsWith('260')) {
    return digits.slice(3);
  }
  if (digits.startsWith('0')) {
    return digits.slice(1);
  }
  return digits;
}

function buildTransactionId(externalId) {
  const prefix = externalId ? `SM-${externalId}` : 'SM';
  return `${prefix}-${Date.now()}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`;
}

function getDefaultBaseUrl(environmentMode) {
  return environmentMode === 'production' ? PRODUCTION_BASE_URL : UAT_BASE_URL;
}

function normalizeAirtelStatus(data) {
  const status =
    data?.data?.transaction?.status ||
    data?.transaction?.status ||
    data?.status?.code ||
    data?.status ||
    '';

  switch (String(status).toUpperCase()) {
    case 'TS':
    case 'SUCCESS':
    case 'SUCCESSFUL':
    case 'COMPLETED':
      return 'successful';
    case 'TF':
    case 'FAILED':
    case 'FAILURE':
    case 'DECLINED':
      return 'failed';
    case 'TP':
    case 'TIP':
    case 'PENDING':
    case 'IN_PROGRESS':
    default:
      return 'pending';
  }
}

function getAirtelMessage(data) {
  return (
    data?.message ||
    data?.error_description ||
    data?.error ||
    data?.status?.message ||
    data?.status?.result_message ||
    data?.data?.message
  );
}

function ensureConfigured(config) {
  if (!config.enabled) {
    throw new Error('Airtel Money is not configured. Set AIRTEL_CLIENT_ID and AIRTEL_CLIENT_SECRET in .env.');
  }
}

async function readJson(response) {
  const text = await response.text();
  if (!text) {
    return {};
  }

  try {
    return JSON.parse(text);
  } catch (_) {
    return { message: text };
  }
}

module.exports = {
  getAirtelConfig,
  requestPayment,
  getPaymentStatus,
};
