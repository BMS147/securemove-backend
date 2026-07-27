async function sendOtpEmail({ to, code, purpose, name = 'SecureMove user' }) {
  const subject = purpose === 'password_reset'
    ? 'Reset your SecureMove password'
    : 'Verify your SecureMove email';
  const action = purpose === 'password_reset'
    ? 'reset your password'
    : 'verify your email address';

  const text = [
    `Hi ${name},`,
    '',
    `Use this SecureMove code to ${action}: ${code}`,
    '',
    'This code expires in 10 minutes. If you did not request it, you can ignore this message.',
  ].join('\n');

  const smtpHost = process.env.SMTP_HOST;
  const smtpUser = process.env.SMTP_USER;
  const smtpPass = process.env.SMTP_PASS;
  const smtpFrom = process.env.SMTP_FROM || smtpUser;

  if (!smtpHost || !smtpUser || !smtpPass || !smtpFrom) {
    console.warn(`[DEV OTP] ${purpose} for ${to}: ${code}`);
    return { delivered: false, devMode: true };
  }

  let nodemailer;
  try {
    nodemailer = require('nodemailer');
  } catch (error) {
    console.warn(`[DEV OTP] nodemailer unavailable. ${purpose} for ${to}: ${code}`);
    return { delivered: false, devMode: true };
  }

  const transporter = nodemailer.createTransport({
    host: smtpHost,
    port: Number(process.env.SMTP_PORT || 587),
    secure: process.env.SMTP_SECURE === 'true',
    connectionTimeout: Number(process.env.SMTP_CONNECTION_TIMEOUT_MS || 15000),
    greetingTimeout: Number(process.env.SMTP_GREETING_TIMEOUT_MS || 15000),
    socketTimeout: Number(process.env.SMTP_SOCKET_TIMEOUT_MS || 20000),
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });

  let info;
  try {
    info = await transporter.sendMail({
      from: smtpFrom,
      to,
      subject,
      text,
    });
  } catch (error) {
    console.error(
      `[OTP EMAIL ERROR] ${purpose} to ${to} via ${smtpHost}:${process.env.SMTP_PORT || 587} failed: ${error.message}`
    );
    console.warn(`[DEV OTP] ${purpose} for ${to}: ${code}`);
    return {
      delivered: false,
      devMode: true,
      error: error.message,
    };
  }

  console.log(
    `[OTP EMAIL] ${purpose} to ${to} accepted=${JSON.stringify(info.accepted || [])} rejected=${JSON.stringify(info.rejected || [])} messageId=${info.messageId || 'none'}`
  );

  return {
    delivered: true,
    devMode: false,
    accepted: info.accepted || [],
    rejected: info.rejected || [],
    messageId: info.messageId || null,
  };
}

module.exports = {
  sendOtpEmail,
};
