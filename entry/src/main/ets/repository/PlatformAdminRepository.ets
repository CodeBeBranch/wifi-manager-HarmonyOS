import { ApiError } from '../model/ApiModels'
import {
  AccountDeleteReview,
  AccountReviewPage,
  Hm2DemoState,
  Hm2DemoScenario,
  PlatformAccount,
  PlatformAccountPage,
  PlatformSummary,
  PlatformTenantMember,
  SaasPlan,
  SaasPlanPage,
  TenantCreateInput,
  TenantUpdateInput
} from '../model/Hm2Models'
import { PlatformTenant, PlatformTenantPageResult } from '../model/TenantModels'
import { runtimeModeStore } from '../preview/RuntimeMode'
import { appPreferences } from '../storage/AppPreferences'
import http from '@ohos.net.http'
import { sessionStore } from '../session/SessionStore'

const HM2_DEMO_STATE_KEY = 'demo_platform_hm2_state_v1'

export class PlatformAdminMutationTracker {
  private revision: number = 0

  current(): number {
    return this.revision
  }

  mark(): number {
    this.revision += 1
    return this.revision
  }
}

const platformAdminMutationTracker = new PlatformAdminMutationTracker()

export function platformAdminMutationRevision(): number {
  return platformAdminMutationTracker.current()
}

function publishPlatformAdminMutation(): void {
  platformAdminMutationTracker.mark()
}

export interface Hm2PreferenceStorage {
  getString(key: string, fallback?: string): Promise<string>
  putString(key: string, value: string): Promise<void>
  remove(key: string): Promise<void>
}

export interface PlatformAdminRepositoryContract {
  summary(): Promise<PlatformSummary>
  listTenants(current: number, size: number, keyword: string, status: string): Promise<PlatformTenantPageResult>
  createTenant(input: TenantCreateInput): Promise<PlatformTenant>
  tenantDetail(tenantId: string): Promise<PlatformTenant>
  updateTenant(tenantId: string, input: TenantUpdateInput): Promise<PlatformTenant>
  updateTenantStatus(tenantId: string, status: string): Promise<PlatformTenant>
  listTenantMembers(tenantId: string, keyword: string): Promise<PlatformTenantMember[]>
  listAccounts(current: number, size: number, keyword: string, status: string): Promise<PlatformAccountPage>
  accountDetail(userId: string): Promise<PlatformAccount>
  updateAccountStatus(userId: string, status: string): Promise<PlatformAccount>
  submitAccountDeletion(userId: string, reason: string): Promise<AccountDeleteReview>
  listAccountReviews(current: number, size: number, status: string): Promise<AccountReviewPage>
  accountReviewDetail(reviewId: string): Promise<AccountDeleteReview>
  decideAccountReview(reviewId: string, approved: boolean, comment: string): Promise<AccountDeleteReview>
  listSaasPlans(current: number, size: number, keyword: string, status: string): Promise<SaasPlanPage>
  saasPlanDetail(planId: string): Promise<SaasPlan>
  cacheManagedTenant(tenantId: string): void
  managedTenantCacheId(): string
  clearManagedTenantCache(): void
  demoScenario(): Hm2DemoScenario
  setDemoScenario(scenario: Hm2DemoScenario): void
  resetDemo(): Promise<void>
}

function cloneState<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T
}

function defaultTenants(): PlatformTenant[] {
  return [
    {
      tenantId: 'preview-tenant-01',
      tenantCode: 'edge-lab',
      name: '边缘网络实验室',
      status: 'ACTIVE',
      timezone: 'Asia/Shanghai',
      ownerUserId: '2001',
      contextVersion: 8,
      version: 5,
      memberCount: 12,
      subscriptionStatus: 'ACTIVE',
      createTime: '2026-06-18 09:30',
      updateTime: '2026-08-18 14:20'
    },
    {
      tenantId: 'preview-tenant-02',
      tenantCode: 'branch-office',
      name: '分部办公网络',
      status: 'ACTIVE',
      timezone: 'Asia/Shanghai',
      ownerUserId: '2002',
      contextVersion: 4,
      version: 3,
      memberCount: 28,
      subscriptionStatus: 'TRIAL',
      createTime: '2026-07-02 11:15',
      updateTime: '2026-08-17 17:42'
    },
    {
      tenantId: 'preview-tenant-03',
      tenantCode: 'retail-east',
      name: '华东门店网络',
      status: 'ACTIVE',
      timezone: 'Asia/Shanghai',
      ownerUserId: '2003',
      contextVersion: 6,
      version: 4,
      memberCount: 19,
      subscriptionStatus: 'ACTIVE',
      createTime: '2026-05-09 08:40',
      updateTime: '2026-08-16 10:06'
    },
    {
      tenantId: 'preview-tenant-04',
      tenantCode: 'archive-team',
      name: '历史项目归档组',
      status: 'DISABLED',
      timezone: 'Asia/Shanghai',
      ownerUserId: '2004',
      contextVersion: 2,
      version: 7,
      memberCount: 4,
      subscriptionStatus: 'EXPIRED',
      createTime: '2025-12-12 16:00',
      updateTime: '2026-08-01 09:18'
    }
  ]
}

function defaultMembers(): PlatformTenantMember[] {
  return [
    {
      memberId: 'm-01',
      userId: '2001',
      username: 'lab-owner',
      nickname: '实验室负责人',
      role: 'TENANT_OWNER',
      status: 'ACTIVE',
      joinedAt: '2026-06-18'
    },
    {
      memberId: 'm-02',
      userId: '2011',
      username: 'lab-admin',
      nickname: '网络管理员',
      role: 'TENANT_ADMIN',
      status: 'ACTIVE',
      joinedAt: '2026-06-19'
    },
    {
      memberId: 'm-03',
      userId: '2012',
      username: 'lab-member',
      nickname: '值班成员',
      role: 'MEMBER',
      status: 'ACTIVE',
      joinedAt: '2026-07-03'
    },
    {
      memberId: 'm-04',
      userId: '2002',
      username: 'campus-owner',
      nickname: '校园网负责人',
      role: 'TENANT_OWNER',
      status: 'ACTIVE',
      joinedAt: '2026-07-02'
    }
  ]
}

function defaultAccounts(): PlatformAccount[] {
  return [
    {
      userId: '1000',
      username: 'superadmin',
      nickname: '超级管理员',
      email: 'superadmin@wifi.local',
      role: 'SUPER_ADMIN',
      status: 'ACTIVE',
      tenantCount: 0,
      deletionState: 'NONE',
      lastLoginAt: '今天 09:32'
    },
    {
      userId: '2001',
      username: 'lab-owner',
      nickname: '实验室负责人',
      email: 'owner@edge-lab.local',
      role: 'TENANT_OWNER',
      status: 'ACTIVE',
      tenantCount: 1,
      deletionState: 'NONE',
      lastLoginAt: '今天 08:10'
    },
    {
      userId: '2011',
      username: 'lab-admin',
      nickname: '网络管理员',
      email: 'admin@edge-lab.local',
      role: 'TENANT_ADMIN',
      status: 'ACTIVE',
      tenantCount: 1,
      deletionState: 'NONE',
      lastLoginAt: '昨天 21:04'
    },
    {
      userId: '2012',
      username: 'lab-member',
      nickname: '值班成员',
      email: 'member@edge-lab.local',
      role: 'MEMBER',
      status: 'SUSPENDED',
      tenantCount: 1,
      deletionState: 'PENDING',
      lastLoginAt: '8 月 15 日'
    },
    {
      userId: '2108',
      username: 'trial-user',
      nickname: '试用账号',
      email: 'trial@wifi.local',
      role: 'MEMBER',
      status: 'ACTIVE',
      tenantCount: 0,
      deletionState: 'NONE',
      lastLoginAt: '从未登录'
    }
  ]
}

function defaultReviews(): AccountDeleteReview[] {
  return [
    {
      reviewId: 'review-001',
      userId: '2012',
      username: 'lab-member',
      nickname: '值班成员',
      reason: '账号已离职，需要清理访问权限。',
      status: 'PENDING',
      requestedAt: '2026-08-18 10:24',
      reviewedAt: '',
      reviewer: '',
      comment: ''
    },
    {
      reviewId: 'review-000',
      userId: '2099',
      username: 'old-contractor',
      nickname: '外协账号',
      reason: '项目已结束。',
      status: 'REJECTED',
      requestedAt: '2026-08-10 09:12',
      reviewedAt: '2026-08-10 11:08',
      reviewer: 'superadmin',
      comment: '仍有关联审计记录，暂不删除。'
    }
  ]
}

function defaultPlans(): SaasPlan[] {
  return [
    {
      planId: 'plan-basic',
      planCode: 'BASIC',
      name: '基础版',
      version: 'v2.1',
      status: 'PUBLISHED',
      priceLabel: '¥199 / 月',
      billingCycle: 'MONTHLY',
      deviceLimit: 10,
      memberLimit: 20,
      features: ['设备与连接管理', '基础告警', '7 天数据保留'],
      updatedAt: '2026-08-12'
    },
    {
      planId: 'plan-pro',
      planCode: 'PRO',
      name: '专业版',
      version: 'v3.0',
      status: 'PUBLISHED',
      priceLabel: '¥699 / 月',
      billingCycle: 'MONTHLY',
      deviceLimit: 100,
      memberLimit: 200,
      features: ['高级告警与审计', '位置与围栏', '90 天数据保留'],
      updatedAt: '2026-08-17'
    },
    {
      planId: 'plan-enterprise',
      planCode: 'ENTERPRISE',
      name: '企业版',
      version: 'v1.4',
      status: 'DRAFT',
      priceLabel: '联系平台',
      billingCycle: 'CUSTOM',
      deviceLimit: 1000,
      memberLimit: 5000,
      features: ['专属配额', '跨区域治理', '长期审计归档'],
      updatedAt: '2026-08-18'
    }
  ]
}

export function createDefaultHm2State(): Hm2DemoState {
  return {
    tenants: defaultTenants(),
    members: defaultMembers(),
    accounts: defaultAccounts(),
    reviews: defaultReviews(),
    plans: defaultPlans(),
    nextTenantSequence: 5,
    nextReviewSequence: 2
  }
}

function normalizePage(current: number): number {
  return Math.max(1, Math.floor(current))
}

function normalizeSize(size: number): number {
  return Math.min(50, Math.max(1, Math.floor(size)))
}

function containsText(values: string[], keyword: string): boolean {
  const normalized = keyword.trim().toLowerCase()
  if (normalized.length === 0) return true
  return values.some((value: string): boolean => value.toLowerCase().includes(normalized))
}

function requireText(value: string, label: string, maxLength: number): string {
  const normalized = value.trim()
  if (normalized.length === 0) {
    throw new ApiError(`请输入${label}`, 400, 400, 'VALIDATION_FAILED')
  }
  if (normalized.length > maxLength) {
    throw new ApiError(`${label}不能超过 ${maxLength} 个字符`, 400, 400, 'VALIDATION_FAILED')
  }
  return normalized
}

export class DemoPlatformAdminRepository implements PlatformAdminRepositoryContract {
  private state: Hm2DemoState = createDefaultHm2State()
  private operation: Promise<void> = Promise.resolve()
  private managedTenantId: string = ''
  private loaded: boolean = false
  private loadOperation: Promise<void> | null = null
  private readonly persistent: boolean
  private readonly preferenceStorage: Hm2PreferenceStorage
  private scenario: Hm2DemoScenario = 'NORMAL'

  constructor(persistent: boolean = false, preferenceStorage: Hm2PreferenceStorage = appPreferences) {
    this.persistent = persistent
    this.preferenceStorage = preferenceStorage
  }

  async summary(): Promise<PlatformSummary> {
    await this.waitForWrites()
    await this.ensureLoaded()
    await this.beforeRead('SUMMARY')
    if (this.scenario === 'EMPTY') {
      return {
        tenantTotal: 0,
        activeTenantTotal: 0,
        accountTotal: 0,
        pendingReviewTotal: 0,
        activePlanTotal: 0
      }
    }
    return {
      tenantTotal: this.state.tenants.length,
      activeTenantTotal: this.state.tenants.filter(
        (item: PlatformTenant): boolean => item.status === 'ACTIVE'
      ).length,
      accountTotal: this.state.accounts.filter(
        (item: PlatformAccount): boolean => item.status !== 'DELETED'
      ).length,
      pendingReviewTotal: this.state.reviews.filter(
        (item: AccountDeleteReview): boolean => item.status === 'PENDING'
      ).length,
      activePlanTotal: this.state.plans.filter(
        (item: SaasPlan): boolean => item.status === 'PUBLISHED'
      ).length
    }
  }

  async listTenants(
    current: number,
    size: number,
    keyword: string,
    status: string
  ): Promise<PlatformTenantPageResult> {
    await this.waitForWrites()
    await this.ensureLoaded()
    await this.beforeRead('TENANTS')
    const page = normalizePage(current)
    const pageSize = normalizeSize(size)
    if (this.scenario === 'EMPTY' ||
      (this.scenario === 'FILTER_EMPTY' && (keyword.trim().length > 0 || status.length > 0))) {
      return { total: 0, current: page, size: pageSize, records: [] }
    }
    const records = this.state.tenants.filter((item: PlatformTenant): boolean =>
      containsText([item.name, item.tenantCode], keyword) &&
      (status.length === 0 || item.status === status)
    )
    const start = (page - 1) * pageSize
    return {
      total: records.length,
      current: page,
      size: pageSize,
      records: cloneState(records.slice(start, start + pageSize))
    }
  }

  async createTenant(input: TenantCreateInput): Promise<PlatformTenant> {
    this.beforeMutation()
    return this.write<PlatformTenant>(() => {
      const tenantCode = requireText(input.tenantCode, '组织标识', 32).toLowerCase()
      const name = requireText(input.name, '组织名称', 64)
      const timezone = requireText(input.timezone, '时区', 48)
      const ownerUsername = requireText(input.ownerUsername, '负责人账号', 64)
      if (!/^[a-z0-9][a-z0-9-]{2,31}$/.test(tenantCode)) {
        throw new ApiError('组织标识仅支持小写字母、数字和连字符', 400, 400, 'TENANT_CODE_INVALID')
      }
      if (this.state.tenants.some(
        (item: PlatformTenant): boolean => item.tenantCode === tenantCode
      )) {
        throw new ApiError('组织标识已存在', 409, 409, 'TENANT_CODE_CONFLICT')
      }
      const owner = this.state.accounts.find(
        (item: PlatformAccount): boolean => item.username === ownerUsername
      )
      if (owner === undefined || owner.status !== 'ACTIVE') {
        throw new ApiError('负责人账号不存在或不可用', 400, 400, 'TENANT_OWNER_INVALID')
      }
      const sequence = this.state.nextTenantSequence
      this.state.nextTenantSequence += 1
      const tenant: PlatformTenant = {
        tenantId: `preview-tenant-${String(sequence).padStart(2, '0')}`,
        tenantCode: tenantCode,
        name: name,
        status: 'ACTIVE',
        timezone: timezone,
        ownerUserId: owner.userId,
        contextVersion: 1,
        version: 1,
        memberCount: 1,
        subscriptionStatus: 'TRIAL',
        createTime: '刚刚',
        updateTime: '刚刚'
      }
      this.state.tenants.unshift(tenant)
      return cloneState(tenant)
    })
  }

  async tenantDetail(tenantId: string): Promise<PlatformTenant> {
    await this.waitForWrites()
    await this.ensureLoaded()
    await this.beforeRead('TENANT_DETAIL')
    this.requireNonEmptyScenario('组织')
    return cloneState(this.requireTenant(tenantId))
  }

  async updateTenant(tenantId: string, input: TenantUpdateInput): Promise<PlatformTenant> {
    this.beforeMutation()
    return this.write<PlatformTenant>(() => {
      const tenant = this.requireTenant(tenantId)
      tenant.name = requireText(input.name, '组织名称', 64)
      tenant.timezone = requireText(input.timezone, '时区', 48)
      tenant.version += 1
      tenant.updateTime = '刚刚'
      return cloneState(tenant)
    })
  }

  async updateTenantStatus(tenantId: string, status: string): Promise<PlatformTenant> {
    this.beforeMutation()
    return this.write<PlatformTenant>(() => {
      if (status !== 'ACTIVE' && status !== 'DISABLED') {
        throw new ApiError('组织状态无效', 400, 400, 'TENANT_STATUS_INVALID')
      }
      const tenant = this.requireTenant(tenantId)
      tenant.status = status
      tenant.contextVersion += 1
      tenant.version += 1
      tenant.updateTime = '刚刚'
      return cloneState(tenant)
    })
  }

  async listTenantMembers(tenantId: string, keyword: string): Promise<PlatformTenantMember[]> {
    await this.waitForWrites()
    await this.ensureLoaded()
    await this.beforeRead('TENANT_MEMBERS')
    if (this.scenario === 'EMPTY') {
      return []
    }
    const tenant = this.requireTenant(tenantId)
    const owner = this.state.accounts.find(
      (item: PlatformAccount): boolean => item.userId === tenant.ownerUserId
    )
    const memberIds = tenantId === 'preview-tenant-01'
      ? ['2001', '2011', '2012']
      : [tenant.ownerUserId]
    let members = this.state.members.filter(
      (item: PlatformTenantMember): boolean => memberIds.includes(item.userId)
    ).map((item: PlatformTenantMember): PlatformTenantMember => {
      if (item.userId !== tenant.ownerUserId) {
        return item
      }
      return {
        memberId: `owner-${tenantId}`,
        userId: item.userId,
        username: item.username,
        nickname: item.nickname,
        role: 'TENANT_OWNER',
        status: item.status,
        joinedAt: item.joinedAt
      }
    })
    if (members.length === 0 && owner !== undefined) {
      members = [{
        memberId: `owner-${tenantId}`,
        userId: owner.userId,
        username: owner.username,
        nickname: owner.nickname,
        role: 'TENANT_OWNER',
        status: owner.status,
        joinedAt: tenant.createTime ?? ''
      }]
    }
    if (this.scenario === 'FILTER_EMPTY' && keyword.trim().length > 0) {
      return []
    }
    return cloneState(members.filter((item: PlatformTenantMember): boolean =>
      containsText([item.username, item.nickname, item.role], keyword)
    ))
  }

  async listAccounts(
    current: number,
    size: number,
    keyword: string,
    status: string
  ): Promise<PlatformAccountPage> {
    await this.waitForWrites()
    await this.ensureLoaded()
    await this.beforeRead('ACCOUNTS')
    const page = normalizePage(current)
    const pageSize = normalizeSize(size)
    if (this.scenario === 'EMPTY' ||
      (this.scenario === 'FILTER_EMPTY' && (keyword.trim().length > 0 || status.length > 0))) {
      return { total: 0, current: page, size: pageSize, records: [] }
    }
    const records = this.state.accounts.filter((item: PlatformAccount): boolean =>
      containsText([item.username, item.nickname, item.email], keyword) &&
      (status.length === 0 || item.status === status)
    )
    const start = (page - 1) * pageSize
    return {
      total: records.length,
      current: page,
      size: pageSize,
      records: cloneState(records.slice(start, start + pageSize))
    }
  }

  async accountDetail(userId: string): Promise<PlatformAccount> {
    await this.waitForWrites()
    await this.ensureLoaded()
    await this.beforeRead('ACCOUNT_DETAIL')
    this.requireNonEmptyScenario('账号')
    return cloneState(this.requireAccount(userId))
  }

  async updateAccountStatus(userId: string, status: string): Promise<PlatformAccount> {
    this.beforeMutation()
    return this.write<PlatformAccount>(() => {
      if (status !== 'ACTIVE' && status !== 'SUSPENDED') {
        throw new ApiError('账号状态无效', 400, 400, 'ACCOUNT_STATUS_INVALID')
      }
      const account = this.requireAccount(userId)
      if (account.role === 'SUPER_ADMIN') {
        throw new ApiError('演示模式不允许停用当前超级管理员', 409, 409, 'SELF_STATUS_FORBIDDEN')
      }
      if (account.status === 'DELETED') {
        throw new ApiError('已删除账号不能变更状态', 409, 409, 'ACCOUNT_ALREADY_DELETED')
      }
      account.status = status
      return cloneState(account)
    })
  }

  async submitAccountDeletion(userId: string, reason: string): Promise<AccountDeleteReview> {
    this.beforeMutation()
    return this.write<AccountDeleteReview>(() => {
      const account = this.requireAccount(userId)
      if (account.role === 'SUPER_ADMIN') {
        throw new ApiError('不能提交超级管理员删除申请', 409, 409, 'SELF_DELETE_FORBIDDEN')
      }
      if (account.deletionState === 'PENDING') {
        throw new ApiError('该账号已有待处理删除申请', 409, 409, 'DELETE_REVIEW_PENDING')
      }
      const normalizedReason = requireText(reason, '删除原因', 255)
      const sequence = this.state.nextReviewSequence
      this.state.nextReviewSequence += 1
      const review: AccountDeleteReview = {
        reviewId: `review-${String(sequence).padStart(3, '0')}`,
        userId: account.userId,
        username: account.username,
        nickname: account.nickname,
        reason: normalizedReason,
        status: 'PENDING',
        requestedAt: '刚刚',
        reviewedAt: '',
        reviewer: '',
        comment: ''
      }
      account.deletionState = 'PENDING'
      this.state.reviews.unshift(review)
      return cloneState(review)
    })
  }

  async listAccountReviews(current: number, size: number, status: string): Promise<AccountReviewPage> {
    await this.waitForWrites()
    await this.ensureLoaded()
    await this.beforeRead('ACCOUNT_REVIEWS')
    const page = normalizePage(current)
    const pageSize = normalizeSize(size)
    if (this.scenario === 'EMPTY' ||
      (this.scenario === 'FILTER_EMPTY' && status.length > 0)) {
      return { total: 0, current: page, size: pageSize, records: [] }
    }
    const records = this.state.reviews.filter(
      (item: AccountDeleteReview): boolean => status.length === 0 || item.status === status
    )
    const start = (page - 1) * pageSize
    return {
      total: records.length,
      current: page,
      size: pageSize,
      records: cloneState(records.slice(start, start + pageSize))
    }
  }

  async accountReviewDetail(reviewId: string): Promise<AccountDeleteReview> {
    await this.waitForWrites()
    await this.ensureLoaded()
    await this.beforeRead('ACCOUNT_REVIEW_DETAIL')
    this.requireNonEmptyScenario('删除申请')
    return cloneState(this.requireReview(reviewId))
  }

  async decideAccountReview(
    reviewId: string,
    approved: boolean,
    comment: string
  ): Promise<AccountDeleteReview> {
    this.beforeMutation()
    return this.write<AccountDeleteReview>(() => {
      const review = this.requireReview(reviewId)
      if (review.status !== 'PENDING') {
        throw new ApiError('该申请已经处理', 409, 409, 'DELETE_REVIEW_FINISHED')
      }
      const account = this.requireAccount(review.userId)
      review.status = approved ? 'APPROVED' : 'REJECTED'
      review.comment = comment.trim()
      review.reviewedAt = '刚刚'
      review.reviewer = 'superadmin'
      account.deletionState = review.status
      if (approved) {
        account.status = 'DELETED'
      }
      return cloneState(review)
    })
  }

  async listSaasPlans(
    current: number,
    size: number,
    keyword: string,
    status: string
  ): Promise<SaasPlanPage> {
    await this.waitForWrites()
    await this.ensureLoaded()
    await this.beforeRead('PLANS')
    const page = normalizePage(current)
    const pageSize = normalizeSize(size)
    if (this.scenario === 'EMPTY' ||
      (this.scenario === 'FILTER_EMPTY' && (keyword.trim().length > 0 || status.length > 0))) {
      return { total: 0, current: page, size: pageSize, records: [] }
    }
    const records = this.state.plans.filter((item: SaasPlan): boolean =>
      containsText([item.name, item.planCode, item.version], keyword) &&
      (status.length === 0 || item.status === status)
    )
    const start = (page - 1) * pageSize
    return {
      total: records.length,
      current: page,
      size: pageSize,
      records: cloneState(records.slice(start, start + pageSize))
    }
  }

  async saasPlanDetail(planId: string): Promise<SaasPlan> {
    await this.waitForWrites()
    await this.ensureLoaded()
    await this.beforeRead('PLAN_DETAIL')
    this.requireNonEmptyScenario('套餐')
    const plan = this.state.plans.find((item: SaasPlan): boolean => item.planId === planId)
    if (plan === undefined) {
      throw new ApiError('没有找到套餐', 404, 404, 'SAAS_PLAN_NOT_FOUND')
    }
    return cloneState(plan)
  }

  cacheManagedTenant(tenantId: string): void {
    this.managedTenantId = tenantId
  }

  managedTenantCacheId(): string {
    return this.managedTenantId
  }

  clearManagedTenantCache(): void {
    this.managedTenantId = ''
  }

  demoScenario(): Hm2DemoScenario {
    return this.scenario
  }

  setDemoScenario(scenario: Hm2DemoScenario): void {
    this.scenario = scenario
  }

  async resetDemo(): Promise<void> {
    const previous = this.operation
    this.operation = (async (): Promise<void> => {
      try {
        await previous
      } catch (_) {
      }
      const previousState = cloneState(this.state)
      const previousManagedTenantId = this.managedTenantId
      const previousLoaded = this.loaded
      const previousScenario = this.scenario
      const previousSerialized = JSON.stringify(previousState)
      const resetSerialized = JSON.stringify(createDefaultHm2State())
      try {
        this.state = createDefaultHm2State()
        this.managedTenantId = ''
        this.loaded = true
        this.scenario = 'NORMAL'
        if (this.persistent) {
          await this.preferenceStorage.putString(HM2_DEMO_STATE_KEY, resetSerialized)
        }
      } catch (error) {
        this.state = previousState
        this.managedTenantId = previousManagedTenantId
        this.loaded = previousLoaded
        this.scenario = previousScenario
        if (this.persistent) {
          try {
            await this.preferenceStorage.putString(HM2_DEMO_STATE_KEY, previousSerialized)
          } catch (_) {
          }
        }
        throw error instanceof Error ? error : new Error('本地演示重置失败')
      }
    })()
    await this.operation
  }

  private requireTenant(tenantId: string): PlatformTenant {
    const tenant = this.state.tenants.find(
      (item: PlatformTenant): boolean => item.tenantId === tenantId
    )
    if (tenant === undefined) {
      throw new ApiError('没有找到组织', 404, 404, 'TENANT_NOT_FOUND')
    }
    return tenant
  }

  private requireAccount(userId: string): PlatformAccount {
    const account = this.state.accounts.find(
      (item: PlatformAccount): boolean => item.userId === userId
    )
    if (account === undefined) {
      throw new ApiError('没有找到账号', 404, 404, 'ACCOUNT_NOT_FOUND')
    }
    return account
  }

  private requireReview(reviewId: string): AccountDeleteReview {
    const review = this.state.reviews.find(
      (item: AccountDeleteReview): boolean => item.reviewId === reviewId
    )
    if (review === undefined) {
      throw new ApiError('没有找到删除申请', 404, 404, 'DELETE_REVIEW_NOT_FOUND')
    }
    return review
  }

  private async beforeRead(area: string): Promise<void> {
    if (this.scenario === 'LOADING') {
      await new Promise<void>((resolve: () => void): void => {
        setTimeout(resolve, 2500)
      })
    }
    if (this.scenario === 'FORBIDDEN') {
      throw new ApiError('当前账号无权访问平台治理能力', 403, 403, 'FORBIDDEN')
    }
    if (this.scenario === 'RATE_LIMITED') {
      throw new ApiError('请求过于频繁，请稍后再试', 429, 429, 'RATE_LIMITED', '', '3', true)
    }
    if (this.scenario === 'DEPENDENCY_DOWN') {
      throw new ApiError('平台依赖暂时不可用', 503, 503, 'DEPENDENCY_DOWN', '', '', true)
    }
    if (this.scenario === 'PARTIAL_FAILURE' &&
      (area === 'SUMMARY' || area === 'PLANS' || area === 'PLAN_DETAIL')) {
      throw new ApiError('平台服务摘要暂时不可用', 502, 502, 'PARTIAL_FAILURE', '', '', true)
    }
  }

  private beforeMutation(): void {
    if (this.scenario === 'FORBIDDEN') {
      throw new ApiError('当前账号无权执行该操作', 403, 403, 'FORBIDDEN')
    }
    if (this.scenario === 'CONFLICT') {
      throw new ApiError('状态已变化，请刷新后重试', 409, 409, 'STATE_CONFLICT')
    }
    if (this.scenario === 'RATE_LIMITED') {
      throw new ApiError('操作过于频繁，请稍后再试', 429, 429, 'RATE_LIMITED', '', '3', true)
    }
    if (this.scenario === 'DEPENDENCY_DOWN') {
      throw new ApiError('平台依赖暂时不可用', 503, 503, 'DEPENDENCY_DOWN', '', '', true)
    }
  }

  private requireNonEmptyScenario(label: string): void {
    if (this.scenario === 'EMPTY') {
      throw new ApiError(`没有找到${label}`, 404, 404, 'DEMO_EMPTY')
    }
  }

  private async waitForWrites(): Promise<void> {
    try {
      await this.operation
    } catch (_) {
    }
  }

  private async ensureLoaded(): Promise<void> {
    if (this.loaded) return
    if (this.loadOperation === null) {
      this.loadOperation = (async (): Promise<void> => {
        if (this.persistent) {
          const serialized = await this.preferenceStorage.getString(HM2_DEMO_STATE_KEY)
          if (serialized.length > 0) {
            try {
              this.state = JSON.parse(serialized) as Hm2DemoState
            } catch (_) {
              this.state = createDefaultHm2State()
              await this.preferenceStorage.remove(HM2_DEMO_STATE_KEY)
            }
          }
        }
        this.loaded = true
      })()
    }
    await this.loadOperation
  }

  private async write<T>(action: () => T): Promise<T> {
    const previous = this.operation
    let result: T | null = null
    const task: Promise<void> = (async (): Promise<void> => {
      try {
        await previous
      } catch (_) {
      }
      await this.ensureLoaded()
      const previousState = cloneState(this.state)
      const previousSerialized = JSON.stringify(previousState)
      let persistenceAttempted = false
      try {
        result = action()
        if (this.persistent) {
          persistenceAttempted = true
          await this.preferenceStorage.putString(HM2_DEMO_STATE_KEY, JSON.stringify(this.state))
        }
        publishPlatformAdminMutation()
      } catch (error) {
        this.state = previousState
        if (this.persistent && persistenceAttempted) {
          try {
            await this.preferenceStorage.putString(HM2_DEMO_STATE_KEY, previousSerialized)
          } catch (_) {
          }
        }
        throw error instanceof Error ? error : new Error('本地状态更新失败')
      }
    })()
    this.operation = task.catch((): void => {})
    await task
    if (result === null) {
      throw new ApiError('本地状态更新失败', 500, 500, 'DEMO_STATE_UPDATE_FAILED')
    }
    return result
  }
}

function realPending(): ApiError {
  return new ApiError(
    '该能力等待真实环境契约与上下文联调后开放',
    503,
    503,
    'REAL_CONTRACT_PENDING'
  )
}

class RealPlatformAdminRepository implements PlatformAdminRepositoryContract {
  private managedTenantId: string = ''

  async summary(): Promise<PlatformSummary> {
    throw realPending()
  }

  async listTenants(
    current: number,
    size: number,
    keyword: string,
    _status: string
  ): Promise<PlatformTenantPageResult> {
    const query = keyword.trim().length > 0
      ? `&keyword=${encodeURIComponent(keyword.trim())}`
      : ''
    const response = await sessionStore.authorizedRequest<PlatformTenantPageResult>(
      http.RequestMethod.GET,
      `/admin/platform/tenants?current=${current}&size=${size}${query}`
    )
    return response.data
  }

  async createTenant(_input: TenantCreateInput): Promise<PlatformTenant> {
    throw realPending()
  }

  async tenantDetail(_tenantId: string): Promise<PlatformTenant> {
    throw realPending()
  }

  async updateTenant(_tenantId: string, _input: TenantUpdateInput): Promise<PlatformTenant> {
    throw realPending()
  }

  async updateTenantStatus(_tenantId: string, _status: string): Promise<PlatformTenant> {
    throw realPending()
  }

  async listTenantMembers(_tenantId: string, _keyword: string): Promise<PlatformTenantMember[]> {
    throw realPending()
  }

  async listAccounts(
    _current: number,
    _size: number,
    _keyword: string,
    _status: string
  ): Promise<PlatformAccountPage> {
    throw realPending()
  }

  async accountDetail(_userId: string): Promise<PlatformAccount> {
    throw realPending()
  }

  async updateAccountStatus(_userId: string, _status: string): Promise<PlatformAccount> {
    throw realPending()
  }

  async submitAccountDeletion(_userId: string, _reason: string): Promise<AccountDeleteReview> {
    throw realPending()
  }

  async listAccountReviews(
    _current: number,
    _size: number,
    _status: string
  ): Promise<AccountReviewPage> {
    throw realPending()
  }

  async accountReviewDetail(_reviewId: string): Promise<AccountDeleteReview> {
    throw realPending()
  }

  async decideAccountReview(
    _reviewId: string,
    _approved: boolean,
    _comment: string
  ): Promise<AccountDeleteReview> {
    throw realPending()
  }

  async listSaasPlans(
    _current: number,
    _size: number,
    _keyword: string,
    _status: string
  ): Promise<SaasPlanPage> {
    throw realPending()
  }

  async saasPlanDetail(_planId: string): Promise<SaasPlan> {
    throw realPending()
  }

  cacheManagedTenant(tenantId: string): void {
    this.managedTenantId = tenantId
  }

  managedTenantCacheId(): string {
    return this.managedTenantId
  }

  clearManagedTenantCache(): void {
    this.managedTenantId = ''
  }

  demoScenario(): Hm2DemoScenario {
    throw realPending()
  }

  setDemoScenario(_scenario: Hm2DemoScenario): void {
    throw realPending()
  }

  async resetDemo(): Promise<void> {
    throw realPending()
  }
}

export class PlatformAdminRepositoryFactory {
  private readonly demo = new DemoPlatformAdminRepository(true)
  private real: RealPlatformAdminRepository | null = null

  current(): PlatformAdminRepositoryContract {
    if (runtimeModeStore.isDemo()) {
      return this.demo
    }
    if (this.real === null) {
      this.real = new RealPlatformAdminRepository()
    }
    return this.real
  }

  demoForTest(): DemoPlatformAdminRepository {
    return new DemoPlatformAdminRepository()
  }

  realRepositoryCreatedForTest(): boolean {
    return this.real !== null
  }
}

export const platformAdminRepositoryFactory = new PlatformAdminRepositoryFactory()
