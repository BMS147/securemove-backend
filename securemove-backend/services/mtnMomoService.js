const crypto = require('crypto');

const DEFAULT_BASE_URL = 'https://sandbox.momodeveloper.mtn.com';

function getMtnConfig() {
  return {
    enabled:
      process.env.MTN_MOMO_COLLECTION_SUBSCRIPTION_KEY &&
      process.env.MTN_MOMO_API_USER &&
      process.env.MTN_MOMO_API_KEY,
    baseUrl: (process.env.MTN_MOMO_BASE_URL || DEFAULT_BASE_URL).replace(/\/$/, ''),
    subscriptionKey: process.env.MTN_MOMO_COLLECTION_SUBSCRIPTION_KEY,
    apiUser: process.env.MTN_MOMO_API_USER,
    apiKey: process.env.MTN_MOMO_API_KEY,
    targetEnvironment: process.env.MTN_MOMO_TARGET_ENV || 'sandbox',
    callbackUrl: process.env.MTN_MOMO_CALLBACK_URL || '',
    currency: (process.env.MTN_MOMO_CURRENCY || 'ZMW').toUpperCase(),
  };
}

async function createAccessToken() {
  const config = getMtnConfig();
  ensureConfigured(config);

  const basicAuth = Buffer.from(`${config.apiUser}:${config.apiKey}`).toString('base64');
  const response = await fetch(`${config.baseUrl}/collection/token/`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${basicAuth}`,
      'Ocp-Apim-Subscription-Key': config.subscriptionKey,
    },
  });

  const data = await readJson(response);
  if (!response.ok) {
    throw new Error(data.error_description || data.message || 'Unable to create MTN access token');
  }

  if (!data.access_token) {
    throw new Error('MTN token response did not include an access token');
  }

  return data.access_token;
}

async function requestToPay({ amount, phoneNumber, externalId, payerMessage, payeeNote }) {
  const config = getMtnConfig();
  ensureConfigured(config);

  const accessToken = await createAccessToken();
  const referenceId = crypto.randomUUID();
  const headers = {
    Authorization: `Bearer ${accessToken}`,
    'Ocp-Apim-Subscription-Key': config.subscriptionKey,
    'X-Reference-Id': referenceId,
    'X-Target-Environment': config.targetEnvironment,
    'Content-Type': 'application/json',
  };

  if (config.callbackUrl) {
    headers['X-Callback-Url'] = config.callbackUrl;
  }

  const response = await fetch(`${config.baseUrl}/collection/v1_0/requesttopay`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      amount: amount.toFixed(2),
      currency: config.currency,
      externalId: String(externalId),
      payer: {
        partyIdType: 'MSISDN',
        partyId: normalizeMsisdn(phoneNumber),
      },
      payerMessage,
      payeeNote,
    }),
  });

  if (response.status !== 202) {
    const data = await readJson(response);
    throw new Error(data.message || data.error || 'MTN RequestToPay was not accepted');
  }

  return {
    referenceId,
    provider: 'mtn',
    status: 'PENDING',
  };
}

async function getRequestToPayStatus(referenceId) {
  const config = getMtnConfig();
  ensureConfigured(config);

  const accessToken = await createAccessToken();
  const response = await fetch(`${config.baseUrl}/collection/v1_0/requesttopay/${referenceId}`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Ocp-Apim-Subscription-Key': config.subscriptionKey,
      'X-Target-Environment': config.targetEnvironment,
    },
  });

  const data = await readJson(response);
  if (!response.ok) {
    throw new Error(data.message || data.error || 'Unable to fetch MTN payment status');
  }

  return {
    referenceId,
    status: normalizeMtnStatus(data.status),
    reason: data.reason || null,
    financialTransactionId: data.financialTransactionId || null,
    externalId: data.externalId || null,
    raw: data,
  };
}

function normalizeMsisdn(phoneNumber) {
  const digits = String(phoneNumber).replace(/\D/g, '');
  if (digits.startsWith('260')) {
    return digits;
  }
  if (digits.startsWith('0')) {
    return `26${digits}`;
  }
  if (digits.startsWith('7') || digits.startsWith('9')) {
    return `260${digits}`;
  }
  return digits;
}

function normalizeMtnStatus(status) {
  switch (String(status || '').toUpperCase()) {
    case 'SUCCESSFUL':
      return 'successful';
    case 'FAILED':
      return 'failed';
    case 'PENDING':
    default:
      return 'pending';
  }
}

function ensureConfigured(config) {
  if (!config.enabled) {
    throw new Error(
      'MTN MoMo is not configured. Set MTN_MOMO_COLLECTION_SUBSCRIPTION_KEY, MTN_MOMO_API_USER, and MTN_MOMO_API_KEY in .env.',
    );
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
  getMtnConfig,
  requestToPay,
  getRequestToPayStatus,
};
