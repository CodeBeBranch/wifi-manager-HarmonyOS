export interface LoginRequest {
  loginType: string
  account: string
  password: string
}

export interface LoginByCodeRequest {
  target: string
  code: string
}

export interface SendVerifyCodeRequest {
  target: string
  scene: string
}

export function isValidContact(value: string): boolean {
  const normalized = value.trim()
  return /^1[3-9]\d{9}$/.test(normalized) || /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalized)
}

export function isValidVerifyCode(value: string): boolean {
  return /^[A-Za-z0-9]{6}$/.test(value.trim())
}

export interface TenantContext {
  contextType: string
  tenantId: string
  tenantCode: string
  tenantName: string
  tenantRole: string
  contextVersion: number
  memberContextVersion: number
  tenantStatus: string
  writable: boolean
  authorities: string[]
}

export interface AuthResult {
  userId: string
  token: string | null
  username: string
  role: number
  nickname: string
  avatar: string
  accountState: string
  context: TenantContext | null
}

export interface StoredSession {
  auth: AuthResult
  refreshCookie: string
}

export interface AlertSocketCredentials {
  accessToken: string
  tenantId: string
  contextType: string
}

export interface SessionSnapshot {
  authenticated: boolean
  accountState: string
  userId: string
  username: string
  nickname: string
  role: number
  context: TenantContext | null
}

export function anonymousSnapshot(): SessionSnapshot {
  return {
    authenticated: false,
    accountState: '',
    userId: '',
    username: '',
    nickname: '',
    role: -1,
    context: null
  }
}
