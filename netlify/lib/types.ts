export type UserRole = 'household' | 'admin';

export interface HouseholdProfileData {
  adults: number;
  children: number;
  infants: number;
  seniors: number;
  pets: number;
  isFloodProne: boolean;
  isEarthquakeZone: boolean;
  hasChronicMedicalNeeds: boolean;
}

export interface HouseholdRecord {
  id: string;
  name: string;
  inviteCode: string;
  profile: HouseholdProfileData;
  expiryAlertDays: number;
  plan: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface UserRecord {
  id: string;
  email: string;
  passwordHash: string;
  fullName: string;
  role: UserRole;
  householdId: string;
  createdAt: string;
}

export interface KitItemRecord {
  id: string;
  name: string;
  category: number;
  quantity: number;
  targetQuantity: number;
  unit: string;
  expirationDate: string | null;
  isPacked: boolean;
  notes: string;
  lastUpdated: string;
  deleted?: boolean;
}

export interface SafetyCheckinRecord {
  id: string;
  householdId: string;
  userId: string | null;
  authorName: string;
  status: string;
  note: string;
  latitude: number | null;
  longitude: number | null;
  timestamp: string;
  acknowledgedAt: string | null;
  acknowledgedBy: string | null;
}

export type AdvisorySeverity = 'info' | 'warning' | 'critical';

export interface DrrmAdvisoryRecord {
  id: string;
  title: string;
  message: string;
  severity: AdvisorySeverity;
  area: string;
  authorName: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface EvacuationCenterRecord {
  id: string;
  name: string;
  address: string;
  city: string;
  latitude: number;
  longitude: number;
  contactPerson: string;
  contactNumber: string;
  capacityPeople: number;
  isOpen: boolean;
  facilities: string;
  isOfficial: boolean;
  createdByHouseholdId?: string | null;
  updatedAt?: string;
}

export interface TelemetryCacheRecord {
  cacheKey: string;
  latitude: number;
  longitude: number;
  payload: Record<string, unknown>;
  fetchedAt: string;
}

export interface IsoEvaluationInput {
  householdId: string | null;
  respondentLabel: string;
  platform: string;
  functionalityScore: number;
  usabilityScore: number;
  reliabilityScore: number;
  effectivenessScore: number;
  readinessPercentage: number;
  rawCompletionPercentage: number;
  comments: string;
}

export interface IsoEvaluationRecord extends IsoEvaluationInput {
  id: string;
  createdAt: string;
}

export interface SyncBundle {
  household: HouseholdRecord;
  kitItems: KitItemRecord[];
  checkins: SafetyCheckinRecord[];
  shelters: EvacuationCenterRecord[];
}

export interface AdminHouseholdSummary {
  id: string;
  name: string;
  inviteCode: string;
  accountCount: number;
  memberCount: number;
  itemCount: number;
  packedCount: number;
  readinessPct: number;
  updatedAt: string;
  profile: HouseholdProfileData;
  primaryMeetingPoint: string;
  secondaryMeetingPoint: string;
}

export interface AdminCheckinItem extends SafetyCheckinRecord {
  householdName: string;
}

export interface AdminOverviewData {
  counts: {
    households: number;
    users: number;
    openShelters: number;
    totalShelters: number;
    checkinsTotal: number;
    checkinsNeedingHelp: number;
    evaluationsTotal: number;
    activeAdvisories: number;
  };
  households: AdminHouseholdSummary[];
  recentCheckins: AdminCheckinItem[];
  shelters: EvacuationCenterRecord[];
  advisories: DrrmAdvisoryRecord[];
}
