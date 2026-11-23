import { timingSafeEqual } from 'node:crypto';
import {
  generateInviteCode,
  generateNumericOtp,
  hashPassword,
  signJwt,
  verifyJwt,
  verifyPassword,
  type JwtClaims,
} from './crypto.js';
import { getEnv, getRequiredEnv } from './env.js';
import {
  isEmailResetConfigured,
  sendPasswordResetEmail,
  type ResetEmailPayload,
} from './mailer.js';
import type { DataStore } from './repository.js';
import type {
  AdvisorySeverity,
  EvacuationCenterRecord,
  HouseholdProfileData,
  IsoEvaluationRecord,
  KitItemRecord,
  UserRole,
} from './types.js';

const TELEMETRY_TTL_MS = 10 * 60 * 1000;

function json(data: unknown, status = 200): Response {
  return Response.json(data, {
    status,
    headers: { 'cache-control': 'no-store' },
  });
}

function normalizeApiPath(rawUrl: string): string {
  const url = new URL(rawUrl, 'http://localhost');
  const rewritten = url.searchParams.get('__route');
  if (rewritten !== null && rewritten.trim() !== '') {
    const clean = rewritten.trim();
    return clean.startsWith('/') ? clean : `/${clean}`;
  }
  const { pathname } = url;
  if (pathname.startsWith('/.netlify/functions/api')) {
    return pathname.slice('/.netlify/functions/api'.length) || '/';
  }
  if (pathname.startsWith('/api')) {
    return pathname.slice('/api'.length) || '/';
  }
  return pathname;
}

async function parseJsonBody(req: Request): Promise<Record<string, unknown>> {
  try {
    const body = await req.json();
    return body && typeof body === 'object' ? (body as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

function getBearerClaims(req: Request): JwtClaims | null {
  const header = req.headers.get('authorization');
  if (!header || !header.toLowerCase().startsWith('bearer ')) return null;
  const token = header.slice(7).trim();
  if (!token) return null;
  try {
    return verifyJwt(token, getRequiredEnv('JWT_SECRET'));
  } catch {
    return null;
  }
}

function hasValidAdminCode(provided: string | null | undefined): boolean {
  const configured = getEnv('ADMIN_INVITE_CODE');
  if (!configured || !provided) return false;
  const a = Buffer.from(configured.trim());
  const b = Buffer.from(provided.trim());
  return a.length === b.length && timingSafeEqual(a, b);
}

function isAdminAuthorized(req: Request, claims: JwtClaims | null): boolean {
  if (claims?.role === 'admin') return true;
  return hasValidAdminCode(req.headers.get('x-admin-code'));
}

function decodeWmoWeather(code: number): string {
  if (code === 0) return 'Clear Sky';
  if (code <= 3) return 'Partly Cloudy / Overcast';
  if (code <= 48) return 'Fog / Haze';
  if (code <= 57) return 'Light Drizzle';
  if (code <= 67) return 'Moderate to Heavy Rain';
  if (code <= 82) return 'Heavy Rain Showers';
  if (code >= 95) return 'Thunderstorm / Squall';
  return 'Active Weather';
}

function csvCell(value: unknown): string {
  let str = String(value ?? '');
  if (/^[=+\-@\t\r]/.test(str)) {
    str = `'${str}`;
  }
  if (/[",\n\r]/.test(str)) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

function buildEvaluationSummary(rows: IsoEvaluationRecord[]) {
  const total = rows.length;
  if (total === 0) {
    return {
      totalRespondents: 0,
      means: {
        functionality: 0,
        usability: 0,
        offlineReliability: 0,
        effectiveness: 0,
        overallMean: 0,
        averageReadinessPct: 0,
      },
      byPlatform: {},
      recent: [],
    };
  }

  let fnSum = 0;
  let usSum = 0;
  let relSum = 0;
  let effSum = 0;
  let readySum = 0;
  const byPlatform: Record<string, number> = {};

  for (const r of rows) {
    fnSum += r.functionalityScore;
    usSum += r.usabilityScore;
    relSum += r.reliabilityScore;
    effSum += r.effectivenessScore;
    readySum += r.readinessPercentage;
    byPlatform[r.platform] = (byPlatform[r.platform] ?? 0) + 1;
  }

  const fnMean = fnSum / total;
  const usMean = usSum / total;
  const relMean = relSum / total;
  const effMean = effSum / total;
  const overallMean = (fnMean + usMean + relMean + effMean) / 4;

  return {
    totalRespondents: total,
    means: {
      functionality: Number(fnMean.toFixed(2)),
      usability: Number(usMean.toFixed(2)),
      offlineReliability: Number(relMean.toFixed(2)),
      effectiveness: Number(effMean.toFixed(2)),
      overallMean: Number(overallMean.toFixed(2)),
      averageReadinessPct: Number((readySum / total).toFixed(1)),
    },
    byPlatform,
    recent: rows.slice(0, 50),
  };
}

export async function handleApiRequest(
  req: Request,
  store: DataStore,
  opts?: {
    sendResetEmail?: (payload: ResetEmailPayload) => Promise<void>;
  },
): Promise<Response> {
  try {
    const path = normalizeApiPath(req.url);
    const method = req.method.toUpperCase();

    if (method === 'GET' && path === '/health') {
      const dbOk = await store.ping();
      return json({
        ok: true,
        service: 'lifecheckpoint-api',
        database: dbOk ? 'connected' : 'unavailable',
        timestamp: new Date().toISOString(),
      });
    }

    if (method === 'POST' && path === '/auth/register') {
      const body = await parseJsonBody(req);
      const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
      const password = typeof body.password === 'string' ? body.password : '';
      const fullName = typeof body.fullName === 'string' ? body.fullName.trim() : '';
      const householdName =
        typeof body.householdName === 'string' ? body.householdName.trim() : '';
      const inviteCode =
        typeof body.inviteCode === 'string' ? body.inviteCode.trim().toUpperCase() : '';
      const adminCode =
        typeof body.adminCode === 'string' ? body.adminCode.trim() : '';

      if (!email || !email.includes('@') || password.length < 6 || !fullName) {
        return json(
          { error: 'Provide a valid email, full name, and password (min 6 chars).' },
          400,
        );
      }

      const existing = await store.getUserByEmail(email);
      if (existing) {
        return json({ error: 'An account with this email already exists.' }, 409);
      }

      let role: UserRole = 'household';
      if (adminCode.length > 0) {
        if (!hasValidAdminCode(adminCode)) {
          return json({ error: 'Invalid researcher/admin invite code.' }, 403);
        }
        role = 'admin';
      }

      let household = inviteCode
        ? await store.getHouseholdByInviteCode(inviteCode)
        : null;
      if (inviteCode && !household) {
        return json({ error: 'Household invite code not found.' }, 404);
      }
      if (!household) {
        household = await store.createHousehold(
          householdName || `${fullName.split(' ')[0]}'s Household`,
          generateInviteCode(6),
        );
      }

      const user = await store.createUser({
        email,
        passwordHash: hashPassword(password),
        fullName,
        role,
        householdId: household.id,
      });

      const token = signJwt(
        {
          sub: user.id,
          email: user.email,
          fullName: user.fullName,
          role: user.role,
          householdId: household.id,
        },
        getRequiredEnv('JWT_SECRET'),
      );

      return json(
        {
          token,
          user: {
            id: user.id,
            email: user.email,
            fullName: user.fullName,
            role: user.role,
          },
          household: {
            id: household.id,
            name: household.name,
            inviteCode: household.inviteCode,
          },
        },
        201,
      );
    }

    if (method === 'POST' && path === '/auth/login') {
      const body = await parseJsonBody(req);
      const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
      const password = typeof body.password === 'string' ? body.password : '';
      if (!email || !password) {
        return json({ error: 'Email and password are required.' }, 400);
      }

      const user = await store.getUserByEmail(email);
      if (!user || !verifyPassword(password, user.passwordHash)) {
        return json({ error: 'Invalid email or password.' }, 401);
      }

      let household = await store.getHouseholdById(user.householdId);
      if (!household) {
        household = await store.createHousehold(
          `${user.fullName.split(' ')[0]}'s Household`,
          generateInviteCode(6),
        );
        await store.updateUserHousehold(user.id, household.id);
      }

      const token = signJwt(
        {
          sub: user.id,
          email: user.email,
          fullName: user.fullName,
          role: user.role,
          householdId: household.id,
        },
        getRequiredEnv('JWT_SECRET'),
      );

      return json({
        token,
        user: {
          id: user.id,
          email: user.email,
          fullName: user.fullName,
          role: user.role,
        },
        household: {
          id: household.id,
          name: household.name,
          inviteCode: household.inviteCode,
        },
      });
    }

    if (method === 'GET' && path === '/auth/me') {
      const claims = getBearerClaims(req);
      if (!claims) return json({ error: 'Unauthorized' }, 401);
      const user = await store.getUserById(claims.sub);
      const household = await store.getHouseholdById(claims.householdId);
      if (!user || !household) return json({ error: 'Session not found' }, 401);

      return json({
        user: {
          id: user.id,
          email: user.email,
          fullName: user.fullName,
          role: user.role,
        },
        household: {
          id: household.id,
          name: household.name,
          inviteCode: household.inviteCode,
        },
      });
    }

    if (method === 'DELETE' && path === '/auth/me') {
      const claims = getBearerClaims(req);
      if (!claims) return json({ error: 'Unauthorized' }, 401);
      if (claims.role === 'admin') {
        return json(
          { error: 'Admin accounts cannot be self-deleted from the household menu.' },
          403,
        );
      }

      const result = await store.deleteUserAccount(claims.sub);
      if (!result.deleted) {
        return json({ error: 'Account not found.' }, 404);
      }
      return json({
        deleted: true,
        householdDeleted: result.householdDeleted,
      });
    }

    if (method === 'PATCH' && path === '/auth/password') {
      const claims = getBearerClaims(req);
      if (!claims) return json({ error: 'Unauthorized' }, 401);

      const body = await parseJsonBody(req);
      const currentPassword =
        typeof body.currentPassword === 'string' ? body.currentPassword : '';
      const newPassword =
        typeof body.newPassword === 'string' ? body.newPassword : '';

      if (!currentPassword || newPassword.length < 6) {
        return json(
          {
            error:
              'Enter your current password and a new password (min 6 characters).',
          },
          400,
        );
      }

      const user = await store.getUserById(claims.sub);
      if (!user || !verifyPassword(currentPassword, user.passwordHash)) {
        return json({ error: 'Current password is incorrect.' }, 401);
      }

      await store.updateUserPassword(user.id, hashPassword(newPassword));
      return json({ ok: true, message: 'Password updated successfully.' });
    }

    if (method === 'POST' && path === '/auth/forgot-password') {
      const body = await parseJsonBody(req);
      const email =
        typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
      if (!email || !email.includes('@')) {
        return json({ error: 'Please enter a valid email address.' }, 400);
      }

      const sender = opts?.sendResetEmail ?? sendPasswordResetEmail;
      if (!opts?.sendResetEmail && !isEmailResetConfigured()) {
        return json(
          {
            error:
              'Email password reset is not configured yet (set GMAIL_USER and GMAIL_APP_PASSWORD in Vercel).',
          },
          503,
        );
      }

      const user = await store.getUserByEmail(email);
      if (user && user.role !== 'admin') {
        const otp = generateNumericOtp(6);
        const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
        await store.setPasswordResetCode(email, hashPassword(otp), expiresAt);
        try {
          await sender({
            to: user.email,
            fullName: user.fullName,
            code: otp,
          });
        } catch (err) {
          const detail = err instanceof Error ? err.message : 'SMTP error';
          return json(
            {
              error: `Unable to send reset email right now (${detail}). Check Gmail App Password settings.`,
            },
            502,
          );
        }
      }

      // Generic 200 response prevents email enumeration attacks
      return json({
        ok: true,
        message:
          'If an account exists for that email, a 6-digit reset code has been sent to your inbox.',
      });
    }

    if (method === 'POST' && path === '/auth/reset-password') {
      const body = await parseJsonBody(req);
      const email =
        typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
      const rawCode =
        typeof body.code === 'string'
          ? body.code
          : typeof body.recoveryCode === 'string'
            ? body.recoveryCode
            : '';
      const code = rawCode.trim();
      const newPassword =
        typeof body.newPassword === 'string' ? body.newPassword : '';

      if (!email || !email.includes('@') || !code || newPassword.length < 6) {
        return json(
          {
            error:
              'Provide your email, 6-digit email reset code, and a new password (min 6 chars).',
          },
          400,
        );
      }

      const user = await store.getUserByEmail(email);
      if (
        !user ||
        user.role === 'admin' ||
        !user.passwordResetCodeHash ||
        !user.passwordResetExpiresAt
      ) {
        return json(
          {
            error:
              'Invalid or expired 6-digit reset code. Please request a new code.',
          },
          400,
        );
      }

      const expiresMs = new Date(user.passwordResetExpiresAt).getTime();
      if (
        !Number.isFinite(expiresMs) ||
        expiresMs <= Date.now() ||
        !verifyPassword(code, user.passwordResetCodeHash)
      ) {
        return json(
          {
            error:
              'Invalid or expired 6-digit reset code. Please request a new code.',
          },
          400,
        );
      }

      await store.updateUserPassword(user.id, hashPassword(newPassword));
      return json({
        ok: true,
        message: 'Password reset! You can now sign in with your new password.',
      });
    }

    if (method === 'POST' && path === '/households/join') {
      const claims = getBearerClaims(req);
      if (!claims) return json({ error: 'Unauthorized' }, 401);

      const body = await parseJsonBody(req);
      const inviteCode =
        typeof body.inviteCode === 'string' ? body.inviteCode.trim().toUpperCase() : '';
      if (!inviteCode) {
        return json({ error: 'Household inviteCode is required.' }, 400);
      }

      const target = await store.getHouseholdByInviteCode(inviteCode);
      if (!target) {
        return json({ error: 'Invalid household invite code.' }, 404);
      }

      await store.updateUserHousehold(claims.sub, target.id);
      const token = signJwt(
        {
          sub: claims.sub,
          email: claims.email,
          fullName: claims.fullName,
          role: claims.role,
          householdId: target.id,
        },
        getRequiredEnv('JWT_SECRET'),
      );

      return json({
        token,
        household: {
          id: target.id,
          name: target.name,
          inviteCode: target.inviteCode,
        },
      });
    }

    if (method === 'GET' && path === '/sync/bundle') {
      const claims = getBearerClaims(req);
      if (!claims) return json({ error: 'Unauthorized' }, 401);

      const bundle = await store.getSyncBundle(claims.householdId);
      if (!bundle) return json({ error: 'Household not found' }, 404);
      return json(bundle);
    }

    if (method === 'PUT' && path === '/kit') {
      const claims = getBearerClaims(req);
      if (!claims) return json({ error: 'Unauthorized' }, 401);

      const body = await parseJsonBody(req);
      const items = Array.isArray(body.items) ? (body.items as KitItemRecord[]) : undefined;
      const profile =
        body.profile && typeof body.profile === 'object'
          ? (body.profile as HouseholdProfileData)
          : undefined;
      const expiryAlertDays =
        typeof body.expiryAlertDays === 'number'
          ? Math.min(365, Math.max(1, Math.round(body.expiryAlertDays)))
          : undefined;

      const merged = await store.upsertKitBatch(claims.householdId, {
        items,
        profile,
        expiryAlertDays,
      });
      return json({ items: merged });
    }

    if (method === 'DELETE' && path.startsWith('/kit/')) {
      const claims = getBearerClaims(req);
      if (!claims) return json({ error: 'Unauthorized' }, 401);

      const itemId = decodeURIComponent(path.slice('/kit/'.length)).trim();
      if (!itemId) return json({ error: 'Item id is required.' }, 400);

      await store.markKitItemDeleted(
        claims.householdId,
        itemId,
        new Date().toISOString(),
      );
      return json({ deleted: true, id: itemId });
    }

    if (method === 'PUT' && path === '/plan') {
      const claims = getBearerClaims(req);
      if (!claims) return json({ error: 'Unauthorized' }, 401);

      const body = await parseJsonBody(req);
      const saved = await store.updateEmergencyPlan(claims.householdId, body);
      return json({ plan: saved });
    }

    if (method === 'GET' && path === '/checkins') {
      const claims = getBearerClaims(req);
      if (!claims) return json({ error: 'Unauthorized' }, 401);

      const checkins = await store.getCheckins(claims.householdId, 25);
      return json({ checkins });
    }

    if (method === 'POST' && path === '/checkins') {
      const claims = getBearerClaims(req);
      if (!claims) return json({ error: 'Unauthorized' }, 401);

      const body = await parseJsonBody(req);
      const status = typeof body.status === 'string' ? body.status.trim() : '';
      const note = typeof body.note === 'string' ? body.note.trim() : '';
      if (!status) return json({ error: 'status is required.' }, 400);

      const record = await store.addCheckin({
        householdId: claims.householdId,
        userId: claims.sub,
        authorName: claims.fullName,
        status,
        note,
        latitude: typeof body.latitude === 'number' ? body.latitude : null,
        longitude: typeof body.longitude === 'number' ? body.longitude : null,
      });
      return json({ checkin: record }, 201);
    }

    if (method === 'GET' && path === '/shelters') {
      const claims = getBearerClaims(req);
      const shelters = await store.getShelters(claims?.householdId ?? null);
      return json({ shelters });
    }

    if (method === 'POST' && path === '/shelters') {
      const claims = getBearerClaims(req);
      if (!claims) return json({ error: 'Unauthorized' }, 401);

      const body = await parseJsonBody(req);
      const name = typeof body.name === 'string' ? body.name.trim() : '';
      if (!name) return json({ error: 'Shelter name is required.' }, 400);

      const rawId =
        typeof body.id === 'string' && body.id.trim() ? body.id.trim() : '';
      const isAdminOfficial = claims.role === 'admin' && body.isOfficial === true;
      const safeId = isAdminOfficial
        ? rawId || `official_${Date.now()}`
        : rawId.startsWith('custom_')
          ? rawId
          : `custom_${Date.now()}`;

      const shelter: EvacuationCenterRecord = {
        id: safeId,
        name,
        address:
          typeof body.address === 'string' && body.address.trim()
            ? body.address.trim()
            : 'Local Barangay Site, City of Manila',
        city:
          typeof body.city === 'string' && body.city.trim()
            ? body.city.trim()
            : 'Manila',
        latitude: typeof body.latitude === 'number' ? body.latitude : 14.5822,
        longitude: typeof body.longitude === 'number' ? body.longitude : 120.9882,
        contactPerson:
          typeof body.contactPerson === 'string' && body.contactPerson.trim()
            ? body.contactPerson.trim()
            : 'Barangay DRRM Officer',
        contactNumber:
          typeof body.contactNumber === 'string' && body.contactNumber.trim()
            ? body.contactNumber.trim()
            : '(02) 8568-6909',
        capacityPeople:
          typeof body.capacityPeople === 'number' ? body.capacityPeople : 400,
        isOpen: typeof body.isOpen === 'boolean' ? body.isOpen : true,
        facilities:
          typeof body.facilities === 'string' && body.facilities.trim()
            ? body.facilities.trim()
            : 'Community Saved Evacuation Shelter',
        isOfficial: isAdminOfficial,
      };

      const saved = await store.addShelter(
        isAdminOfficial ? null : claims.householdId,
        shelter,
      );
      if (!saved) {
        return json(
          { error: 'Cannot overwrite an official or another household shelter.' },
          403,
        );
      }
      return json({ shelter: saved }, 201);
    }

    if (method === 'DELETE' && path.startsWith('/shelters/')) {
      const claims = getBearerClaims(req);
      if (!claims) return json({ error: 'Unauthorized' }, 401);

      const id = decodeURIComponent(path.slice('/shelters/'.length)).trim();
      if (!id) return json({ error: 'Shelter id is required.' }, 400);
      const deleted = await store.deleteHouseholdShelter(claims.householdId, id);
      if (!deleted) {
        return json(
          { error: 'Custom household shelter not found or cannot delete official shelter.' },
          404,
        );
      }
      return json({ deleted: true, id });
    }

    if (method === 'PATCH' && path.startsWith('/shelters/')) {
      const claims = getBearerClaims(req);
      if (!isAdminAuthorized(req, claims)) {
        return json({ error: 'Admin access required to update shelter status.' }, 403);
      }

      const id = decodeURIComponent(path.slice('/shelters/'.length)).trim();
      const body = await parseJsonBody(req);
      const updated = await store.updateShelterStatus(id, {
        isOpen: typeof body.isOpen === 'boolean' ? body.isOpen : undefined,
        capacityPeople:
          typeof body.capacityPeople === 'number'
            ? Math.max(0, Math.round(body.capacityPeople))
            : undefined,
        name:
          typeof body.name === 'string' && body.name.trim()
            ? body.name.trim()
            : undefined,
        address:
          typeof body.address === 'string' && body.address.trim()
            ? body.address.trim()
            : undefined,
        city:
          typeof body.city === 'string' && body.city.trim()
            ? body.city.trim()
            : undefined,
        latitude:
          typeof body.latitude === 'number' && Number.isFinite(body.latitude)
            ? body.latitude
            : undefined,
        longitude:
          typeof body.longitude === 'number' && Number.isFinite(body.longitude)
            ? body.longitude
            : undefined,
        contactPerson:
          typeof body.contactPerson === 'string'
            ? body.contactPerson.trim()
            : undefined,
        contactNumber:
          typeof body.contactNumber === 'string'
            ? body.contactNumber.trim()
            : undefined,
        facilities:
          typeof body.facilities === 'string' ? body.facilities.trim() : undefined,
      });

      if (!updated) return json({ error: 'Shelter not found.' }, 404);
      return json({ shelter: updated });
    }

    if (method === 'PATCH' && path.startsWith('/admin/checkins/')) {
      const claims = getBearerClaims(req);
      if (!isAdminAuthorized(req, claims)) {
        return json({ error: 'Admin authorization required.' }, 403);
      }
      const id = decodeURIComponent(path.slice('/admin/checkins/'.length)).trim();
      if (!id) return json({ error: 'Check-in id is required.' }, 400);
      const body = await parseJsonBody(req);
      const acknowledged = body.acknowledged !== false;
      const updated = await store.acknowledgeCheckin(
        id,
        claims?.fullName || 'DRRM Admin',
        acknowledged,
      );
      if (!updated) return json({ error: 'Check-in not found.' }, 404);
      return json({ checkin: updated });
    }

    if (method === 'GET' && path === '/advisories') {
      const advisories = await store.getAdvisories(true);
      return json({ advisories });
    }

    if (method === 'POST' && path === '/admin/advisories') {
      const claims = getBearerClaims(req);
      if (!isAdminAuthorized(req, claims)) {
        return json({ error: 'Admin authorization required to post advisories.' }, 403);
      }
      const body = await parseJsonBody(req);
      const title = typeof body.title === 'string' ? body.title.trim() : '';
      const message = typeof body.message === 'string' ? body.message.trim() : '';
      if (!title || !message) {
        return json({ error: 'Advisory title and message are required.' }, 400);
      }
      const rawSev = typeof body.severity === 'string' ? body.severity.toLowerCase() : 'warning';
      const severity: AdvisorySeverity =
        rawSev === 'critical' || rawSev === 'info' ? rawSev : 'warning';
      const area =
        typeof body.area === 'string' && body.area.trim()
          ? body.area.trim().slice(0, 80)
          : 'City of Manila';

      const advisory = await store.createAdvisory({
        title: title.slice(0, 140),
        message: message.slice(0, 600),
        severity,
        area,
        authorName: claims?.fullName || 'DRRM Admin',
      });
      return json({ advisory }, 201);
    }

    if (method === 'PATCH' && path.startsWith('/admin/advisories/')) {
      const claims = getBearerClaims(req);
      if (!isAdminAuthorized(req, claims)) {
        return json({ error: 'Admin authorization required.' }, 403);
      }
      const id = decodeURIComponent(path.slice('/admin/advisories/'.length)).trim();
      if (!id) return json({ error: 'Advisory id is required.' }, 400);
      const body = await parseJsonBody(req);
      const rawSev = typeof body.severity === 'string' ? body.severity.toLowerCase() : undefined;
      const severity: AdvisorySeverity | undefined =
        rawSev === 'critical' || rawSev === 'warning' || rawSev === 'info'
          ? rawSev
          : undefined;
      const updated = await store.updateAdvisory(id, {
        isActive: typeof body.isActive === 'boolean' ? body.isActive : undefined,
        title: typeof body.title === 'string' && body.title.trim() ? body.title.trim().slice(0, 140) : undefined,
        message: typeof body.message === 'string' && body.message.trim() ? body.message.trim().slice(0, 600) : undefined,
        severity,
        area: typeof body.area === 'string' && body.area.trim() ? body.area.trim().slice(0, 80) : undefined,
      });
      if (!updated) return json({ error: 'Advisory not found.' }, 404);
      return json({ advisory: updated });
    }

    if (method === 'DELETE' && path.startsWith('/admin/advisories/')) {
      const claims = getBearerClaims(req);
      if (!isAdminAuthorized(req, claims)) {
        return json({ error: 'Admin authorization required.' }, 403);
      }
      const id = decodeURIComponent(path.slice('/admin/advisories/'.length)).trim();
      if (!id) return json({ error: 'Advisory id is required.' }, 400);
      const deleted = await store.deleteAdvisory(id);
      if (!deleted) return json({ error: 'Advisory not found.' }, 404);
      return json({ deleted: true, id });
    }

    if (method === 'GET' && path === '/admin/overview') {
      const claims = getBearerClaims(req);
      if (!isAdminAuthorized(req, claims)) {
        return json({ error: 'Admin authorization required.' }, 403);
      }
      const overview = await store.getAdminOverview();
      const evaluations = await store.getEvaluations();
      return json({
        ...overview,
        evaluationSummary: buildEvaluationSummary(evaluations),
      });
    }

    if (method === 'POST' && path === '/admin/shelters') {
      const claims = getBearerClaims(req);
      if (!isAdminAuthorized(req, claims)) {
        return json({ error: 'Admin authorization required to add official shelters.' }, 403);
      }

      const body = await parseJsonBody(req);
      const name = typeof body.name === 'string' ? body.name.trim() : '';
      if (!name) return json({ error: 'Shelter name is required.' }, 400);

      const shelter: EvacuationCenterRecord = {
        id:
          typeof body.id === 'string' && body.id.trim()
            ? body.id.trim()
            : `official_${Date.now()}`,
        name,
        address:
          typeof body.address === 'string' && body.address.trim()
            ? body.address.trim()
            : 'City of Manila',
        city:
          typeof body.city === 'string' && body.city.trim()
            ? body.city.trim()
            : 'Manila',
        latitude: typeof body.latitude === 'number' ? body.latitude : 14.5822,
        longitude: typeof body.longitude === 'number' ? body.longitude : 120.9882,
        contactPerson:
          typeof body.contactPerson === 'string' && body.contactPerson.trim()
            ? body.contactPerson.trim()
            : 'Manila DRRMO',
        contactNumber:
          typeof body.contactNumber === 'string' && body.contactNumber.trim()
            ? body.contactNumber.trim()
            : '(02) 8568-6909',
        capacityPeople:
          typeof body.capacityPeople === 'number'
            ? Math.max(0, Math.round(body.capacityPeople))
            : 500,
        isOpen: typeof body.isOpen === 'boolean' ? body.isOpen : true,
        facilities:
          typeof body.facilities === 'string' && body.facilities.trim()
            ? body.facilities.trim()
            : 'Official Emergency Evacuation Center',
        isOfficial: true,
      };

      const saved = await store.addShelter(null, shelter);
      if (!saved) {
        return json({ error: 'Unable to save shelter.' }, 500);
      }
      return json({ shelter: saved }, 201);
    }

    if (method === 'DELETE' && path.startsWith('/admin/shelters/')) {
      const claims = getBearerClaims(req);
      if (!isAdminAuthorized(req, claims)) {
        return json({ error: 'Admin authorization required to remove shelters.' }, 403);
      }
      const id = decodeURIComponent(path.slice('/admin/shelters/'.length)).trim();
      if (!id) return json({ error: 'Shelter id is required.' }, 400);
      const deleted = await store.deleteShelter(id);
      if (!deleted) return json({ error: 'Shelter not found.' }, 404);
      return json({ deleted: true, id });
    }

    if (method === 'GET' && path === '/telemetry') {
      const url = new URL(req.url, 'http://localhost');
      const rawLat = Number(url.searchParams.get('lat') ?? 14.5822);
      const rawLng = Number(url.searchParams.get('lng') ?? 120.9882);
      const lat = Number.isFinite(rawLat) && rawLat >= -90 && rawLat <= 90 ? rawLat : 14.5822;
      const lng =
        Number.isFinite(rawLng) && rawLng >= -180 && rawLng <= 180 ? rawLng : 120.9882;

      const cacheKey = `${lat.toFixed(2)},${lng.toFixed(2)}`;
      const cached = await store.getTelemetryCache(cacheKey);
      if (cached) {
        const ageMs = Date.now() - new Date(cached.fetchedAt).getTime();
        if (ageMs < TELEMETRY_TTL_MS) {
          return json({ ...cached.payload, cached: true, lastUpdated: cached.fetchedAt });
        }
      }

      const fetched = await fetchUpstreamTelemetry(lat, lng);
      if (fetched) {
        await store.setTelemetryCache(cacheKey, lat, lng, fetched);
        return json({
          ...fetched,
          cached: false,
          lastUpdated: new Date().toISOString(),
        });
      }

      if (cached) {
        return json({
          ...cached.payload,
          cached: true,
          stale: true,
          lastUpdated: cached.fetchedAt,
        });
      }

      return json({ error: 'Upstream telemetry temporarily unavailable.' }, 503);
    }

    if (method === 'POST' && path === '/evaluations') {
      const claims = getBearerClaims(req);
      const body = await parseJsonBody(req);

      const functionalityScore = clampLikert(body.functionalityScore);
      const usabilityScore = clampLikert(body.usabilityScore);
      const reliabilityScore = clampLikert(body.reliabilityScore);
      const effectivenessScore = clampLikert(body.effectivenessScore);

      if (
        functionalityScore === null ||
        usabilityScore === null ||
        reliabilityScore === null ||
        effectivenessScore === null
      ) {
        return json(
          { error: 'All four ISO/IEC 25010 scores must be integers from 1 to 5.' },
          400,
        );
      }

      const saved = await store.createEvaluation({
        householdId: claims?.householdId ?? null,
        respondentLabel:
          typeof body.respondentLabel === 'string' && body.respondentLabel.trim()
            ? body.respondentLabel.trim().slice(0, 80)
            : claims?.fullName || 'Anonymous Household',
        platform:
          typeof body.platform === 'string' && body.platform.trim()
            ? body.platform.trim().toLowerCase().slice(0, 24)
            : 'web',
        functionalityScore,
        usabilityScore,
        reliabilityScore,
        effectivenessScore,
        readinessPercentage:
          typeof body.readinessPercentage === 'number'
            ? Number(body.readinessPercentage.toFixed(1))
            : 0,
        rawCompletionPercentage:
          typeof body.rawCompletionPercentage === 'number'
            ? Number(body.rawCompletionPercentage.toFixed(1))
            : 0,
        comments:
          typeof body.comments === 'string' ? body.comments.trim().slice(0, 500) : '',
      });

      return json({ evaluation: saved }, 201);
    }

    if (method === 'GET' && path === '/evaluations/summary') {
      const claims = getBearerClaims(req);
      if (!isAdminAuthorized(req, claims)) {
        return json(
          { error: 'Researcher/Admin authorization required to view Chapter 4 dataset.' },
          403,
        );
      }
      const rows = await store.getEvaluations();
      return json(buildEvaluationSummary(rows));
    }

    if (method === 'GET' && path === '/evaluations/export') {
      const claims = getBearerClaims(req);
      if (!isAdminAuthorized(req, claims)) {
        return json(
          { error: 'Researcher/Admin authorization required to export CSV.' },
          403,
        );
      }

      const rows = await store.getEvaluations();
      const header = [
        'id',
        'created_at',
        'respondent_label',
        'platform',
        'functionality_score',
        'usability_score',
        'offline_reliability_score',
        'effectiveness_score',
        'weighted_mean',
        'readiness_percentage',
        'raw_completion_percentage',
        'comments',
      ].join(',');

      const lines = rows.map((r) => {
        const mean = (
          (r.functionalityScore +
            r.usabilityScore +
            r.reliabilityScore +
            r.effectivenessScore) /
          4
        ).toFixed(2);
        return [
          r.id,
          r.createdAt,
          r.respondentLabel,
          r.platform,
          r.functionalityScore,
          r.usabilityScore,
          r.reliabilityScore,
          r.effectivenessScore,
          mean,
          r.readinessPercentage,
          r.rawCompletionPercentage,
          r.comments,
        ]
          .map(csvCell)
          .join(',');
      });

      return new Response([header, ...lines].join('\n'), {
        status: 200,
        headers: {
          'content-type': 'text/csv; charset=utf-8',
          'content-disposition':
            'attachment; filename="lifecheckpoint_iso25010_evaluations.csv"',
          'cache-control': 'no-store',
        },
      });
    }

    return json({ error: `Route not found: ${method} ${path}` }, 404);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Internal server error';
    return json({ error: message }, 500);
  }
}

function clampLikert(val: unknown): number | null {
  if (typeof val !== 'number' || !Number.isFinite(val)) return null;
  const rounded = Math.round(val);
  if (rounded < 1 || rounded > 5) return null;
  return rounded;
}

async function fetchUpstreamTelemetry(
  lat: number,
  lng: number,
): Promise<Record<string, unknown> | null> {
  let weather: Record<string, unknown> | null = null;
  let earthquakes: Array<Record<string, unknown>> = [];

  try {
    const wUrl = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lng}&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,wind_speed_10m,weather_code&hourly=precipitation_probability,precipitation&forecast_hours=6&timezone=Asia%2FManila`;
    const resp = await fetch(wUrl, { signal: AbortSignal.timeout(6000) });
    if (resp.ok) {
      const data = (await resp.json()) as {
        current?: Record<string, unknown>;
        hourly?: {
          precipitation_probability?: number[];
          precipitation?: number[];
        };
      };
      const cur = data.current;
      if (cur) {
        const code = Number(cur.weather_code ?? 0);
        const tempC = Number(cur.temperature_2m ?? 29);
        const probs = Array.isArray(data.hourly?.precipitation_probability)
          ? data.hourly!.precipitation_probability!.map((n) => Number(n ?? 0))
          : [];
        const rainVals = Array.isArray(data.hourly?.precipitation)
          ? data.hourly!.precipitation!.map((n) => Number(n ?? 0))
          : [];
        const maxRainChance = probs.length > 0 ? Math.max(...probs) : 0;
        const rainSum6h = rainVals.reduce((acc, v) => acc + v, 0);
        weather = {
          temperatureC: tempC,
          apparentTemperatureC: Number(cur.apparent_temperature ?? tempC),
          humidityPct: Math.round(Number(cur.relative_humidity_2m ?? 70)),
          windSpeedKmh: Number(cur.wind_speed_10m ?? 10),
          precipitationMm: Number(cur.precipitation ?? 0),
          rainChance6hPct: Math.round(maxRainChance),
          rainExpected6hMm: Number(rainSum6h.toFixed(1)),
          weatherCode: code,
          conditionText: decodeWmoWeather(code),
        };
      }
    }
  } catch {
    // Graceful upstream weather fallback
  }

  try {
    // Prioritize Luzon / City of Manila bounding box first; fall back to full PH if empty
    const luzonUrl =
      'https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&minlatitude=11.5&maxlatitude=18.8&minlongitude=118.5&maxlongitude=124.5&limit=6&orderby=time';
    const phUrl =
      'https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&minlatitude=4.5&maxlatitude=21.5&minlongitude=116.0&maxlongitude=127.0&limit=5&orderby=time';

    const fetchQuakes = async (url: string) => {
      const resp = await fetch(url, { signal: AbortSignal.timeout(6000) });
      if (!resp.ok) return [];
      const data = (await resp.json()) as {
        features?: Array<{
          id?: string;
          properties?: Record<string, unknown>;
          geometry?: { coordinates?: number[] };
        }>;
      };
      return (data.features ?? []).map((f) => {
        const props = f.properties ?? {};
        const coords = f.geometry?.coordinates ?? [120.9882, 14.5822, 10];
        const ms = Number(props.time ?? Date.now());
        return {
          id: String(f.id ?? ''),
          magnitude: Number(props.mag ?? 0),
          place: String(props.place ?? 'Philippines'),
          time: new Date(ms).toISOString(),
          depthKm: Number(coords[2] ?? 10),
          longitude: typeof coords[0] === 'number' ? coords[0] : null,
          latitude: typeof coords[1] === 'number' ? coords[1] : null,
        };
      });
    };

    earthquakes = await fetchQuakes(luzonUrl);
    if (earthquakes.length === 0) {
      earthquakes = await fetchQuakes(phUrl);
    }
  } catch {
    // Graceful upstream seismic fallback
  }

  if (!weather && earthquakes.length === 0) return null;
  return { weather, earthquakes, latitude: lat, longitude: lng };
}
