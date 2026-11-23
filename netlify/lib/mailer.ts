import tls from 'node:tls';
import { getEnv } from './env.js';

export interface ResetEmailPayload {
  to: string;
  fullName: string;
  code: string;
}

export function isEmailResetConfigured(): boolean {
  const user = getEnv('GMAIL_USER');
  const pass = getEnv('GMAIL_APP_PASSWORD');
  return Boolean(user && pass);
}

/**
 * Sends a 6-digit password reset code via Gmail SMTP over implicit TLS (port 465)
 * using Node's built-in `node:tls` (zero external npm dependencies).
 */
export async function sendPasswordResetEmail(
  payload: ResetEmailPayload,
): Promise<void> {
  const user = (getEnv('GMAIL_USER') ?? '').trim();
  const rawPass = getEnv('GMAIL_APP_PASSWORD') ?? '';
  // Google displays App Passwords in 4-char groups with spaces; strip whitespace safely
  const pass = rawPass.replace(/\s+/g, '');
  const host = (getEnv('SMTP_HOST') ?? 'smtp.gmail.com').trim();
  const port = Number(getEnv('SMTP_PORT') ?? 465) || 465;

  if (!user || !pass) {
    throw new Error('GMAIL_USER and GMAIL_APP_PASSWORD are not configured.');
  }

  const safeName = payload.fullName.replace(/[<>"]/g, '').trim() || 'Resident';
  const subject = `LifeCheckpoint Password Reset Code: ${payload.code}`;
  const htmlBody = `<!DOCTYPE html>
<html>
  <body style="font-family: Arial, Helvetica, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; color: #0f172a;">
    <div style="max-width: 480px; margin: 0 auto; background: #ffffff; border-radius: 14px; border: 1px solid #e2e8f0; overflow: hidden;">
      <div style="background: #0f1e34; color: #ffffff; padding: 20px 24px;">
        <h2 style="margin: 0; font-size: 18px;">LifeCheckpoint</h2>
        <p style="margin: 4px 0 0; font-size: 12px; color: #cbd5e1;">City of Manila Emergency Monitoring &amp; Family Preparedness</p>
      </div>
      <div style="padding: 24px;">
        <p style="margin: 0 0 12px; font-size: 14px;">Hello <strong>${escapeHtml(safeName)}</strong>,</p>
        <p style="margin: 0 0 16px; font-size: 14px; line-height: 1.5;">
          We received a request to reset your LifeCheckpoint password. Enter this 6-digit verification code in the app:
        </p>
        <div style="background: #f1f5f9; border: 1px solid #cbd5e1; border-radius: 10px; padding: 16px; text-align: center; margin: 0 0 18px;">
          <span style="font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #0f1e34;">${escapeHtml(payload.code)}</span>
        </div>
        <p style="margin: 0 0 10px; font-size: 13px; color: #475569;">
          This code expires in <strong>15 minutes</strong> and can only be used once.
        </p>
        <p style="margin: 0; font-size: 12px; color: #64748b;">
          If you did not request a password reset, you can safely ignore this email — your password will remain unchanged.
        </p>
      </div>
    </div>
  </body>
</html>`;

  const base64Body = Buffer.from(htmlBody, 'utf8')
    .toString('base64')
    .replace(/.{1,76}/g, '$&\r\n');

  const rawMessage = [
    `From: LifeCheckpoint <${user}>`,
    `To: <${payload.to}>`,
    `Subject: ${subject}`,
    `Date: ${new Date().toUTCString()}`,
    'MIME-Version: 1.0',
    'Content-Type: text/html; charset="UTF-8"',
    'Content-Transfer-Encoding: base64',
    '',
    base64Body,
  ].join('\r\n');

  await sendViaSmtps({
    host,
    port,
    user,
    pass,
    to: payload.to,
    rawMessage,
  });
}

function escapeHtml(input: string): string {
  return input
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function sendViaSmtps(opts: {
  host: string;
  port: number;
  user: string;
  pass: string;
  to: string;
  rawMessage: string;
}): Promise<void> {
  return new Promise((resolve, reject) => {
    let settled = false;
    let buffer = '';
    let waitingResolve: ((line: string) => void) | null = null;
    let waitingReject: ((err: Error) => void) | null = null;

    const socket = tls.connect({
      host: opts.host,
      port: opts.port,
      servername: opts.host,
      rejectUnauthorized: true,
    });

    const timeout = setTimeout(() => {
      fail(new Error('SMTP connection timed out.'));
    }, 12000);

    function cleanup() {
      clearTimeout(timeout);
      socket.destroy();
    }

    function fail(err: Error) {
      if (settled) return;
      settled = true;
      cleanup();
      if (waitingReject) {
        const r = waitingReject;
        waitingResolve = null;
        waitingReject = null;
        r(err);
      }
      reject(err);
    }

    function tryDeliverResponse() {
      if (!waitingResolve) return;
      const lines = buffer.split('\r\n');
      let completeIdx = -1;
      for (let i = 0; i < lines.length - 1; i++) {
        if (/^\d{3} /.test(lines[i])) {
          completeIdx = i;
          break;
        }
      }
      if (completeIdx === -1) return;

      const responseText = lines.slice(0, completeIdx + 1).join('\n');
      buffer = lines.slice(completeIdx + 1).join('\r\n');
      const r = waitingResolve;
      waitingResolve = null;
      waitingReject = null;
      r(responseText);
    }

    socket.setEncoding('utf8');
    socket.on('data', (chunk: string) => {
      buffer += chunk;
      tryDeliverResponse();
    });
    socket.on('error', (err) => fail(err));
    socket.on('close', () => {
      if (!settled) {
        fail(new Error('SMTP connection closed unexpectedly.'));
      }
    });

    function readResponse(expectedPrefix: string): Promise<string> {
      return new Promise((res, rej) => {
        waitingResolve = (text) => {
          const lastLine = text.split('\n').pop() ?? '';
          if (!lastLine.startsWith(expectedPrefix)) {
            rej(new Error(`SMTP error (expected ${expectedPrefix}): ${lastLine}`));
            return;
          }
          res(text);
        };
        waitingReject = rej;
        tryDeliverResponse();
      });
    }

    async function sendCmd(cmd: string, expectedPrefix: string): Promise<void> {
      socket.write(`${cmd}\r\n`);
      await readResponse(expectedPrefix);
    }

    socket.once('secureConnect', async () => {
      try {
        await readResponse('220');
        await sendCmd('EHLO lifecheckpoint.vercel.app', '250');
        await sendCmd('AUTH LOGIN', '334');
        await sendCmd(Buffer.from(opts.user, 'utf8').toString('base64'), '334');
        await sendCmd(Buffer.from(opts.pass, 'utf8').toString('base64'), '235');
        await sendCmd(`MAIL FROM:<${opts.user}>`, '250');
        await sendCmd(`RCPT TO:<${opts.to}>`, '250');
        await sendCmd('DATA', '354');
        socket.write(`${opts.rawMessage}\r\n.\r\n`);
        await readResponse('250');
        try {
          socket.write('QUIT\r\n');
        } catch {
          // Ignore quit error after message already accepted
        }
        if (!settled) {
          settled = true;
          cleanup();
          resolve();
        }
      } catch (err) {
        fail(err instanceof Error ? err : new Error(String(err)));
      }
    });
  });
}
