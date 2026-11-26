import test from 'node:test';
import assert from 'node:assert/strict';
import { InMemoryStore } from '../../.test-dist/server/lib/repository.js';
import { handleApiRequest } from '../../.test-dist/server/lib/router.js';

process.env.JWT_SECRET = 'test_jwt_secret_for_lifecheckpoint_unit_tests_2026';
process.env.ADMIN_INVITE_CODE = 'DRRM-TEST-ADMIN';

async function callApi(
  store,
  path,
  { method = 'GET', token = null, headers = {}, body = null, sendResetEmail = undefined } = {},
) {
  const reqHeaders = { ...headers };
  if (token) reqHeaders.authorization = `Bearer ${token}`;
  if (body !== null) reqHeaders['content-type'] = 'application/json';

  const req = new Request(`https://lifecheckpoint.vercel.app/api${path}`, {
    method,
    headers: reqHeaders,
    body: body !== null ? JSON.stringify(body) : undefined,
  });

  const res = await handleApiRequest(
    req,
    store,
    sendResetEmail ? { sendResetEmail } : undefined,
  );
  const text = await res.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  return { status: res.status, headers: res.headers, json, text };
}

test('health endpoint returns ok (direct /api/health and Vercel /api?__route=health)', async () => {
  const store = new InMemoryStore();
  const res = await callApi(store, '/health');
  assert.equal(res.status, 200);
  assert.equal(res.json.ok, true);
  assert.equal(res.json.database, 'connected');

  const vercelRes = await callApi(store, '?__route=health');
  assert.equal(vercelRes.status, 200);
  assert.equal(vercelRes.json.ok, true);
});

test('auth, household invite sync, kit timestamp conflict resolution, and plan/checkins', async () => {
  const store = new InMemoryStore();

  // 1. Register user 1
  const reg1 = await callApi(store, '/auth/register', {
    method: 'POST',
    body: {
      email: 'juan@lifecheckpoint.ph',
      password: 'password123',
      fullName: 'Juan Dela Cruz',
      householdName: 'Dela Cruz Family',
    },
  });
  assert.equal(reg1.status, 201);
  assert.ok(reg1.json.token);
  assert.equal(reg1.json.user.role, 'household');
  const inviteCode = reg1.json.household.inviteCode;
  assert.equal(inviteCode.length, 6);

  // 2. Register user 2 joining same household
  const reg2 = await callApi(store, '/auth/register', {
    method: 'POST',
    body: {
      email: 'maria@lifecheckpoint.ph',
      password: 'password123',
      fullName: 'Maria Dela Cruz',
      inviteCode,
    },
  });
  assert.equal(reg2.status, 201);
  assert.equal(reg2.json.household.id, reg1.json.household.id);

  // 3. Upsert kit item newer timestamp then stale timestamp
  const newerTs = '2026-11-18T12:00:00.000Z';
  const staleTs = '2026-11-18T10:00:00.000Z';

  const putNew = await callApi(store, '/kit', {
    method: 'PUT',
    token: reg1.json.token,
    body: {
      expiryAlertDays: 14,
      items: [
        {
          id: 'water_bottles',
          name: 'Drinking Water',
          category: 0,
          quantity: 6,
          targetQuantity: 6,
          unit: 'gallons',
          expirationDate: '2027-05-01T00:00:00.000Z',
          isPacked: true,
          notes: 'City of Manila supply',
          lastUpdated: newerTs,
        },
      ],
    },
  });
  assert.equal(putNew.status, 200);
  assert.equal(putNew.json.items[0].quantity, 6);

  const putStale = await callApi(store, '/kit', {
    method: 'PUT',
    token: reg2.json.token,
    body: {
      items: [
        {
          id: 'water_bottles',
          name: 'Drinking Water',
          category: 0,
          quantity: 1,
          targetQuantity: 6,
          unit: 'gallons',
          expirationDate: null,
          isPacked: false,
          notes: 'Stale offline edit',
          lastUpdated: staleTs,
        },
      ],
    },
  });
  assert.equal(putStale.status, 200);
  assert.equal(putStale.json.items[0].quantity, 6);

  // 4. Plan + Checkin visible to member 2 via /sync/bundle
  const planPut = await callApi(store, '/plan', {
    method: 'PUT',
    token: reg1.json.token,
    body: {
      householdName: 'Dela Cruz City of Manila Household',
      primaryMeetingPoint: 'Rizal Memorial Sports Complex',
    },
  });
  assert.equal(planPut.status, 200);

  const checkinPost = await callApi(store, '/checkins', {
    method: 'POST',
    token: reg1.json.token,
    body: {
      status: 'SAFE',
      note: 'All family members safe at home',
      latitude: 14.5822,
      longitude: 120.9882,
    },
  });
  assert.equal(checkinPost.status, 201);

  const bundle = await callApi(store, '/sync/bundle', { token: reg2.json.token });
  assert.equal(bundle.status, 200);
  assert.equal(bundle.json.household.expiryAlertDays, 14);
  assert.equal(bundle.json.household.plan.primaryMeetingPoint, 'Rizal Memorial Sports Complex');
  assert.equal(bundle.json.checkins.length, 1);
  assert.equal(bundle.json.checkins[0].authorName, 'Juan Dela Cruz');
});

test('shelter RBAC and ISO 25010 evaluations summary & CSV export', async () => {
  const store = new InMemoryStore();

  const hhUser = await callApi(store, '/auth/register', {
    method: 'POST',
    body: {
      email: 'resident@manila.ph',
      password: 'password123',
      fullName: 'Manila Resident',
    },
  });

  const adminUser = await callApi(store, '/auth/register', {
    method: 'POST',
    body: {
      email: 'admin@lifecheckpoint.ph',
      password: 'password123',
      fullName: 'DRRM Admin',
      adminCode: 'DRRM-TEST-ADMIN',
    },
  });
  assert.equal(adminUser.status, 201);
  assert.equal(adminUser.json.user.role, 'admin');

  // Household user cannot update official shelter status
  const forbiddenPatch = await callApi(store, '/shelters/manila_paco_arena', {
    method: 'PATCH',
    token: hhUser.json.token,
    body: { isOpen: false },
  });
  assert.equal(forbiddenPatch.status, 403);

  // Household user can save and delete their own custom shelter, but cannot delete official shelters
  const customShelter = await callApi(store, '/shelters', {
    method: 'POST',
    token: hhUser.json.token,
    body: {
      name: 'Brgy 672 Covered Court',
      address: 'Paco, Manila',
      city: 'Manila',
      latitude: 14.5815,
      longitude: 120.9901,
    },
  });
  assert.equal(customShelter.status, 201);
  assert.equal(customShelter.json.shelter.isOfficial, false);

  const cantDeleteOfficial = await callApi(
    store,
    '/shelters/manila_paco_arena',
    { method: 'DELETE', token: hhUser.json.token },
  );
  assert.equal(cantDeleteOfficial.status, 404);

  const canDeleteOwn = await callApi(
    store,
    `/shelters/${encodeURIComponent(customShelter.json.shelter.id)}`,
    { method: 'DELETE', token: hhUser.json.token },
  );
  assert.equal(canDeleteOwn.status, 200);
  assert.equal(canDeleteOwn.json.deleted, true);

  // Admin can update shelter status
  const okPatch = await callApi(store, '/shelters/manila_paco_arena', {
    method: 'PATCH',
    token: adminUser.json.token,
    body: { isOpen: false, capacityPeople: 950 },
  });
  assert.equal(okPatch.status, 200);
  assert.equal(okPatch.json.shelter.isOpen, false);
  assert.equal(okPatch.json.shelter.capacityPeople, 950);

  // Submit evaluation (including CSV formula attempt in comment)
  const eval1 = await callApi(store, '/evaluations', {
    method: 'POST',
    body: {
      respondentLabel: 'Paco Household #1',
      platform: 'android',
      functionalityScore: 5,
      usabilityScore: 4,
      reliabilityScore: 5,
      effectivenessScore: 5,
      readinessPercentage: 88.5,
      rawCompletionPercentage: 80.0,
      comments: '=HYPERLINK("http://evil.example")',
    },
  });
  assert.equal(eval1.status, 201);

  // Household user blocked from summary
  const blockedSummary = await callApi(store, '/evaluations/summary', {
    token: hhUser.json.token,
  });
  assert.equal(blockedSummary.status, 403);

  // Admin can view summary & CSV export
  const summary = await callApi(store, '/evaluations/summary', {
    token: adminUser.json.token,
  });
  assert.equal(summary.status, 200);
  assert.equal(summary.json.totalRespondents, 1);
  assert.equal(summary.json.means.overallMean, 4.75);

  const csvRes = await callApi(store, '/evaluations/export', {
    token: adminUser.json.token,
  });
  assert.equal(csvRes.status, 200);
  assert.ok(csvRes.headers.get('content-type').includes('text/csv'));
  assert.ok(csvRes.text.includes("'=HYPERLINK"));
});

test('admin overview, official shelter publish/delete, and strict RBAC', async () => {
  const store = new InMemoryStore();

  const hhUser = await callApi(store, '/auth/register', {
    method: 'POST',
    body: {
      email: 'family@manila.ph',
      password: 'password123',
      fullName: 'Santos Family',
      householdName: 'Santos Household',
    },
  });

  await callApi(store, '/checkins', {
    method: 'POST',
    token: hhUser.json.token,
    body: {
      status: 'NEED ASSISTANCE',
      note: 'Floodwater rising near gate',
      latitude: 14.58,
      longitude: 120.98,
    },
  });

  // Regular household user blocked from admin overview
  const blocked = await callApi(store, '/admin/overview', {
    token: hhUser.json.token,
  });
  assert.equal(blocked.status, 403);

  // Valid x-admin-code unlocks admin overview
  const okOverview = await callApi(store, '/admin/overview', {
    headers: { 'x-admin-code': 'DRRM-TEST-ADMIN' },
  });
  assert.equal(okOverview.status, 200);
  assert.equal(okOverview.json.counts.households, 1);
  assert.equal(okOverview.json.counts.checkinsNeedingHelp, 1);
  assert.equal(okOverview.json.recentCheckins.length, 1);

  // Admin can publish, edit, and delete official shelter
  const created = await callApi(store, '/admin/shelters', {
    method: 'POST',
    headers: { 'x-admin-code': 'DRRM-TEST-ADMIN' },
    body: {
      name: 'Paco Barangay Gym',
      address: 'Paco, Manila',
      city: 'Manila',
      capacityPeople: 600,
    },
  });
  assert.equal(created.status, 201);
  assert.equal(created.json.shelter.isOfficial, true);

  const edited = await callApi(
    store,
    `/shelters/${encodeURIComponent(created.json.shelter.id)}`,
    {
      method: 'PATCH',
      headers: { 'x-admin-code': 'DRRM-TEST-ADMIN' },
      body: {
        name: 'Paco Covered Court & DRRM Hub',
        capacityPeople: 750,
        contactNumber: '(02) 8527-5174',
        isOpen: false,
      },
    },
  );
  assert.equal(edited.status, 200);
  assert.equal(edited.json.shelter.name, 'Paco Covered Court & DRRM Hub');
  assert.equal(edited.json.shelter.capacityPeople, 750);
  assert.equal(edited.json.shelter.isOpen, false);

  // Admin can acknowledge SOS check-in -> drops active Need Help count to 0
  const checkinId = okOverview.json.recentCheckins[0].id;
  const acked = await callApi(
    store,
    `/admin/checkins/${encodeURIComponent(checkinId)}`,
    {
      method: 'PATCH',
      headers: { 'x-admin-code': 'DRRM-TEST-ADMIN' },
      body: { acknowledged: true },
    },
  );
  assert.equal(acked.status, 200);
  assert.ok(acked.json.checkin.acknowledgedAt);

  const overviewAfterAck = await callApi(store, '/admin/overview', {
    headers: { 'x-admin-code': 'DRRM-TEST-ADMIN' },
  });
  assert.equal(overviewAfterAck.status, 200);
  assert.equal(overviewAfterAck.json.counts.checkinsNeedingHelp, 0);
  assert.ok(overviewAfterAck.json.households[0].profile);

  // Admin can broadcast, toggle, and delete DRRM advisory (household blocked)
  const blockedAdv = await callApi(store, '/admin/advisories', {
    method: 'POST',
    token: hhUser.json.token,
    body: { title: 'Test', message: 'Unauthorized' },
  });
  assert.equal(blockedAdv.status, 403);

  const createdAdv = await callApi(store, '/admin/advisories', {
    method: 'POST',
    headers: { 'x-admin-code': 'DRRM-TEST-ADMIN' },
    body: {
      title: 'Paco Flood Watch',
      message: 'Rizal Memorial Sports Complex is open for evacuees.',
      severity: 'critical',
      area: 'Manila',
    },
  });
  assert.equal(createdAdv.status, 201);
  assert.equal(createdAdv.json.advisory.severity, 'critical');

  const publicAdvs = await callApi(store, '/advisories');
  assert.equal(publicAdvs.status, 200);
  assert.equal(publicAdvs.json.advisories.length, 1);

  const resolvedAdv = await callApi(
    store,
    `/admin/advisories/${encodeURIComponent(createdAdv.json.advisory.id)}`,
    {
      method: 'PATCH',
      headers: { 'x-admin-code': 'DRRM-TEST-ADMIN' },
      body: { isActive: false },
    },
  );
  assert.equal(resolvedAdv.status, 200);
  assert.equal(resolvedAdv.json.advisory.isActive, false);

  const publicAdvsAfterResolve = await callApi(store, '/advisories');
  assert.equal(publicAdvsAfterResolve.json.advisories.length, 0);

  const deletedAdv = await callApi(
    store,
    `/admin/advisories/${encodeURIComponent(createdAdv.json.advisory.id)}`,
    {
      method: 'DELETE',
      headers: { 'x-admin-code': 'DRRM-TEST-ADMIN' },
    },
  );
  assert.equal(deletedAdv.status, 200);
  assert.equal(deletedAdv.json.deleted, true);

  const deleted = await callApi(
    store,
    `/admin/shelters/${encodeURIComponent(created.json.shelter.id)}`,
    {
      method: 'DELETE',
      headers: { 'x-admin-code': 'DRRM-TEST-ADMIN' },
    },
  );
  assert.equal(deleted.status, 200);
  assert.equal(deleted.json.deleted, true);
});

test('BOLA shelter protection, RA 10173 cloud account deletion, and weighted admin readiness', async () => {
  const store = new InMemoryStore();

  const user = await callApi(store, '/auth/register', {
    method: 'POST',
    body: {
      email: 'privacy.test@manila.ph',
      password: 'password123',
      fullName: 'Manila Household',
      householdName: 'Sampaloc Family',
    },
  });
  assert.equal(user.status, 201);

  // 1. Regular user trying to overwrite an official shelter ID cannot alter the official record
  const hijackAttempt = await callApi(store, '/shelters', {
    method: 'POST',
    token: user.json.token,
    body: {
      id: 'manila_rizal_memorial',
      name: 'Fake Overwrite Attempt',
      isOfficial: true,
      isOpen: false,
    },
  });
  assert.equal(hijackAttempt.status, 201);
  assert.notEqual(hijackAttempt.json.shelter.id, 'manila_rizal_memorial');
  assert.equal(hijackAttempt.json.shelter.isOfficial, false);

  const sheltersAfter = await callApi(store, '/shelters');
  const officialRizal = sheltersAfter.json.shelters.find(
    (s) => s.id === 'manila_rizal_memorial',
  );
  assert.ok(officialRizal);
  assert.equal(officialRizal.isOpen, true);
  assert.ok(officialRizal.name.includes('Rizal Memorial'));

  // 2. Weighted readiness in Admin Overview matches Flutter formula (Water 3x vs Clothing 1x)
  await callApi(store, '/kit', {
    method: 'PUT',
    token: user.json.token,
    body: {
      items: [
        {
          id: 'water_bottles',
          name: 'Drinking Water',
          category: 0, // weight 3
          quantity: 6,
          targetQuantity: 6,
          unit: 'gallons',
          expirationDate: null,
          isPacked: true,
          notes: '',
          lastUpdated: new Date().toISOString(),
        },
        {
          id: 'extra_clothes',
          name: 'Extra Clothes',
          category: 5, // weight 1
          quantity: 0,
          targetQuantity: 2,
          unit: 'sets',
          expirationDate: null,
          isPacked: false,
          notes: '',
          lastUpdated: new Date().toISOString(),
        },
      ],
    },
  });

  const overview = await callApi(store, '/admin/overview', {
    headers: { 'x-admin-code': 'DRRM-TEST-ADMIN' },
  });
  assert.equal(overview.status, 200);
  // 3 / (3 + 1) = 75.0% weighted (not 50% unweighted)
  assert.equal(overview.json.households[0].readinessPct, 75);

  // 3. RA 10173 Right to Erasure: DELETE /auth/me removes user + orphaned household
  const delRes = await callApi(store, '/auth/me', {
    method: 'DELETE',
    token: user.json.token,
  });
  assert.equal(delRes.status, 200);
  assert.equal(delRes.json.deleted, true);
  assert.equal(delRes.json.householdDeleted, true);

  const meAfterDelete = await callApi(store, '/auth/me', {
    token: user.json.token,
  });
  assert.equal(meAfterDelete.status, 401);
});

test('forgot password via Gmail 6-digit email OTP and authenticated change password', async () => {
  const store = new InMemoryStore();
  const sentEmails = [];
  const mockSendEmail = async (payload) => {
    sentEmails.push(payload);
  };

  const reg = await callApi(store, '/auth/register', {
    method: 'POST',
    body: {
      email: 'forgot.user@gmail.com',
      password: 'OldPassword1!',
      fullName: 'Manila Resident',
      householdName: 'Paco Family',
    },
  });
  assert.equal(reg.status, 201);

  // 1. Requesting a reset code for an unknown email still returns 200 (no account enumeration)
  const unknownReq = await callApi(store, '/auth/forgot-password', {
    method: 'POST',
    body: { email: 'nobody@gmail.com' },
    sendResetEmail: mockSendEmail,
  });
  assert.equal(unknownReq.status, 200);
  assert.equal(sentEmails.length, 0);

  // 2. Requesting a reset code for a registered email sends a 6-digit numeric OTP
  const forgotRes = await callApi(store, '/auth/forgot-password', {
    method: 'POST',
    body: { email: 'forgot.user@gmail.com' },
    sendResetEmail: mockSendEmail,
  });
  assert.equal(forgotRes.status, 200);
  assert.equal(sentEmails.length, 1);
  const otpCode = sentEmails[0].code;
  assert.match(otpCode, /^\d{6}$/);

  // 3. Wrong code fails
  const badReset = await callApi(store, '/auth/reset-password', {
    method: 'POST',
    body: {
      email: 'forgot.user@gmail.com',
      code: '000000',
      newPassword: 'NewPassword2!',
    },
  });
  assert.equal(badReset.status, 400);

  // 4. Valid 6-digit emailed OTP resets password cleanly & revokes old JWTs immediately
  const okReset = await callApi(store, '/auth/reset-password', {
    method: 'POST',
    body: {
      email: 'forgot.user@gmail.com',
      code: otpCode,
      newPassword: 'NewPassword2!',
    },
  });
  assert.equal(okReset.status, 200);

  const staleAfterReset = await callApi(store, '/auth/me', {
    token: reg.json.token,
  });
  assert.equal(staleAfterReset.status, 401);

  // 5. Reusing the same 6-digit OTP fails (single-use)
  const reuseAttempt = await callApi(store, '/auth/reset-password', {
    method: 'POST',
    body: {
      email: 'forgot.user@gmail.com',
      code: otpCode,
      newPassword: 'AnotherPass3!',
    },
  });
  assert.equal(reuseAttempt.status, 400);

  const oldLogin = await callApi(store, '/auth/login', {
    method: 'POST',
    body: { email: 'forgot.user@gmail.com', password: 'OldPassword1!' },
  });
  assert.equal(oldLogin.status, 401);

  const newLogin = await callApi(store, '/auth/login', {
    method: 'POST',
    body: { email: 'forgot.user@gmail.com', password: 'NewPassword2!' },
  });
  assert.equal(newLogin.status, 200);

  // 6. Authenticated Change Password (rejects wrong current, accepts right current, revokes old JWT, issues fresh JWT)
  const badChange = await callApi(store, '/auth/password', {
    method: 'PATCH',
    token: newLogin.json.token,
    body: { currentPassword: 'WrongCurrent', newPassword: 'ChangedPass3!' },
  });
  assert.equal(badChange.status, 401);

  const okChange = await callApi(store, '/auth/password', {
    method: 'PATCH',
    token: newLogin.json.token,
    body: { currentPassword: 'NewPassword2!', newPassword: 'ChangedPass3!' },
  });
  assert.equal(okChange.status, 200);
  assert.ok(okChange.json.token);

  const revokedOldToken = await callApi(store, '/auth/me', {
    token: newLogin.json.token,
  });
  assert.equal(revokedOldToken.status, 401);

  const validFreshToken = await callApi(store, '/auth/me', {
    token: okChange.json.token,
  });
  assert.equal(validFreshToken.status, 200);

  const finalLogin = await callApi(store, '/auth/login', {
    method: 'POST',
    body: { email: 'forgot.user@gmail.com', password: 'ChangedPass3!' },
  });
  assert.equal(finalLogin.status, 200);
});

test('OTP brute-force lockout after 5 wrong guesses, 60s resend cooldown, and strict email validation', async () => {
  const store = new InMemoryStore();
  const sentEmails = [];
  const mockSendEmail = async (payload) => {
    sentEmails.push(payload);
  };

  // Reject CRLF / SMTP header-injection email on registration
  const badEmailReg = await callApi(store, '/auth/register', {
    method: 'POST',
    body: {
      email: 'attacker@example.com\r\nBcc: victim@example.com',
      password: 'Password123!',
      fullName: 'Bad Input',
    },
  });
  assert.equal(badEmailReg.status, 400);

  const reg = await callApi(store, '/auth/register', {
    method: 'POST',
    body: {
      email: 'lockout.user@manila.ph',
      password: 'InitialPass1!',
      fullName: 'Ermita Resident',
      householdName: 'Ermita Family',
    },
  });
  assert.equal(reg.status, 201);

  // First reset request sends email; immediate second request within 60s is cooldown-throttled silently (still 200)
  const req1 = await callApi(store, '/auth/forgot-password', {
    method: 'POST',
    body: { email: 'lockout.user@manila.ph' },
    sendResetEmail: mockSendEmail,
  });
  assert.equal(req1.status, 200);
  assert.equal(sentEmails.length, 1);
  const realOtp = sentEmails[0].code;

  const req2 = await callApi(store, '/auth/forgot-password', {
    method: 'POST',
    body: { email: 'lockout.user@manila.ph' },
    sendResetEmail: mockSendEmail,
  });
  assert.equal(req2.status, 200);
  assert.equal(sentEmails.length, 1);

  // 4 wrong guesses return 400; 5th wrong guess returns 429 and permanently invalidates the OTP
  const wrongOtp = realOtp === '111111' ? '222222' : '111111';
  for (let i = 0; i < 4; i++) {
    const failRes = await callApi(store, '/auth/reset-password', {
      method: 'POST',
      body: {
        email: 'lockout.user@manila.ph',
        code: wrongOtp,
        newPassword: 'NewPassword9!',
      },
    });
    assert.equal(failRes.status, 400);
  }

  const lockRes = await callApi(store, '/auth/reset-password', {
    method: 'POST',
    body: {
      email: 'lockout.user@manila.ph',
      code: wrongOtp,
      newPassword: 'NewPassword9!',
    },
  });
  assert.equal(lockRes.status, 429);

  // Even the previously valid OTP is now invalidated after lockout
  const afterLock = await callApi(store, '/auth/reset-password', {
    method: 'POST',
    body: {
      email: 'lockout.user@manila.ph',
      code: realOtp,
      newPassword: 'NewPassword9!',
    },
  });
  assert.equal(afterLock.status, 400);
});
