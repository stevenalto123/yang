import { createHmac, randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';
import type { UserRole } from './types.js';

export interface JwtClaims {
  sub: string;
  email: string;
  fullName: string;
  role: UserRole;
  householdId: string;
  iat: number;
  exp: number;
}

const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function hashPassword(password: string): string {
  const salt = randomBytes(16).toString('hex');
  const derived = scryptSync(password, salt, 64).toString('hex');
  return `${salt}:${derived}`;
}

export function verifyPassword(password: string, storedHash: string): boolean {
  const parts = storedHash.split(':');
  if (parts.length !== 2) return false;
  const [salt, expectedHex] = parts;
  if (!salt || !expectedHex) return false;

  const actualBuf = scryptSync(password, salt, 64);
  const expectedBuf = Buffer.from(expectedHex, 'hex');
  if (actualBuf.length !== expectedBuf.length) return false;
  return timingSafeEqual(actualBuf, expectedBuf);
}

export function generateInviteCode(length = 6): string {
  const bytes = randomBytes(length);
  let code = '';
  for (let i = 0; i < length; i++) {
    code += INVITE_ALPHABET[bytes[i] % INVITE_ALPHABET.length];
  }
  return code;
}

function base64UrlEncode(input: Buffer | string): string {
  return Buffer.from(input)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function base64UrlDecode(input: string): Buffer {
  const normalized = input.replace(/-/g, '+').replace(/_/g, '/');
  const padLen = (4 - (normalized.length % 4)) % 4;
  return Buffer.from(normalized + '='.repeat(padLen), 'base64');
}

export function signJwt(
  claims: Omit<JwtClaims, 'iat' | 'exp'>,
  secret: string,
  ttlSeconds = 60 * 60 * 24 * 30,
): string {
  const now = Math.floor(Date.now() / 1000);
  const fullPayload: JwtClaims = {
    ...claims,
    iat: now,
    exp: now + ttlSeconds,
  };

  const headerPart = base64UrlEncode(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payloadPart = base64UrlEncode(JSON.stringify(fullPayload));
  const signingInput = `${headerPart}.${payloadPart}`;
  const signature = createHmac('sha256', secret).update(signingInput).digest();
  return `${signingInput}.${base64UrlEncode(signature)}`;
}

export function verifyJwt(token: string, secret: string): JwtClaims | null {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [headerPart, payloadPart, sigPart] = parts;
  if (!headerPart || !payloadPart || !sigPart) return null;

  const signingInput = `${headerPart}.${payloadPart}`;
  try {
    const header = JSON.parse(base64UrlDecode(headerPart).toString('utf8')) as {
      alg?: string;
    };
    if (header.alg !== 'HS256') return null;
  } catch {
    return null;
  }

  const expectedSig = createHmac('sha256', secret).update(signingInput).digest();
  let providedSig: Buffer;
  try {
    providedSig = base64UrlDecode(sigPart);
  } catch {
    return null;
  }

  if (expectedSig.length !== providedSig.length || !timingSafeEqual(expectedSig, providedSig)) {
    return null;
  }

  try {
    const parsed = JSON.parse(base64UrlDecode(payloadPart).toString('utf8')) as JwtClaims;
    const now = Math.floor(Date.now() / 1000);
    if (!parsed.exp || parsed.exp < now || !parsed.sub || !parsed.householdId) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}
