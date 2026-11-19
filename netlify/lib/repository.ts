import { randomUUID } from 'node:crypto';
import { ensureSchema } from './db.js';
import type {
  AdminCheckinItem,
  AdminHouseholdSummary,
  AdminOverviewData,
  EvacuationCenterRecord,
  HouseholdProfileData,
  HouseholdRecord,
  IsoEvaluationInput,
  IsoEvaluationRecord,
  KitItemRecord,
  SafetyCheckinRecord,
  SyncBundle,
  TelemetryCacheRecord,
  UserRecord,
  UserRole,
} from './types.js';

export const DEFAULT_HOUSEHOLD_PROFILE: HouseholdProfileData = {
  adults: 2,
  children: 0,
  infants: 0,
  seniors: 0,
  pets: 0,
  isFloodProne: true,
  isEarthquakeZone: true,
  hasChronicMedicalNeeds: false,
};

export interface DataStore {
  ping(): Promise<boolean>;
  getUserByEmail(email: string): Promise<UserRecord | null>;
  getUserById(id: string): Promise<UserRecord | null>;
  createUser(input: {
    email: string;
    passwordHash: string;
    fullName: string;
    role: UserRole;
    householdId: string;
  }): Promise<UserRecord>;
  updateUserHousehold(userId: string, householdId: string): Promise<void>;

  createHousehold(name: string, inviteCode: string): Promise<HouseholdRecord>;
  getHouseholdById(id: string): Promise<HouseholdRecord | null>;
  getHouseholdByInviteCode(code: string): Promise<HouseholdRecord | null>;

  getSyncBundle(householdId: string): Promise<SyncBundle | null>;
  upsertKitBatch(
    householdId: string,
    input: {
      items?: KitItemRecord[];
      profile?: HouseholdProfileData;
      expiryAlertDays?: number;
    },
  ): Promise<KitItemRecord[]>;
  markKitItemDeleted(
    householdId: string,
    itemId: string,
    deletedAtIso: string,
  ): Promise<void>;

  updateEmergencyPlan(
    householdId: string,
    plan: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;

  addCheckin(input: {
    householdId: string;
    userId: string | null;
    authorName: string;
    status: string;
    note: string;
    latitude: number | null;
    longitude: number | null;
  }): Promise<SafetyCheckinRecord>;
  getCheckins(householdId: string, limit?: number): Promise<SafetyCheckinRecord[]>;

  getShelters(householdId?: string | null): Promise<EvacuationCenterRecord[]>;
  addShelter(
    householdId: string | null,
    shelter: EvacuationCenterRecord,
  ): Promise<EvacuationCenterRecord>;
  updateShelterStatus(
    id: string,
    patch: { isOpen?: boolean; capacityPeople?: number },
  ): Promise<EvacuationCenterRecord | null>;
  deleteShelter(id: string): Promise<boolean>;

  getTelemetryCache(cacheKey: string): Promise<TelemetryCacheRecord | null>;
  setTelemetryCache(
    cacheKey: string,
    latitude: number,
    longitude: number,
    payload: Record<string, unknown>,
  ): Promise<void>;

  createEvaluation(input: IsoEvaluationInput): Promise<IsoEvaluationRecord>;
  getEvaluations(): Promise<IsoEvaluationRecord[]>;
  getAdminOverview(): Promise<AdminOverviewData>;
}

function toIso(val: unknown): string {
  if (val instanceof Date) return val.toISOString();
  if (typeof val === 'string' && val.length > 0) return val;
  return new Date().toISOString();
}

function parseJsonObject<T>(val: unknown, fallback: T): T {
  if (val && typeof val === 'object') return val as T;
  if (typeof val === 'string' && val.trim().length > 0) {
    try {
      return JSON.parse(val) as T;
    } catch {
      return fallback;
    }
  }
  return fallback;
}

function mapHouseholdRow(row: Record<string, unknown>): HouseholdRecord {
  return {
    id: String(row.id),
    name: String(row.name ?? 'My Household'),
    inviteCode: String(row.invite_code),
    profile: parseJsonObject<HouseholdProfileData>(
      row.profile_json,
      DEFAULT_HOUSEHOLD_PROFILE,
    ),
    expiryAlertDays: Number(row.expiry_alert_days ?? 30),
    plan: parseJsonObject<Record<string, unknown>>(row.plan_json, {}),
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
  };
}

function mapUserRow(row: Record<string, unknown>): UserRecord {
  return {
    id: String(row.id),
    email: String(row.email),
    passwordHash: String(row.password_hash),
    fullName: String(row.full_name),
    role: row.role === 'admin' ? 'admin' : 'household',
    householdId: String(row.household_id ?? ''),
    createdAt: toIso(row.created_at),
  };
}

function mapKitRow(row: Record<string, unknown>): KitItemRecord {
  return {
    id: String(row.id),
    name: String(row.name),
    category: Number(row.category_index ?? 0),
    quantity: Number(row.quantity ?? 0),
    targetQuantity: Number(row.target_quantity ?? 1),
    unit: String(row.unit ?? 'pcs'),
    expirationDate: row.expiration_date ? toIso(row.expiration_date) : null,
    isPacked: Boolean(row.is_packed),
    notes: String(row.notes ?? ''),
    lastUpdated: toIso(row.last_updated),
    deleted: Boolean(row.deleted ?? false),
  };
}

function mapCheckinRow(row: Record<string, unknown>): SafetyCheckinRecord {
  return {
    id: String(row.id),
    householdId: String(row.household_id),
    userId: row.user_id ? String(row.user_id) : null,
    authorName: String(row.author_name ?? 'Household Member'),
    status: String(row.status),
    note: String(row.note ?? ''),
    latitude: row.latitude != null ? Number(row.latitude) : null,
    longitude: row.longitude != null ? Number(row.longitude) : null,
    timestamp: toIso(row.created_at),
  };
}

function mapShelterRow(row: Record<string, unknown>): EvacuationCenterRecord {
  return {
    id: String(row.id),
    name: String(row.name),
    address: String(row.address),
    city: String(row.city),
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
    contactPerson: String(row.contact_person),
    contactNumber: String(row.contact_number),
    capacityPeople: Number(row.capacity_people ?? 500),
    isOpen: Boolean(row.is_open ?? true),
    facilities: String(row.facilities ?? ''),
    isOfficial: Boolean(row.is_official ?? false),
    createdByHouseholdId: row.created_by_household_id
      ? String(row.created_by_household_id)
      : null,
    updatedAt: toIso(row.updated_at),
  };
}

function mapEvaluationRow(row: Record<string, unknown>): IsoEvaluationRecord {
  return {
    id: String(row.id),
    householdId: row.household_id ? String(row.household_id) : null,
    respondentLabel: String(row.respondent_label ?? 'Anonymous Household'),
    platform: String(row.platform ?? 'web'),
    functionalityScore: Number(row.functionality_score),
    usabilityScore: Number(row.usability_score),
    reliabilityScore: Number(row.reliability_score),
    effectivenessScore: Number(row.effectiveness_score),
    readinessPercentage: Number(row.readiness_percentage ?? 0),
    rawCompletionPercentage: Number(row.raw_completion_percentage ?? 0),
    comments: String(row.comments ?? ''),
    createdAt: toIso(row.created_at),
  };
}

export class PostgresStore implements DataStore {
  async ping(): Promise<boolean> {
    const sql = await ensureSchema();
    await sql`SELECT 1`;
    return true;
  }

  async getUserByEmail(email: string): Promise<UserRecord | null> {
    const sql = await ensureSchema();
    const rows = await sql`
      SELECT * FROM users WHERE LOWER(email) = LOWER(${email.trim()}) LIMIT 1
    `;
    return rows.length > 0 ? mapUserRow(rows[0]) : null;
  }

  async getUserById(id: string): Promise<UserRecord | null> {
    const sql = await ensureSchema();
    const rows = await sql`SELECT * FROM users WHERE id = ${id} LIMIT 1`;
    return rows.length > 0 ? mapUserRow(rows[0]) : null;
  }

  async createUser(input: {
    email: string;
    passwordHash: string;
    fullName: string;
    role: UserRole;
    householdId: string;
  }): Promise<UserRecord> {
    const sql = await ensureSchema();
    const rows = await sql`
      INSERT INTO users (email, password_hash, full_name, role, household_id)
      VALUES (
        ${input.email.trim().toLowerCase()},
        ${input.passwordHash},
        ${input.fullName.trim()},
        ${input.role},
        ${input.householdId}
      )
      RETURNING *
    `;
    return mapUserRow(rows[0]);
  }

  async updateUserHousehold(userId: string, householdId: string): Promise<void> {
    const sql = await ensureSchema();
    await sql`
      UPDATE users SET household_id = ${householdId} WHERE id = ${userId}
    `;
  }

  async createHousehold(name: string, inviteCode: string): Promise<HouseholdRecord> {
    const sql = await ensureSchema();
    const rows = await sql`
      INSERT INTO households (name, invite_code, profile_json, expiry_alert_days, plan_json)
      VALUES (
        ${name.trim() || 'My Household'},
        ${inviteCode.toUpperCase()},
        ${JSON.stringify(DEFAULT_HOUSEHOLD_PROFILE)}::jsonb,
        30,
        ${JSON.stringify({ householdName: name.trim() || 'My Household' })}::jsonb
      )
      RETURNING *
    `;
    return mapHouseholdRow(rows[0]);
  }

  async getHouseholdById(id: string): Promise<HouseholdRecord | null> {
    const sql = await ensureSchema();
    const rows = await sql`SELECT * FROM households WHERE id = ${id} LIMIT 1`;
    return rows.length > 0 ? mapHouseholdRow(rows[0]) : null;
  }

  async getHouseholdByInviteCode(code: string): Promise<HouseholdRecord | null> {
    const sql = await ensureSchema();
    const rows = await sql`
      SELECT * FROM households WHERE UPPER(invite_code) = UPPER(${code.trim()}) LIMIT 1
    `;
    return rows.length > 0 ? mapHouseholdRow(rows[0]) : null;
  }

  async getSyncBundle(householdId: string): Promise<SyncBundle | null> {
    const sql = await ensureSchema();
    const household = await this.getHouseholdById(householdId);
    if (!household) return null;

    const [kitRows, checkins, shelters] = await Promise.all([
      sql`
        SELECT * FROM kit_items
        WHERE household_id = ${householdId} AND deleted = FALSE
        ORDER BY category_index ASC, name ASC
      `,
      this.getCheckins(householdId, 20),
      this.getShelters(householdId),
    ]);

    return {
      household,
      kitItems: kitRows.map(mapKitRow),
      checkins,
      shelters,
    };
  }

  async upsertKitBatch(
    householdId: string,
    input: {
      items?: KitItemRecord[];
      profile?: HouseholdProfileData;
      expiryAlertDays?: number;
    },
  ): Promise<KitItemRecord[]> {
    const sql = await ensureSchema();

    if (input.profile !== undefined || input.expiryAlertDays !== undefined) {
      await sql`
        UPDATE households
        SET
          profile_json = COALESCE(${input.profile ? JSON.stringify(input.profile) : null}::jsonb, profile_json),
          expiry_alert_days = COALESCE(${input.expiryAlertDays ?? null}, expiry_alert_days),
          updated_at = NOW()
        WHERE id = ${householdId}
      `;
    }

    if (input.items && input.items.length > 0) {
      for (const item of input.items) {
        const expDate = item.expirationDate ? new Date(item.expirationDate) : null;
        const lastUpdated = new Date(item.lastUpdated || Date.now());
        await sql`
          INSERT INTO kit_items (
            household_id, id, name, category_index, quantity, target_quantity,
            unit, expiration_date, is_packed, notes, last_updated, deleted
          ) VALUES (
            ${householdId},
            ${item.id},
            ${item.name},
            ${item.category},
            ${Math.max(0, item.quantity)},
            ${Math.max(1, item.targetQuantity)},
            ${item.unit || 'pcs'},
            ${expDate && !Number.isNaN(expDate.getTime()) ? expDate.toISOString() : null},
            ${Boolean(item.isPacked)},
            ${item.notes || ''},
            ${Number.isNaN(lastUpdated.getTime()) ? new Date().toISOString() : lastUpdated.toISOString()},
            ${Boolean(item.deleted ?? false)}
          )
          ON CONFLICT (household_id, id) DO UPDATE SET
            name = EXCLUDED.name,
            category_index = EXCLUDED.category_index,
            quantity = EXCLUDED.quantity,
            target_quantity = EXCLUDED.target_quantity,
            unit = EXCLUDED.unit,
            expiration_date = EXCLUDED.expiration_date,
            is_packed = EXCLUDED.is_packed,
            notes = EXCLUDED.notes,
            last_updated = EXCLUDED.last_updated,
            deleted = EXCLUDED.deleted
          WHERE EXCLUDED.last_updated >= kit_items.last_updated
        `;
      }
    }

    const rows = await sql`
      SELECT * FROM kit_items
      WHERE household_id = ${householdId} AND deleted = FALSE
      ORDER BY category_index ASC, name ASC
    `;
    return rows.map(mapKitRow);
  }

  async markKitItemDeleted(
    householdId: string,
    itemId: string,
    deletedAtIso: string,
  ): Promise<void> {
    const sql = await ensureSchema();
    await sql`
      UPDATE kit_items
      SET deleted = TRUE, last_updated = ${deletedAtIso}
      WHERE household_id = ${householdId} AND id = ${itemId}
        AND last_updated <= ${deletedAtIso}
    `;
  }

  async updateEmergencyPlan(
    householdId: string,
    plan: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    const sql = await ensureSchema();
    const householdName =
      typeof plan.householdName === 'string' && plan.householdName.trim()
        ? plan.householdName.trim()
        : undefined;

    const rows = await sql`
      UPDATE households
      SET
        plan_json = ${JSON.stringify(plan)}::jsonb,
        name = COALESCE(${householdName ?? null}, name),
        updated_at = NOW()
      WHERE id = ${householdId}
      RETURNING plan_json
    `;
    return rows.length > 0
      ? parseJsonObject<Record<string, unknown>>(rows[0].plan_json, plan)
      : plan;
  }

  async addCheckin(input: {
    householdId: string;
    userId: string | null;
    authorName: string;
    status: string;
    note: string;
    latitude: number | null;
    longitude: number | null;
  }): Promise<SafetyCheckinRecord> {
    const sql = await ensureSchema();
    const rows = await sql`
      INSERT INTO safety_checkins (
        household_id, user_id, author_name, status, note, latitude, longitude
      ) VALUES (
        ${input.householdId},
        ${input.userId},
        ${input.authorName},
        ${input.status},
        ${input.note},
        ${input.latitude},
        ${input.longitude}
      )
      RETURNING *
    `;
    return mapCheckinRow(rows[0]);
  }

  async getCheckins(householdId: string, limit = 20): Promise<SafetyCheckinRecord[]> {
    const sql = await ensureSchema();
    const rows = await sql`
      SELECT * FROM safety_checkins
      WHERE household_id = ${householdId}
      ORDER BY created_at DESC
      LIMIT ${limit}
    `;
    return rows.map(mapCheckinRow);
  }

  async getShelters(householdId?: string | null): Promise<EvacuationCenterRecord[]> {
    const sql = await ensureSchema();
    const rows = householdId
      ? await sql`
          SELECT * FROM evacuation_centers
          WHERE is_official = TRUE OR created_by_household_id = ${householdId}
          ORDER BY is_official DESC, updated_at DESC
        `
      : await sql`
          SELECT * FROM evacuation_centers
          WHERE is_official = TRUE
          ORDER BY updated_at DESC
        `;
    return rows.map(mapShelterRow);
  }

  async addShelter(
    householdId: string | null,
    shelter: EvacuationCenterRecord,
  ): Promise<EvacuationCenterRecord> {
    const sql = await ensureSchema();
    const rows = await sql`
      INSERT INTO evacuation_centers (
        id, name, address, city, latitude, longitude,
        contact_person, contact_number, capacity_people, is_open, facilities,
        is_official, created_by_household_id, updated_at
      ) VALUES (
        ${shelter.id},
        ${shelter.name},
        ${shelter.address},
        ${shelter.city},
        ${shelter.latitude},
        ${shelter.longitude},
        ${shelter.contactPerson},
        ${shelter.contactNumber},
        ${shelter.capacityPeople},
        ${shelter.isOpen},
        ${shelter.facilities},
        ${Boolean(shelter.isOfficial)},
        ${householdId},
        NOW()
      )
      ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        address = EXCLUDED.address,
        city = EXCLUDED.city,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        contact_person = EXCLUDED.contact_person,
        contact_number = EXCLUDED.contact_number,
        capacity_people = EXCLUDED.capacity_people,
        is_open = EXCLUDED.is_open,
        facilities = EXCLUDED.facilities,
        updated_at = NOW()
      RETURNING *
    `;
    return mapShelterRow(rows[0]);
  }

  async updateShelterStatus(
    id: string,
    patch: { isOpen?: boolean; capacityPeople?: number },
  ): Promise<EvacuationCenterRecord | null> {
    const sql = await ensureSchema();
    const rows = await sql`
      UPDATE evacuation_centers
      SET
        is_open = COALESCE(${patch.isOpen ?? null}, is_open),
        capacity_people = COALESCE(${patch.capacityPeople ?? null}, capacity_people),
        updated_at = NOW()
      WHERE id = ${id}
      RETURNING *
    `;
    return rows.length > 0 ? mapShelterRow(rows[0]) : null;
  }

  async deleteShelter(id: string): Promise<boolean> {
    const sql = await ensureSchema();
    const rows = await sql`
      DELETE FROM evacuation_centers WHERE id = ${id} RETURNING id
    `;
    return rows.length > 0;
  }

  async getTelemetryCache(cacheKey: string): Promise<TelemetryCacheRecord | null> {
    const sql = await ensureSchema();
    const rows = await sql`
      SELECT * FROM telemetry_cache WHERE cache_key = ${cacheKey} LIMIT 1
    `;
    if (rows.length === 0) return null;
    const row = rows[0];
    return {
      cacheKey: String(row.cache_key),
      latitude: Number(row.latitude),
      longitude: Number(row.longitude),
      payload: parseJsonObject<Record<string, unknown>>(row.payload_json, {}),
      fetchedAt: toIso(row.fetched_at),
    };
  }

  async setTelemetryCache(
    cacheKey: string,
    latitude: number,
    longitude: number,
    payload: Record<string, unknown>,
  ): Promise<void> {
    const sql = await ensureSchema();
    await sql`
      INSERT INTO telemetry_cache (cache_key, latitude, longitude, payload_json, fetched_at)
      VALUES (${cacheKey}, ${latitude}, ${longitude}, ${JSON.stringify(payload)}::jsonb, NOW())
      ON CONFLICT (cache_key) DO UPDATE SET
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        payload_json = EXCLUDED.payload_json,
        fetched_at = NOW()
    `;
  }

  async createEvaluation(input: IsoEvaluationInput): Promise<IsoEvaluationRecord> {
    const sql = await ensureSchema();
    const rows = await sql`
      INSERT INTO iso_evaluations (
        household_id, respondent_label, platform,
        functionality_score, usability_score, reliability_score, effectiveness_score,
        readiness_percentage, raw_completion_percentage, comments
      ) VALUES (
        ${input.householdId},
        ${input.respondentLabel},
        ${input.platform},
        ${input.functionalityScore},
        ${input.usabilityScore},
        ${input.reliabilityScore},
        ${input.effectivenessScore},
        ${input.readinessPercentage},
        ${input.rawCompletionPercentage},
        ${input.comments}
      )
      RETURNING *
    `;
    return mapEvaluationRow(rows[0]);
  }

  async getEvaluations(): Promise<IsoEvaluationRecord[]> {
    const sql = await ensureSchema();
    const rows = await sql`
      SELECT * FROM iso_evaluations ORDER BY created_at DESC LIMIT 500
    `;
    return rows.map(mapEvaluationRow);
  }

  async getAdminOverview(): Promise<AdminOverviewData> {
    const sql = await ensureSchema();
    const [countRows, hhRows, checkinRows, shelterRows] = await Promise.all([
      sql`
        SELECT
          (SELECT COUNT(*)::int FROM households) AS households,
          (SELECT COUNT(*)::int FROM users) AS users,
          (SELECT COUNT(*)::int FROM evacuation_centers WHERE is_open = TRUE) AS open_shelters,
          (SELECT COUNT(*)::int FROM evacuation_centers) AS total_shelters,
          (SELECT COUNT(*)::int FROM safety_checkins) AS checkins_total,
          (SELECT COUNT(*)::int FROM safety_checkins WHERE UPPER(status) LIKE '%ASSIST%' OR UPPER(status) LIKE '%HELP%') AS checkins_needing_help,
          (SELECT COUNT(*)::int FROM iso_evaluations) AS evaluations_total
      `,
      sql`
        SELECT
          h.id,
          h.name,
          h.invite_code,
          h.profile_json,
          h.updated_at,
          COALESCE(k.item_count, 0)::int AS item_count,
          COALESCE(k.packed_count, 0)::int AS packed_count
        FROM households h
        LEFT JOIN (
          SELECT
            household_id,
            COUNT(*)::int AS item_count,
            COUNT(*) FILTER (WHERE is_packed = TRUE OR quantity >= target_quantity)::int AS packed_count
          FROM kit_items
          WHERE deleted = FALSE
          GROUP BY household_id
        ) k ON k.household_id = h.id
        ORDER BY h.updated_at DESC
        LIMIT 50
      `,
      sql`
        SELECT
          c.*,
          COALESCE(h.name, 'Household') AS household_name
        FROM safety_checkins c
        LEFT JOIN households h ON h.id = c.household_id
        ORDER BY c.created_at DESC
        LIMIT 50
      `,
      sql`
        SELECT * FROM evacuation_centers
        ORDER BY is_official DESC, city ASC, name ASC
      `,
    ]);

    const c = countRows[0] ?? {};
    const households: AdminHouseholdSummary[] = hhRows.map((row) => {
      const profile = parseJsonObject<HouseholdProfileData>(
        row.profile_json,
        DEFAULT_HOUSEHOLD_PROFILE,
      );
      const memberCount =
        (Number(profile.adults) || 0) +
        (Number(profile.children) || 0) +
        (Number(profile.infants) || 0) +
        (Number(profile.seniors) || 0);
      const itemCount = Number(row.item_count ?? 0);
      const packedCount = Number(row.packed_count ?? 0);
      const readinessPct =
        itemCount > 0 ? Number(((packedCount / itemCount) * 100).toFixed(1)) : 0;
      return {
        id: String(row.id),
        name: String(row.name ?? 'My Household'),
        inviteCode: String(row.invite_code ?? ''),
        memberCount: Math.max(1, memberCount),
        itemCount,
        packedCount,
        readinessPct,
        updatedAt: toIso(row.updated_at),
      };
    });

    const recentCheckins: AdminCheckinItem[] = checkinRows.map((row) => ({
      ...mapCheckinRow(row),
      householdName: String(row.household_name ?? 'Household'),
    }));

    return {
      counts: {
        households: Number(c.households ?? 0),
        users: Number(c.users ?? 0),
        openShelters: Number(c.open_shelters ?? 0),
        totalShelters: Number(c.total_shelters ?? 0),
        checkinsTotal: Number(c.checkins_total ?? 0),
        checkinsNeedingHelp: Number(c.checkins_needing_help ?? 0),
        evaluationsTotal: Number(c.evaluations_total ?? 0),
      },
      households,
      recentCheckins,
      shelters: shelterRows.map(mapShelterRow),
    };
  }
}

export class InMemoryStore implements DataStore {
  private households = new Map<string, HouseholdRecord>();
  private users = new Map<string, UserRecord>();
  private kitByHousehold = new Map<string, Map<string, KitItemRecord>>();
  private checkinsByHousehold = new Map<string, SafetyCheckinRecord[]>();
  private shelters = new Map<string, EvacuationCenterRecord>();
  private telemetry = new Map<string, TelemetryCacheRecord>();
  private evaluations: IsoEvaluationRecord[] = [];

  constructor() {
    const seeds: EvacuationCenterRecord[] = [
      {
        id: 'manila_rizal_memorial',
        name: 'Rizal Memorial Sports Complex (Official City Shelter)',
        address: 'Pablo Ocampo Sr. St. (Vito Cruz), Malate, Manila',
        city: 'Manila',
        latitude: 14.5633,
        longitude: 120.9922,
        contactPerson: 'Manila DRRMO Operations Center',
        contactNumber: '(02) 8527-5174',
        capacityPeople: 3000,
        isOpen: true,
        facilities: 'Large Indoor Arena, Medical Staging Area, Relief Distribution Hub',
        isOfficial: true,
      },
      {
        id: 'eac_campus_reference',
        name: 'Emilio Aguinaldo College (Campus Assembly Reference)',
        address: '1113-1117 San Marcelino St, Paco, Manila',
        city: 'Manila',
        latitude: 14.5822,
        longitude: 120.9882,
        contactPerson: 'Manila DRRMO Dispatch',
        contactNumber: '(02) 8527-5174',
        capacityPeople: 1000,
        isOpen: true,
        facilities: 'Campus Open Grounds, Verify active shelter status with LGU/Admin',
        isOfficial: true,
      },
    ];
    for (const s of seeds) this.shelters.set(s.id, s);
  }

  async ping(): Promise<boolean> {
    return true;
  }

  async getUserByEmail(email: string): Promise<UserRecord | null> {
    const target = email.trim().toLowerCase();
    for (const u of this.users.values()) {
      if (u.email.toLowerCase() === target) return u;
    }
    return null;
  }

  async getUserById(id: string): Promise<UserRecord | null> {
    return this.users.get(id) ?? null;
  }

  async createUser(input: {
    email: string;
    passwordHash: string;
    fullName: string;
    role: UserRole;
    householdId: string;
  }): Promise<UserRecord> {
    const user: UserRecord = {
      id: randomUUID(),
      email: input.email.trim().toLowerCase(),
      passwordHash: input.passwordHash,
      fullName: input.fullName.trim(),
      role: input.role,
      householdId: input.householdId,
      createdAt: new Date().toISOString(),
    };
    this.users.set(user.id, user);
    return user;
  }

  async updateUserHousehold(userId: string, householdId: string): Promise<void> {
    const user = this.users.get(userId);
    if (user) {
      user.householdId = householdId;
    }
  }

  async createHousehold(name: string, inviteCode: string): Promise<HouseholdRecord> {
    const now = new Date().toISOString();
    const household: HouseholdRecord = {
      id: randomUUID(),
      name: name.trim() || 'My Household',
      inviteCode: inviteCode.toUpperCase(),
      profile: { ...DEFAULT_HOUSEHOLD_PROFILE },
      expiryAlertDays: 30,
      plan: { householdName: name.trim() || 'My Household' },
      createdAt: now,
      updatedAt: now,
    };
    this.households.set(household.id, household);
    return household;
  }

  async getHouseholdById(id: string): Promise<HouseholdRecord | null> {
    return this.households.get(id) ?? null;
  }

  async getHouseholdByInviteCode(code: string): Promise<HouseholdRecord | null> {
    const upper = code.trim().toUpperCase();
    for (const h of this.households.values()) {
      if (h.inviteCode.toUpperCase() === upper) return h;
    }
    return null;
  }

  async getSyncBundle(householdId: string): Promise<SyncBundle | null> {
    const household = this.households.get(householdId);
    if (!household) return null;
    const itemsMap = this.kitByHousehold.get(householdId) ?? new Map();
    const kitItems = [...itemsMap.values()].filter((i) => !i.deleted);
    return {
      household,
      kitItems,
      checkins: await this.getCheckins(householdId, 20),
      shelters: await this.getShelters(householdId),
    };
  }

  async upsertKitBatch(
    householdId: string,
    input: {
      items?: KitItemRecord[];
      profile?: HouseholdProfileData;
      expiryAlertDays?: number;
    },
  ): Promise<KitItemRecord[]> {
    const household = this.households.get(householdId);
    if (household) {
      if (input.profile) household.profile = input.profile;
      if (input.expiryAlertDays !== undefined) {
        household.expiryAlertDays = input.expiryAlertDays;
      }
      household.updatedAt = new Date().toISOString();
    }

    const map = this.kitByHousehold.get(householdId) ?? new Map<string, KitItemRecord>();
    this.kitByHousehold.set(householdId, map);

    for (const item of input.items ?? []) {
      const existing = map.get(item.id);
      if (
        !existing ||
        new Date(item.lastUpdated).getTime() >= new Date(existing.lastUpdated).getTime()
      ) {
        map.set(item.id, { ...item });
      }
    }
    return [...map.values()].filter((i) => !i.deleted);
  }

  async markKitItemDeleted(
    householdId: string,
    itemId: string,
    deletedAtIso: string,
  ): Promise<void> {
    const map = this.kitByHousehold.get(householdId);
    const existing = map?.get(itemId);
    if (existing && new Date(existing.lastUpdated).getTime() <= new Date(deletedAtIso).getTime()) {
      existing.deleted = true;
      existing.lastUpdated = deletedAtIso;
    }
  }

  async updateEmergencyPlan(
    householdId: string,
    plan: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    const household = this.households.get(householdId);
    if (household) {
      household.plan = plan;
      if (typeof plan.householdName === 'string' && plan.householdName.trim()) {
        household.name = plan.householdName.trim();
      }
      household.updatedAt = new Date().toISOString();
    }
    return plan;
  }

  async addCheckin(input: {
    householdId: string;
    userId: string | null;
    authorName: string;
    status: string;
    note: string;
    latitude: number | null;
    longitude: number | null;
  }): Promise<SafetyCheckinRecord> {
    const rec: SafetyCheckinRecord = {
      id: randomUUID(),
      householdId: input.householdId,
      userId: input.userId,
      authorName: input.authorName,
      status: input.status,
      note: input.note,
      latitude: input.latitude,
      longitude: input.longitude,
      timestamp: new Date().toISOString(),
    };
    const list = this.checkinsByHousehold.get(input.householdId) ?? [];
    list.unshift(rec);
    this.checkinsByHousehold.set(input.householdId, list);
    return rec;
  }

  async getCheckins(householdId: string, limit = 20): Promise<SafetyCheckinRecord[]> {
    return (this.checkinsByHousehold.get(householdId) ?? []).slice(0, limit);
  }

  async getShelters(householdId?: string | null): Promise<EvacuationCenterRecord[]> {
    return [...this.shelters.values()].filter(
      (s) => s.isOfficial || (householdId && s.createdByHouseholdId === householdId),
    );
  }

  async addShelter(
    householdId: string | null,
    shelter: EvacuationCenterRecord,
  ): Promise<EvacuationCenterRecord> {
    const saved: EvacuationCenterRecord = {
      ...shelter,
      createdByHouseholdId: householdId,
      updatedAt: new Date().toISOString(),
    };
    this.shelters.set(saved.id, saved);
    return saved;
  }

  async updateShelterStatus(
    id: string,
    patch: { isOpen?: boolean; capacityPeople?: number },
  ): Promise<EvacuationCenterRecord | null> {
    const existing = this.shelters.get(id);
    if (!existing) return null;
    if (patch.isOpen !== undefined) existing.isOpen = patch.isOpen;
    if (patch.capacityPeople !== undefined) existing.capacityPeople = patch.capacityPeople;
    existing.updatedAt = new Date().toISOString();
    return existing;
  }

  async deleteShelter(id: string): Promise<boolean> {
    return this.shelters.delete(id);
  }

  async getTelemetryCache(cacheKey: string): Promise<TelemetryCacheRecord | null> {
    return this.telemetry.get(cacheKey) ?? null;
  }

  async setTelemetryCache(
    cacheKey: string,
    latitude: number,
    longitude: number,
    payload: Record<string, unknown>,
  ): Promise<void> {
    this.telemetry.set(cacheKey, {
      cacheKey,
      latitude,
      longitude,
      payload,
      fetchedAt: new Date().toISOString(),
    });
  }

  async createEvaluation(input: IsoEvaluationInput): Promise<IsoEvaluationRecord> {
    const rec: IsoEvaluationRecord = {
      ...input,
      id: randomUUID(),
      createdAt: new Date().toISOString(),
    };
    this.evaluations.unshift(rec);
    return rec;
  }

  async getEvaluations(): Promise<IsoEvaluationRecord[]> {
    return [...this.evaluations];
  }

  async getAdminOverview(): Promise<AdminOverviewData> {
    const allShelters = [...this.shelters.values()];
    const openShelters = allShelters.filter((s) => s.isOpen).length;

    const allCheckins: AdminCheckinItem[] = [];
    for (const [hhId, list] of this.checkinsByHousehold.entries()) {
      const hhName = this.households.get(hhId)?.name ?? 'Household';
      for (const c of list) {
        allCheckins.push({ ...c, householdName: hhName });
      }
    }
    allCheckins.sort((a, b) => b.timestamp.localeCompare(a.timestamp));

    const checkinsNeedingHelp = allCheckins.filter((c) => {
      const st = c.status.toUpperCase();
      return st.includes('ASSIST') || st.includes('HELP');
    }).length;

    const households: AdminHouseholdSummary[] = [...this.households.values()]
      .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))
      .slice(0, 50)
      .map((h) => {
        const itemsMap = this.kitByHousehold.get(h.id) ?? new Map<string, KitItemRecord>();
        const activeItems = [...itemsMap.values()].filter((i) => !i.deleted);
        const packedCount = activeItems.filter(
          (i) => i.isPacked || i.quantity >= i.targetQuantity,
        ).length;
        const itemCount = activeItems.length;
        const readinessPct =
          itemCount > 0 ? Number(((packedCount / itemCount) * 100).toFixed(1)) : 0;
        const p = h.profile;
        const memberCount = Math.max(
          1,
          (p.adults || 0) + (p.children || 0) + (p.infants || 0) + (p.seniors || 0),
        );
        return {
          id: h.id,
          name: h.name,
          inviteCode: h.inviteCode,
          memberCount,
          itemCount,
          packedCount,
          readinessPct,
          updatedAt: h.updatedAt,
        };
      });

    return {
      counts: {
        households: this.households.size,
        users: this.users.size,
        openShelters,
        totalShelters: allShelters.length,
        checkinsTotal: allCheckins.length,
        checkinsNeedingHelp,
        evaluationsTotal: this.evaluations.length,
      },
      households,
      recentCheckins: allCheckins.slice(0, 50),
      shelters: allShelters,
    };
  }
}

let cachedPgStore: PostgresStore | null = null;
export function getPostgresStore(): PostgresStore {
  if (!cachedPgStore) cachedPgStore = new PostgresStore();
  return cachedPgStore;
}
