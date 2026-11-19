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
    '/shelters/eac_campus_reference',
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
    headers: { 'x-admin-code': 'EAC-TEST-ADMIN' },
  });
  assert.equal(okOverview.status, 200);
  assert.equal(okOverview.json.counts.households, 1);
  assert.equal(okOverview.json.counts.checkinsNeedingHelp, 1);
  assert.equal(okOverview.json.recentCheckins.length, 1);

  // Admin can publish, edit, and delete official shelter
  const created = await callApi(store, '/admin/shelters', {
    method: 'POST',
    headers: { 'x-admin-code': 'EAC-TEST-ADMIN' },
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
      headers: { 'x-admin-code': 'EAC-TEST-ADMIN' },
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
      headers: { 'x-admin-code': 'EAC-TEST-ADMIN' },
      body: { acknowledged: true },
    },
  );
  assert.equal(acked.status, 200);
  assert.ok(acked.json.checkin.acknowledgedAt);

  const overviewAfterAck = await callApi(store, '/admin/overview', {
    headers: { 'x-admin-code': 'EAC-TEST-ADMIN' },
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
    headers: { 'x-admin-code': 'EAC-TEST-ADMIN' },
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
      headers: { 'x-admin-code': 'EAC-TEST-ADMIN' },
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
      headers: { 'x-admin-code': 'EAC-TEST-ADMIN' },
    },
  );
  assert.equal(deletedAdv.status, 200);
  assert.equal(deletedAdv.json.deleted, true);

  const deleted = await callApi(
    store,
    `/admin/shelters/${encodeURIComponent(created.json.shelter.id)}`,
    {
      method: 'DELETE',
      headers: { 'x-admin-code': 'EAC-TEST-ADMIN' },
    },
  );
  assert.equal(deleted.status, 200);
  assert.equal(deleted.json.deleted, true);
});
