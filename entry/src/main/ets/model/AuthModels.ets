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

export interface RegisterRequest {
  username: string
  password: string
  nickname: string
  email: string | null
  phone: string | null
  emailCode: string | null
  phoneCode: string | null
}

export interface RegisterResult {
  status: string
  message: string
  conflictFields: string[] | null
}

export interface ResetPasswordRequest {
  target: string
  code: string
  newPassword: string
}

export function isValidContact(value: string): boolean {
  const normalized = value.trim()
  return /^1[3-9]\d{9}$/.test(normalized) || /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalized)
}

export function isPhoneContact(value: string): boolean {
  return /^1[3-9]\d{9}$/.test(value.trim())
}

export function isEmailContact(value: string): boolean {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value.trim())
}

export function isValidVerifyCode(value: string): boolean {
  return /^[A-Za-z0-9]{6}$/.test(value.trim())
}

export function validateUsername(value: string): string {
  const normalized = value.trim()
  if (normalized.length < 3 || normalized.length > 20) {
    return '用户名长度需要在 3 到 20 位之间'
  }
  return ''
}

export function validateAccountPassword(value: string): string {
  if (value.length < 6 || value.length > 20) {
    return '密码长度需要在 6 到 20 位之间'
  }
  return ''
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
