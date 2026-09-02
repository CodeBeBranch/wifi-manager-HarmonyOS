import { PlatformTenant } from './TenantModels'

export type Hm2DemoScenario =
  'NORMAL' |
  'EMPTY' |
  'FILTER_EMPTY' |
  'LOADING' |
  'PARTIAL_FAILURE' |
  'FORBIDDEN' |
  'CONFLICT' |
  'RATE_LIMITED' |
  'DEPENDENCY_DOWN'

export interface PlatformSummary {
  tenantTotal: number
  activeTenantTotal: number
  accountTotal: number
  pendingReviewTotal: number
  activePlanTotal: number
}

export interface TenantCreateInput {
  tenantCode: string
  name: string
  timezone: string
  ownerUsername: string
}

export interface TenantUpdateInput {
  name: string
  timezone: string
}

export interface PlatformTenantMember {
  memberId: string
  tenantId?: string
  userId: string
  username: string
  nickname: string
  role: string
  status: string
  joinedAt: string
}

export interface PlatformAccount {
  userId: string
  username: string
  nickname: string
  email: string
  role: string
  status: string
  tenantCount: number
  deletionState: string
  lastLoginAt: string
}

export interface PlatformAccountPage {
  total: number
  current: number
  size: number
  records: PlatformAccount[]
}

export interface AccountDeleteReview {
  reviewId: string
  userId: string
  username: string
  nickname: string
  reason: string
  status: string
  requestedAt: string
  reviewedAt: string
  reviewer: string
  comment: string
}

export interface AccountReviewPage {
  total: number
  current: number
  size: number
  records: AccountDeleteReview[]
}

export interface SaasPlan {
  planId: string
  planCode: string
  name: string
  version: string
  status: string
  priceLabel: string
  billingCycle: string
  deviceLimit: number
  memberLimit: number
  features: string[]
  updatedAt: string
}

export interface SaasPlanPage {
  total: number
  current: number
  size: number
  records: SaasPlan[]
}

export interface SaasPlanInput {
  planCode: string
  name: string
  version: string
  status: string
  priceLabel: string
  billingCycle: string
  deviceLimit: number
  memberLimit: number
  features: string[]
}

export interface Hm2DemoState {
  tenants: PlatformTenant[]
  members: PlatformTenantMember[]
  accounts: PlatformAccount[]
  reviews: AccountDeleteReview[]
  plans: SaasPlan[]
  nextTenantSequence: number
  nextReviewSequence: number
  nextPlanSequence: number
}

export interface PlatformTenantDetailParams {
  tenantId: string
}

export interface PlatformAccountDetailParams {
  userId: string
}

export interface PlatformAccountEntitlementParams {
  tenantId: string
  userId: string
}

export interface PlatformReviewDetailParams {
  reviewId: string
}

export interface SaasPlanDetailParams {
  planId: string
}
