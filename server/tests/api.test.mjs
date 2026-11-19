import test from 'node:test';
import assert from 'node:assert/strict';
import { InMemoryStore } from '../../.test-dist/netlify/lib/repository.js';
import { handleApiRequest } from '../../.test-dist/netlify/lib/router.js';

process.env.JWT_SECRET = 'test_jwt_secret_for_lifecheckpoint_unit_tests_2026';
process.env.ADMIN_INVITE_CODE = 'EAC-TEST-ADMIN';

async function callApi(store, path, { method = 'GET', token = null, headers = {}, body = null } = {}) {
  const reqHeaders = { ...headers };
  if (token) reqHeaders.authorization = `Bearer ${token}`;
  if (body !== null) reqHeaders['content-type'] = 'application/json';

  const req = new Request(`https://lifecheckpoint.netlify.app/api${path}`, {
    method,
    headers: reqHeaders,
    body: body !== null ? JSON.stringify(body) : undefined,
  });

  const res = await handleApiRequest(req, store);
  const text = await res.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  return { status: res.status, headers: res.headers, json, text };
}

test('health endpoint returns ok', async () => {
  const store = new InMemoryStore();
  const res = await callApi(store, '/health');
  assert.equal(res.status, 200);
  assert.equal(res.json.ok, true);
  assert.equal(res.json.database, 'connected');
});

test('auth, household invite sync, kit timestamp conflict resolution, and plan/checkins', async () => {
  const store = new InMemoryStore();

  // 1. Register user 1
  const reg1 = await callApi(store, '/auth/register', {
    method: 'POST',
    body: {
      email: 'juan@eac.edu.ph',
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
      email: 'maria@eac.edu.ph',
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
          notes: 'Paco supply',
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
      householdName: 'Dela Cruz Paco Household',
      primaryMeetingPoint: 'EAC Main Gate',
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
  assert.equal(bundle.json.household.plan.primaryMeetingPoint, 'EAC Main Gate');
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
      email: 'researcher@eac.edu.ph',
      password: 'password123',
      fullName: 'EAC Researcher',
      adminCode: 'EAC-TEST-ADMIN',
    },
  });
  assert.equal(adminUser.status, 201);
  assert.equal(adminUser.json.user.role, 'admin');

  // Household user cannot update official shelter status
  const forbiddenPatch = await callApi(store, '/shelters/eac_campus_reference', {
    method: 'PATCH',
    token: hhUser.json.token,
    body: { isOpen: false },
  });
  assert.equal(forbiddenPatch.status, 403);

  // Admin can update shelter status
  const okPatch = await callApi(store, '/shelters/eac_campus_reference', {
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
