import { randomUUID } from 'node:crypto';
import { ensureSchema } from './db.js';
import type {
  AdminCheckinItem,
  AdminHouseholdSummary,
  AdminOverviewData,
  AdvisorySeverity,
  DrrmAdvisoryRecord,
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
  updateUserPassword(userId: string, passwordHash: string): Promise<void>;
  setPasswordResetCode(
    email: string,
    codeHash: string,
    expiresAtIso: string,
  ): Promise<{ id: string; email: string; fullName: string; role: UserRole } | null>;
  deleteUserAccount(
    userId: string,
  ): Promise<{ deleted: boolean; householdDeleted: boolean }>;

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
  acknowledgeCheckin(
    id: string,
    acknowledgedBy: string,
    acknowledged: boolean,
  ): Promise<SafetyCheckinRecord | null>;

  getShelters(householdId?: string | null): Promise<EvacuationCenterRecord[]>;
  addShelter(
    householdId: string | null,
    shelter: EvacuationCenterRecord,
  ): Promise<EvacuationCenterRecord | null>;
  updateShelterStatus(
    id: string,
    patch: {
      isOpen?: boolean;
      capacityPeople?: number;
      name?: string;
      address?: string;
      city?: string;
      latitude?: number;
      longitude?: number;
      contactPerson?: string;
      contactNumber?: string;
      facilities?: string;
    },
  ): Promise<EvacuationCenterRecord | null>;
  deleteShelter(id: string): Promise<boolean>;
  deleteHouseholdShelter(householdId: string, id: string): Promise<boolean>;

  getAdvisories(activeOnly?: boolean): Promise<DrrmAdvisoryRecord[]>;
  createAdvisory(input: {
    title: string;
    message: string;
    severity: AdvisorySeverity;
    area: string;
    authorName: string;
  }): Promise<DrrmAdvisoryRecord>;
  updateAdvisory(
    id: string,
    patch: {
      isActive?: boolean;
      title?: string;
      message?: string;
      severity?: AdvisorySeverity;
      area?: string;
    },
  ): Promise<DrrmAdvisoryRecord | null>;
  deleteAdvisory(id: string): Promise<boolean>;

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

function parseJsonArray<T>(val: unknown): T[] {
  if (Array.isArray(val)) return val as T[];
  if (typeof val === 'string' && val.trim().length > 0) {
    try {
      const parsed = JSON.parse(val);
      return Array.isArray(parsed) ? (parsed as T[]) : [];
    } catch {
      return [];
    }
  }
  return [];
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
    passwordResetCodeHash: row.password_reset_code_hash
      ? String(row.password_reset_code_hash)
      : null,
    passwordResetExpiresAt: row.password_reset_expires_at
      ? toIso(row.password_reset_expires_at)
      : null,
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
    acknowledgedAt: row.acknowledged_at ? toIso(row.acknowledged_at) : null,
    acknowledgedBy: row.acknowledged_by ? String(row.acknowledged_by) : null,
  };
}

function mapAdvisoryRow(row: Record<string, unknown>): DrrmAdvisoryRecord {
  const sev = String(row.severity ?? 'warning').toLowerCase();
  return {
    id: String(row.id),
    title: String(row.title ?? ''),
    message: String(row.message ?? ''),
    severity: sev === 'critical' || sev === 'info' ? sev : 'warning',
    area: String(row.area ?? 'City of Manila'),
    authorName: String(row.author_name ?? 'DRRM Admin'),
    isActive: Boolean(row.is_active ?? true),
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
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

  async updateUserPassword(userId: string, passwordHash: string): Promise<void> {
    const sql = await ensureSchema();
    await sql`
      UPDATE users
      SET password_hash = ${passwordHash},
          password_reset_code_hash = NULL,
          password_reset_expires_at = NULL
      WHERE id = ${userId}
    `;
  }

  async setPasswordResetCode(
    email: string,
    codeHash: string,
    expiresAtIso: string,
  ): Promise<{ id: string; email: string; fullName: string; role: UserRole } | null> {
    const sql = await ensureSchema();
    const rows = await sql`
      UPDATE users
      SET password_reset_code_hash = ${codeHash},
          password_reset_expires_at = ${expiresAtIso}
      WHERE LOWER(email) = LOWER(${email.trim()})
      RETURNING id, email, full_name, role
    `;
    if (rows.length === 0) return null;
    const r = rows[0];
    return {
      id: String(r.id),
      email: String(r.email),
      fullName: String(r.full_name),
      role: r.role === 'admin' ? 'admin' : 'household',
    };
  }

  async deleteUserAccount(
    userId: string,
  ): Promise<{ deleted: boolean; householdDeleted: boolean }> {
    const sql = await ensureSchema();
    const deletedUsers = await sql`
      DELETE FROM users
      WHERE id = ${userId}
      RETURNING household_id
    `;
    if (deletedUsers.length === 0) {
      return { deleted: false, householdDeleted: false };
    }

    const householdId = deletedUsers[0].household_id
      ? String(deletedUsers[0].household_id)
      : null;
    let householdDeleted = false;

    if (householdId) {
      const remaining = await sql`
        SELECT COUNT(*)::int AS cnt FROM users WHERE household_id = ${householdId}
      `;
      if (Number(remaining[0]?.cnt ?? 0) === 0) {
        await sql`
          DELETE FROM evacuation_centers
          WHERE is_official = FALSE AND created_by_household_id = ${householdId}
        `;
        await sql`DELETE FROM households WHERE id = ${householdId}`;
        householdDeleted = true;
      }
    }

    return { deleted: true, householdDeleted };
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

    const kitRows = await sql`
      SELECT * FROM kit_items
      WHERE household_id = ${householdId} AND deleted = FALSE
      ORDER BY category_index ASC, name ASC
    `;
    const checkins = await this.getCheckins(householdId, 20);
    const shelters = await this.getShelters(householdId);

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

  async acknowledgeCheckin(
    id: string,
    acknowledgedBy: string,
    acknowledged: boolean,
  ): Promise<SafetyCheckinRecord | null> {
    const sql = await ensureSchema();
    const rows = acknowledged
      ? await sql`
          UPDATE safety_checkins
          SET acknowledged_at = NOW(), acknowledged_by = ${acknowledgedBy}
          WHERE id = ${id}
          RETURNING *
        `
      : await sql`
          UPDATE safety_checkins
          SET acknowledged_at = NULL, acknowledged_by = NULL
          WHERE id = ${id}
          RETURNING *
        `;
    return rows.length > 0 ? mapCheckinRow(rows[0]) : null;
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
  ): Promise<EvacuationCenterRecord | null> {
    const sql = await ensureSchema();
    const rows =
      householdId !== null
        ? await sql`
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
              FALSE,
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
            WHERE evacuation_centers.is_official = FALSE
              AND evacuation_centers.created_by_household_id = ${householdId}
            RETURNING *
          `
        : await sql`
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
              NULL,
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
              is_official = EXCLUDED.is_official,
              updated_at = NOW()
            RETURNING *
          `;
    return rows.length > 0 ? mapShelterRow(rows[0]) : null;
  }

  async updateShelterStatus(
    id: string,
    patch: {
      isOpen?: boolean;
      capacityPeople?: number;
      name?: string;
      address?: string;
      city?: string;
      latitude?: number;
      longitude?: number;
      contactPerson?: string;
      contactNumber?: string;
      facilities?: string;
    },
  ): Promise<EvacuationCenterRecord | null> {
    const sql = await ensureSchema();
    const rows = await sql`
      UPDATE evacuation_centers
      SET
        is_open = COALESCE(${patch.isOpen ?? null}, is_open),
        capacity_people = COALESCE(${patch.capacityPeople ?? null}, capacity_people),
        name = COALESCE(${patch.name ?? null}, name),
        address = COALESCE(${patch.address ?? null}, address),
        city = COALESCE(${patch.city ?? null}, city),
        latitude = COALESCE(${patch.latitude ?? null}, latitude),
        longitude = COALESCE(${patch.longitude ?? null}, longitude),
        contact_person = COALESCE(${patch.contactPerson ?? null}, contact_person),
        contact_number = COALESCE(${patch.contactNumber ?? null}, contact_number),
        facilities = COALESCE(${patch.facilities ?? null}, facilities),
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

  async deleteHouseholdShelter(householdId: string, id: string): Promise<boolean> {
    const sql = await ensureSchema();
    const rows = await sql`
      DELETE FROM evacuation_centers
      WHERE id = ${id}
        AND is_official = FALSE
        AND created_by_household_id = ${householdId}
      RETURNING id
    `;
    return rows.length > 0;
  }

  async getAdvisories(activeOnly = false): Promise<DrrmAdvisoryRecord[]> {
    const sql = await ensureSchema();
    const rows = activeOnly
      ? await sql`
          SELECT * FROM drrm_advisories
          WHERE is_active = TRUE
          ORDER BY created_at DESC
          LIMIT 20
        `
      : await sql`
          SELECT * FROM drrm_advisories
          ORDER BY is_active DESC, created_at DESC
          LIMIT 50
        `;
    return rows.map(mapAdvisoryRow);
  }

  async createAdvisory(input: {
    title: string;
    message: string;
    severity: AdvisorySeverity;
    area: string;
    authorName: string;
  }): Promise<DrrmAdvisoryRecord> {
    const sql = await ensureSchema();
    const rows = await sql`
      INSERT INTO drrm_advisories (title, message, severity, area, author_name, is_active)
      VALUES (${input.title}, ${input.message}, ${input.severity}, ${input.area}, ${input.authorName}, TRUE)
      RETURNING *
    `;
    return mapAdvisoryRow(rows[0]);
  }

  async updateAdvisory(
    id: string,
    patch: {
      isActive?: boolean;
      title?: string;
      message?: string;
      severity?: AdvisorySeverity;
      area?: string;
    },
  ): Promise<DrrmAdvisoryRecord | null> {
    const sql = await ensureSchema();
    const rows = await sql`
      UPDATE drrm_advisories
      SET
        is_active = COALESCE(${patch.isActive ?? null}, is_active),
        title = COALESCE(${patch.title ?? null}, title),
        message = COALESCE(${patch.message ?? null}, message),
        severity = COALESCE(${patch.severity ?? null}, severity),
        area = COALESCE(${patch.area ?? null}, area),
        updated_at = NOW()
      WHERE id = ${id}
      RETURNING *
    `;
    return rows.length > 0 ? mapAdvisoryRow(rows[0]) : null;
  }

  async deleteAdvisory(id: string): Promise<boolean> {
    const sql = await ensureSchema();
    const rows = await sql`
      DELETE FROM drrm_advisories WHERE id = ${id} RETURNING id
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
    const rows = await sql`
      SELECT
        (SELECT COUNT(*)::int FROM households h WHERE EXISTS (SELECT 1 FROM users u WHERE u.household_id = h.id AND u.role = 'household')) AS households,
        (SELECT COUNT(*)::int FROM users WHERE role = 'household') AS users,
        (SELECT COUNT(*)::int FROM evacuation_centers WHERE is_open = TRUE AND (is_official = TRUE OR created_by_household_id IS NOT NULL)) AS open_shelters,
        (SELECT COUNT(*)::int FROM evacuation_centers WHERE is_official = TRUE OR created_by_household_id IS NOT NULL) AS total_shelters,
        (SELECT COUNT(*)::int FROM safety_checkins c LEFT JOIN users u ON u.id = c.user_id WHERE COALESCE(u.role, 'household') = 'household') AS checkins_total,
        (SELECT COUNT(*)::int FROM safety_checkins c LEFT JOIN users u ON u.id = c.user_id WHERE COALESCE(u.role, 'household') = 'household' AND c.acknowledged_at IS NULL AND (UPPER(c.status) LIKE '%ASSIST%' OR UPPER(c.status) LIKE '%HELP%')) AS checkins_needing_help,
        (SELECT COUNT(*)::int FROM iso_evaluations) AS evaluations_total,
        (SELECT COUNT(*)::int FROM drrm_advisories WHERE is_active = TRUE) AS active_advisories,
        COALESCE((
          SELECT json_agg(row_to_json(t))
          FROM (
            SELECT
              h.id,
              h.name,
              h.invite_code,
              h.profile_json,
              h.plan_json,
              h.updated_at,
              COALESCE(u_cnt.account_count, 0)::int AS account_count,
              COALESCE(u_cnt.member_emails, '[]'::json) AS member_emails,
              COALESCE(k.item_count, 0)::int AS item_count,
              COALESCE(k.packed_count, 0)::int AS packed_count,
              COALESCE(k.total_weight, 0)::double precision AS total_weight,
              COALESCE(k.ready_weight, 0)::double precision AS ready_weight
            FROM households h
            INNER JOIN (
              SELECT
                household_id,
                COUNT(*)::int AS account_count,
                json_agg(email ORDER BY created_at ASC) AS member_emails
              FROM users
              WHERE role = 'household'
              GROUP BY household_id
            ) u_cnt ON u_cnt.household_id = h.id
            LEFT JOIN (
              SELECT
                household_id,
                COUNT(*)::int AS item_count,
                COUNT(*) FILTER (
                  WHERE is_packed = TRUE
                    AND quantity >= target_quantity
                    AND (expiration_date IS NULL OR expiration_date::date >= CURRENT_DATE)
                )::int AS packed_count,
                COALESCE(SUM(
                  CASE
                    WHEN category_index IN (0, 1) THEN 3.0
                    WHEN category_index IN (2, 3, 6) THEN 2.0
                    ELSE 1.0
                  END
                ), 0)::double precision AS total_weight,
                COALESCE(SUM(
                  CASE
                    WHEN expiration_date IS NOT NULL AND expiration_date::date < CURRENT_DATE THEN 0.0
                    WHEN is_packed = TRUE AND quantity >= target_quantity THEN (
                      CASE
                        WHEN category_index IN (0, 1) THEN 3.0
                        WHEN category_index IN (2, 3, 6) THEN 2.0
                        ELSE 1.0
                      END
                    )
                    WHEN quantity > 0 AND target_quantity > 0 THEN (
                      CASE
                        WHEN category_index IN (0, 1) THEN 3.0
                        WHEN category_index IN (2, 3, 6) THEN 2.0
                        ELSE 1.0
                      END
                    ) * LEAST(0.85, quantity::double precision / target_quantity::double precision)
                    ELSE 0.0
                  END
                ), 0)::double precision AS ready_weight
              FROM kit_items
              WHERE deleted = FALSE
              GROUP BY household_id
            ) k ON k.household_id = h.id
            ORDER BY h.updated_at DESC
            LIMIT 50
          ) t
        ), '[]'::json) AS households_json,
        COALESCE((
          SELECT json_agg(row_to_json(c_row))
          FROM (
            SELECT c.*, COALESCE(h.name, 'Household') AS household_name
            FROM safety_checkins c
            LEFT JOIN households h ON h.id = c.household_id
            LEFT JOIN users u ON u.id = c.user_id
            WHERE COALESCE(u.role, 'household') = 'household'
            ORDER BY c.created_at DESC
            LIMIT 50
          ) c_row
        ), '[]'::json) AS checkins_json,
        COALESCE((
          SELECT json_agg(row_to_json(s_row))
          FROM (
            SELECT * FROM evacuation_centers
            WHERE is_official = TRUE OR created_by_household_id IS NOT NULL
            ORDER BY is_official DESC, city ASC, name ASC
          ) s_row
        ), '[]'::json) AS shelters_json,
        COALESCE((
          SELECT json_agg(row_to_json(a_row))
          FROM (
            SELECT * FROM drrm_advisories
            ORDER BY is_active DESC, created_at DESC
            LIMIT 50
          ) a_row
        ), '[]'::json) AS advisories_json
    `;

    const c = (rows[0] ?? {}) as Record<string, unknown>;
    const hhRows = parseJsonArray<Record<string, unknown>>(c.households_json);
    const checkinRows = parseJsonArray<Record<string, unknown>>(c.checkins_json);
    const shelterRows = parseJsonArray<Record<string, unknown>>(c.shelters_json);
    const advisoryRows = parseJsonArray<Record<string, unknown>>(c.advisories_json);

    const households: AdminHouseholdSummary[] = hhRows.map((row) => {
      const profile = parseJsonObject<HouseholdProfileData>(
        row.profile_json,
        DEFAULT_HOUSEHOLD_PROFILE,
      );
      const plan = parseJsonObject<Record<string, unknown>>(row.plan_json, {});
      const memberCount =
        (Number(profile.adults) || 0) +
        (Number(profile.children) || 0) +
        (Number(profile.infants) || 0) +
        (Number(profile.seniors) || 0);
      const itemCount = Number(row.item_count ?? 0);
      const packedCount = Number(row.packed_count ?? 0);
      const totalWeight = Number(row.total_weight ?? 0);
      const readyWeight = Number(row.ready_weight ?? 0);
      const readinessPct =
        totalWeight > 0
          ? Number(((readyWeight / totalWeight) * 100).toFixed(1))
          : 0;
      return {
        id: String(row.id),
        name: String(row.name ?? 'My Household'),
        inviteCode: String(row.invite_code ?? ''),
        accountCount: Number(row.account_count ?? 1),
        memberCount: Math.max(1, memberCount),
        itemCount,
        packedCount,
        readinessPct,
        updatedAt: toIso(row.updated_at),
        profile,
        primaryMeetingPoint: String(plan.primaryMeetingPoint ?? ''),
        secondaryMeetingPoint: String(plan.secondaryMeetingPoint ?? ''),
        memberEmails: parseJsonArray<string>(row.member_emails).map(String),
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
        activeAdvisories: Number(c.active_advisories ?? 0),
      },
      households,
      recentCheckins,
      shelters: shelterRows.map(mapShelterRow),
      advisories: advisoryRows.map(mapAdvisoryRow),
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
  private advisories = new Map<string, DrrmAdvisoryRecord>();

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
        id: 'manila_paco_arena',
        name: 'Paco Arena & Sports Complex (City Evacuation Center)',
        address: 'Paz St. cor. Perdigon St., Paco, Manila',
        city: 'Manila',
        latitude: 14.5794,
        longitude: 120.9936,
        contactPerson: 'Manila DRRMO Dispatch',
        contactNumber: '(02) 8527-5174',
        capacityPeople: 1000,
        isOpen: true,
        facilities: 'Multi-Purpose Covered Arena, Community Assembly & Relief Staging',
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

  async updateUserPassword(userId: string, passwordHash: string): Promise<void> {
    const user = this.users.get(userId);
    if (user) {
      user.passwordHash = passwordHash;
      user.passwordResetCodeHash = null;
      user.passwordResetExpiresAt = null;
    }
  }

  async setPasswordResetCode(
    email: string,
    codeHash: string,
    expiresAtIso: string,
  ): Promise<{ id: string; email: string; fullName: string; role: UserRole } | null> {
    const user = await this.getUserByEmail(email);
    if (!user) return null;
    user.passwordResetCodeHash = codeHash;
    user.passwordResetExpiresAt = expiresAtIso;
    return {
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      role: user.role,
    };
  }

  async deleteUserAccount(
    userId: string,
  ): Promise<{ deleted: boolean; householdDeleted: boolean }> {
    const user = this.users.get(userId);
    if (!user) return { deleted: false, householdDeleted: false };
    this.users.delete(userId);

    const hhId = user.householdId;
    let householdDeleted = false;
    if (hhId) {
      const hasOthers = [...this.users.values()].some(
        (u) => u.householdId === hhId,
      );
      if (!hasOthers) {
        this.households.delete(hhId);
        this.kitByHousehold.delete(hhId);
        this.checkinsByHousehold.delete(hhId);
        for (const [sid, shelter] of this.shelters.entries()) {
          if (!shelter.isOfficial && shelter.createdByHouseholdId === hhId) {
            this.shelters.delete(sid);
          }
        }
        householdDeleted = true;
      }
    }
    return { deleted: true, householdDeleted };
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
      acknowledgedAt: null,
      acknowledgedBy: null,
    };
    const list = this.checkinsByHousehold.get(input.householdId) ?? [];
    list.unshift(rec);
    this.checkinsByHousehold.set(input.householdId, list);
    return rec;
  }

  async getCheckins(householdId: string, limit = 20): Promise<SafetyCheckinRecord[]> {
    return (this.checkinsByHousehold.get(householdId) ?? []).slice(0, limit);
  }

  async acknowledgeCheckin(
    id: string,
    acknowledgedBy: string,
    acknowledged: boolean,
  ): Promise<SafetyCheckinRecord | null> {
    for (const list of this.checkinsByHousehold.values()) {
      const found = list.find((c) => c.id === id);
      if (found) {
        found.acknowledgedAt = acknowledged ? new Date().toISOString() : null;
        found.acknowledgedBy = acknowledged ? acknowledgedBy : null;
        return found;
      }
    }
    return null;
  }

  async getShelters(householdId?: string | null): Promise<EvacuationCenterRecord[]> {
    return [...this.shelters.values()].filter(
      (s) => s.isOfficial || (householdId && s.createdByHouseholdId === householdId),
    );
  }

  async addShelter(
    householdId: string | null,
    shelter: EvacuationCenterRecord,
  ): Promise<EvacuationCenterRecord | null> {
    const existing = this.shelters.get(shelter.id);
    if (
      householdId !== null &&
      existing &&
      (existing.isOfficial || existing.createdByHouseholdId !== householdId)
    ) {
      return null;
    }
    const saved: EvacuationCenterRecord = {
      ...shelter,
      isOfficial: householdId === null ? Boolean(shelter.isOfficial) : false,
      createdByHouseholdId: householdId,
      updatedAt: new Date().toISOString(),
    };
    this.shelters.set(saved.id, saved);
    return saved;
  }

  async updateShelterStatus(
    id: string,
    patch: {
      isOpen?: boolean;
      capacityPeople?: number;
      name?: string;
      address?: string;
      city?: string;
      latitude?: number;
      longitude?: number;
      contactPerson?: string;
      contactNumber?: string;
      facilities?: string;
    },
  ): Promise<EvacuationCenterRecord | null> {
    const existing = this.shelters.get(id);
    if (!existing) return null;
    if (patch.isOpen !== undefined) existing.isOpen = patch.isOpen;
    if (patch.capacityPeople !== undefined) existing.capacityPeople = patch.capacityPeople;
    if (patch.name !== undefined) existing.name = patch.name;
    if (patch.address !== undefined) existing.address = patch.address;
    if (patch.city !== undefined) existing.city = patch.city;
    if (patch.latitude !== undefined) existing.latitude = patch.latitude;
    if (patch.longitude !== undefined) existing.longitude = patch.longitude;
    if (patch.contactPerson !== undefined) existing.contactPerson = patch.contactPerson;
    if (patch.contactNumber !== undefined) existing.contactNumber = patch.contactNumber;
    if (patch.facilities !== undefined) existing.facilities = patch.facilities;
    existing.updatedAt = new Date().toISOString();
    return existing;
  }

  async deleteShelter(id: string): Promise<boolean> {
    return this.shelters.delete(id);
  }

  async deleteHouseholdShelter(householdId: string, id: string): Promise<boolean> {
    const existing = this.shelters.get(id);
    if (!existing || existing.isOfficial || existing.createdByHouseholdId !== householdId) {
      return false;
    }
    return this.shelters.delete(id);
  }

  async getAdvisories(activeOnly = false): Promise<DrrmAdvisoryRecord[]> {
    const list = [...this.advisories.values()]
      .filter((a) => !activeOnly || a.isActive)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    return list.slice(0, activeOnly ? 20 : 50);
  }

  async createAdvisory(input: {
    title: string;
    message: string;
    severity: AdvisorySeverity;
    area: string;
    authorName: string;
  }): Promise<DrrmAdvisoryRecord> {
    const now = new Date().toISOString();
    const rec: DrrmAdvisoryRecord = {
      id: randomUUID(),
      title: input.title,
      message: input.message,
      severity: input.severity,
      area: input.area,
      authorName: input.authorName,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    };
    this.advisories.set(rec.id, rec);
    return rec;
  }

  async updateAdvisory(
    id: string,
    patch: {
      isActive?: boolean;
      title?: string;
      message?: string;
      severity?: AdvisorySeverity;
      area?: string;
    },
  ): Promise<DrrmAdvisoryRecord | null> {
    const existing = this.advisories.get(id);
    if (!existing) return null;
    if (patch.isActive !== undefined) existing.isActive = patch.isActive;
    if (patch.title !== undefined) existing.title = patch.title;
    if (patch.message !== undefined) existing.message = patch.message;
    if (patch.severity !== undefined) existing.severity = patch.severity;
    if (patch.area !== undefined) existing.area = patch.area;
    existing.updatedAt = new Date().toISOString();
    return existing;
  }

  async deleteAdvisory(id: string): Promise<boolean> {
    return this.advisories.delete(id);
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
    const allAdvisories = await this.getAdvisories(false);
    const activeAdvisories = allAdvisories.filter((a) => a.isActive).length;

    const householdUsers = [...this.users.values()].filter(
      (u) => u.role === 'household',
    );
    const accountCountByHh = new Map<string, number>();
    for (const u of householdUsers) {
      accountCountByHh.set(
        u.householdId,
        (accountCountByHh.get(u.householdId) ?? 0) + 1,
      );
    }

    const allCheckins: AdminCheckinItem[] = [];
    for (const [hhId, list] of this.checkinsByHousehold.entries()) {
      const hhName = this.households.get(hhId)?.name ?? 'Household';
      for (const c of list) {
        const author = c.userId ? this.users.get(c.userId) : null;
        if (author && author.role === 'admin') continue;
        allCheckins.push({ ...c, householdName: hhName });
      }
    }
    allCheckins.sort((a, b) => b.timestamp.localeCompare(a.timestamp));

    const checkinsNeedingHelp = allCheckins.filter((c) => {
      if (c.acknowledgedAt) return false;
      const st = c.status.toUpperCase();
      return st.includes('ASSIST') || st.includes('HELP');
    }).length;

    const realHouseholds = [...this.households.values()].filter(
      (h) => (accountCountByHh.get(h.id) ?? 0) > 0,
    );

    const households: AdminHouseholdSummary[] = realHouseholds
      .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))
      .slice(0, 50)
      .map((h) => {
        const itemsMap = this.kitByHousehold.get(h.id) ?? new Map<string, KitItemRecord>();
        const activeItems = [...itemsMap.values()].filter((i) => !i.deleted);
        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);
        const isExpiredItem = (i: KitItemRecord) =>
          Boolean(i.expirationDate && new Date(i.expirationDate) < todayStart);
        const weightOf = (cat: number) =>
          cat === 0 || cat === 1 ? 3 : cat === 2 || cat === 3 || cat === 6 ? 2 : 1;

        let totalWeight = 0;
        let readyWeight = 0;
        let packedCount = 0;
        for (const i of activeItems) {
          const w = weightOf(i.category);
          totalWeight += w;
          if (!isExpiredItem(i)) {
            if (i.isPacked && i.quantity >= i.targetQuantity) {
              readyWeight += w;
              packedCount++;
            } else if (i.quantity > 0 && i.targetQuantity > 0) {
              readyWeight += w * Math.min(0.85, i.quantity / i.targetQuantity);
            }
          }
        }
        const itemCount = activeItems.length;
        const readinessPct =
          totalWeight > 0
            ? Number(((readyWeight / totalWeight) * 100).toFixed(1))
            : 0;
        const p = h.profile;
        const memberCount = Math.max(
          1,
          (p.adults || 0) + (p.children || 0) + (p.infants || 0) + (p.seniors || 0),
        );
        return {
          id: h.id,
          name: h.name,
          inviteCode: h.inviteCode,
          accountCount: accountCountByHh.get(h.id) ?? 1,
          memberCount,
          itemCount,
          packedCount,
          readinessPct,
          updatedAt: h.updatedAt,
          profile: p,
          primaryMeetingPoint: String(h.plan.primaryMeetingPoint ?? ''),
          secondaryMeetingPoint: String(h.plan.secondaryMeetingPoint ?? ''),
          memberEmails: householdUsers
            .filter((u) => u.householdId === h.id)
            .map((u) => u.email),
        };
      });

    return {
      counts: {
        households: realHouseholds.length,
        users: householdUsers.length,
        openShelters,
        totalShelters: allShelters.length,
        checkinsTotal: allCheckins.length,
        checkinsNeedingHelp,
        evaluationsTotal: this.evaluations.length,
        activeAdvisories,
      },
      households,
      recentCheckins: allCheckins.slice(0, 50),
      shelters: allShelters,
      advisories: allAdvisories,
    };
  }
}

let cachedPgStore: PostgresStore | null = null;
export function getPostgresStore(): PostgresStore {
  if (!cachedPgStore) cachedPgStore = new PostgresStore();
  return cachedPgStore;
}
