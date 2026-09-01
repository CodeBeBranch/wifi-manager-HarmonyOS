import { DEBUG } from 'BuildProfile'
import {
  anonymousSnapshot,
  LoginByCodeRequest,
  LoginRequest,
  SessionSnapshot,
  TenantContext
} from '../model/AuthModels'

const PREVIEW_PASSWORD = '123456'
const PREVIEW_CODE = '123456'
const PREVIEW_PHONE = '13800138000'
const PREVIEW_EMAIL = 'demo@wifi.local'
const PREVIEW_TENANT_ID = 'preview-tenant-01'

export interface PreviewAccount {
  account: string
  label: string
  role: number
}

const PREVIEW_ACCOUNTS: PreviewAccount[] = [
  { account: 'superadmin', label: '超级管理员', role: 0 },
  { account: 'tenantadmin', label: '租户管理员', role: 1 },
  { account: 'member', label: '普通成员', role: 2 }
]

export function isPreviewAvailable(): boolean {
  return DEBUG
}

export function previewAccounts(): PreviewAccount[] {
  return PREVIEW_ACCOUNTS.slice()
}

function findPreviewAccount(account: string): PreviewAccount | null {
  const normalized = account.trim()
  return PREVIEW_ACCOUNTS.find((item: PreviewAccount): boolean =>
    item.account === normalized) ?? null
}

export function previewCredentialMatches(
  loginType: string,
  account: string,
  password: string,
  debugEnabled: boolean
): boolean {
  return debugEnabled && loginType === 'username' &&
    findPreviewAccount(account) !== null && password === PREVIEW_PASSWORD
}

export function previewCodeCredentialMatches(
  target: string,
  code: string,
  debugEnabled: boolean
): boolean {
  const normalizedTarget = target.trim().toLowerCase()
  return debugEnabled && code.trim() === PREVIEW_CODE &&
    (normalizedTarget === PREVIEW_PHONE || normalizedTarget === PREVIEW_EMAIL)
}

export function isPreviewCodeTarget(target: string): boolean {
  const normalized = target.trim().toLowerCase()
  return DEBUG && (normalized === PREVIEW_PHONE || normalized === PREVIEW_EMAIL)
}

export function previewPhone(): string {
  return PREVIEW_PHONE
}

function createPlatformContext(): TenantContext {
  return {
    contextType: 'PLATFORM',
    tenantId: '',
    tenantCode: '',
    tenantName: '',
    tenantRole: 'PLATFORM_ADMIN',
    contextVersion: 1,
    memberContextVersion: 0,
    tenantStatus: 'ACTIVE',
    writable: false,
    authorities: ['PLATFORM_TENANT_READ']
  }
}

function createManagedTenantContext(tenantId: string): TenantContext {
  const selectedTenantId = tenantId.length > 0 ? tenantId : PREVIEW_TENANT_ID
  return {
    contextType: 'PLATFORM_TENANT',
    tenantId: selectedTenantId,
    tenantCode: selectedTenantId === PREVIEW_TENANT_ID ? 'edge-lab' : 'branch-office',
    tenantName: selectedTenantId === PREVIEW_TENANT_ID ? '边缘网络实验室' : '分部办公网络',
    tenantRole: 'PLATFORM_ADMIN',
    contextVersion: 3,
    memberContextVersion: 1,
    tenantStatus: 'ACTIVE',
    writable: true,
    authorities: [
      'DEVICE_READ',
      'DEVICE_WRITE',
      'SESSION_READ',
      'SESSION_REVOKE',
      'ALERT_READ',
      'ALERT_HANDLE',
      'COMMAND_SUBMIT',
      'WIFI_CONFIG_SUBMIT',
      'REFUND_REVIEW',
      'LOCATION_READ',
      'GEOFENCE_READ',
      'ANALYTICS_READ'
    ]
  }
}

function createTenantContext(role: number): TenantContext {
  return {
    contextType: 'TENANT',
    tenantId: PREVIEW_TENANT_ID,
    tenantCode: 'edge-lab',
    tenantName: '边缘网络实验室',
    tenantRole: role === 1 ? 'TENANT_ADMIN' : 'MEMBER',
    contextVersion: 3,
    memberContextVersion: 2,
    tenantStatus: 'ACTIVE',
    writable: true,
    authorities: role === 1
      ? [
        'DEVICE_READ',
        'DEVICE_WRITE',
        'SESSION_READ',
        'SESSION_REVOKE',
        'ALERT_READ',
        'ALERT_HANDLE',
        'COMMAND_SUBMIT',
        'WIFI_CONFIG_SUBMIT',
        'RULE_WRITE',
        'BLACKLIST_WRITE',
        'REFUND_REVIEW',
        'LOCATION_READ',
        'GEOFENCE_READ',
        'GEOFENCE_WRITE',
        'ANALYTICS_READ'
      ]
      : [
        'SESSION_SELF_READ',
        'PROFILE_SELF_WRITE',
        'ENTITLEMENT_SELF_READ',
        'ORDER_SELF_WRITE',
        'PAYMENT_SELF_WRITE',
        'REFUND_SELF_WRITE',
        'LOCATION_SELF_WRITE'
      ]
  }
}

function createSnapshot(account: PreviewAccount, context: TenantContext): SessionSnapshot {
  return {
    authenticated: true,
    accountState: 'ACTIVE',
    userId: `preview-${account.account}`,
    username: account.account,
    nickname: account.label,
    role: account.role,
    context: context
  }
}

export function persistentPreviewSnapshot(snapshot: SessionSnapshot): SessionSnapshot {
  if (snapshot.authenticated && snapshot.role === 0 &&
    snapshot.context?.contextType === 'PLATFORM_TENANT') {
    return {
      authenticated: snapshot.authenticated,
      accountState: snapshot.accountState,
      userId: snapshot.userId,
      username: snapshot.username,
      nickname: snapshot.nickname,
      role: snapshot.role,
      context: createPlatformContext()
    }
  }
  return snapshot
}

export class PreviewSession {
  private snapshot: SessionSnapshot | null = null

  tryLogin(request: LoginRequest): SessionSnapshot | null {
    if (!previewCredentialMatches(
      request.loginType,
      request.account,
      request.password,
      DEBUG
    )) {
      return null
    }
    const account = findPreviewAccount(request.account)
    if (account === null) {
      return null
    }
    const context = account.role === 0
      ? createPlatformContext()
      : createTenantContext(account.role)
    this.snapshot = createSnapshot(account, context)
    return this.snapshot
  }

  tryLoginByCode(request: LoginByCodeRequest): SessionSnapshot | null {
    if (!previewCodeCredentialMatches(request.target, request.code, DEBUG)) {
      return null
    }
    const account = PREVIEW_ACCOUNTS[2]
    this.snapshot = createSnapshot(account, createTenantContext(account.role))
    return this.snapshot
  }

  canSendCode(target: string): boolean {
    return isPreviewCodeTarget(target)
  }

  restore(snapshot: SessionSnapshot): boolean {
    const account = findPreviewAccount(snapshot.username)
    if (!snapshot.authenticated || account === null) {
      this.snapshot = null
      return false
    }
    const context = account.role === 0 &&
      snapshot.context?.contextType === 'PLATFORM_TENANT' &&
      snapshot.context.tenantId.length > 0
      ? createManagedTenantContext(snapshot.context.tenantId)
      : account.role === 0
        ? createPlatformContext()
        : createTenantContext(account.role)
    const restored = createSnapshot(account, context)
    const nickname = snapshot.nickname.trim()
    if (nickname.length >= 2 && nickname.length <= 40) {
      restored.nickname = nickname
    }
    this.snapshot = restored
    return true
  }

  updateNickname(nickname: string): SessionSnapshot {
    if (this.snapshot === null) {
      return anonymousSnapshot()
    }
    this.snapshot = {
      authenticated: this.snapshot.authenticated,
      accountState: this.snapshot.accountState,
      userId: this.snapshot.userId,
      username: this.snapshot.username,
      nickname: nickname,
      role: this.snapshot.role,
      context: this.snapshot.context
    }
    return this.snapshot
  }

  resetCurrent(): SessionSnapshot {
    if (this.snapshot === null) {
      return anonymousSnapshot()
    }
    const account = findPreviewAccount(this.snapshot.username)
    if (account === null) {
      this.snapshot = null
      return anonymousSnapshot()
    }
    const currentContext = this.snapshot.context
    const context = account.role === 0 &&
      currentContext?.contextType === 'PLATFORM_TENANT' &&
      currentContext.tenantId.length > 0
      ? createManagedTenantContext(currentContext.tenantId)
      : account.role === 0
        ? createPlatformContext()
        : createTenantContext(account.role)
    this.snapshot = createSnapshot(account, context)
    return this.snapshot
  }

  isActive(): boolean {
    return this.snapshot !== null
  }

  getSnapshot(): SessionSnapshot {
    return this.snapshot ?? anonymousSnapshot()
  }

  enterTenant(tenantId: string): SessionSnapshot {
    if (this.snapshot === null) {
      return anonymousSnapshot()
    }
    if (this.snapshot.role !== 0) {
      return this.snapshot
    }
    const account: PreviewAccount = PREVIEW_ACCOUNTS[0]
    this.snapshot = createSnapshot(account, createManagedTenantContext(tenantId))
    return this.snapshot
  }

  returnToPlatform(): SessionSnapshot {
    if (this.snapshot === null) {
      return anonymousSnapshot()
    }
    if (this.snapshot.role !== 0) {
      return this.snapshot
    }
    const account: PreviewAccount = PREVIEW_ACCOUNTS[0]
    this.snapshot = createSnapshot(account, createPlatformContext())
    return this.snapshot
  }

  clear(): void {
    this.snapshot = null
  }
}
