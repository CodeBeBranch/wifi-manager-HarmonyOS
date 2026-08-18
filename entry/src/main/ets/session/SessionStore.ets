import http from '@ohos.net.http'
import { ApiError, ApiSuccess } from '../model/ApiModels'
import {
  AlertSocketCredentials,
  anonymousSnapshot,
  AuthResult,
  LoginByCodeRequest,
  LoginRequest,
  SessionSnapshot,
  StoredSession
} from '../model/AuthModels'
import { httpClient } from '../network/HttpClient'
import { authRepository } from '../repository/AuthRepository'
import { secureStore } from '../storage/SecureStore'

class SessionStore {
  private session: StoredSession | null = null
  private refreshTask: Promise<void> | null = null

  async initialize(): Promise<void> {
    try {
      const serialized = await secureStore.readSession()
      if (serialized.length === 0) {
        this.session = null
        return
      }
      const parsed = JSON.parse(serialized) as StoredSession
      if (parsed.auth === null || parsed.refreshCookie === undefined ||
        typeof parsed.refreshCookie !== 'string') {
        throw new Error('本地会话格式无效')
      }
      this.session = parsed
    } catch (_) {
      this.session = null
      await secureStore.clearSession()
    }
  }

  async restore(): Promise<'active' | 'anonymous' | 'step-up' | 'unavailable'> {
    if (this.session === null || this.session.refreshCookie.length === 0) {
      return 'anonymous'
    }
    try {
      await this.refreshOnce()
      return 'active'
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 403 &&
        error.errorKey === 'REFRESH_STEP_UP_REQUIRED') {
        return 'step-up'
      }
      if (error instanceof ApiError && error.httpStatus === 401) {
        return 'anonymous'
      }
      return 'unavailable'
    }
  }

  async login(request: LoginRequest): Promise<SessionSnapshot> {
    const response = await authRepository.login(request)
    return this.acceptLoginResponse(response)
  }

  async loginByCode(request: LoginByCodeRequest): Promise<SessionSnapshot> {
    const response = await authRepository.loginByCode(request)
    return this.acceptLoginResponse(response)
  }

  async sendLoginCode(target: string): Promise<void> {
    await authRepository.sendVerifyCode({
      target: target,
      scene: 'login'
    })
  }

  async enterPlatformTenant(tenantId: string, reason: string): Promise<SessionSnapshot> {
    return this.switchContext(
      `/auth/platform-context/tenants/${encodeURIComponent(tenantId)}`,
      JSON.stringify({ reason: reason.trim() }),
      'PLATFORM_TENANT',
      tenantId
    )
  }

  async returnPlatformContext(): Promise<SessionSnapshot> {
    return this.switchContext('/auth/platform-context', undefined, 'PLATFORM', '')
  }

  private async switchContext(
    path: string,
    body: string | undefined,
    expectedType: string,
    expectedTenantId: string
  ): Promise<SessionSnapshot> {
    const response = await this.authorizedRequest<AuthResult>(http.RequestMethod.POST, path, body)
    const auth = response.data
    const context = auth.context
    if (auth.token === null || auth.token.length === 0 || context === null ||
      context.contextType !== expectedType ||
      (expectedTenantId.length > 0 && context.tenantId !== expectedTenantId)) {
      throw new ApiError('工作区切换响应无效', 502, 502,
        'DEPENDENCY_PROTOCOL_INVALID', response.requestId)
    }
    const current = this.requireSession()
    await this.replaceContextSession(current, auth)
    return this.getSnapshot()
  }

  private async acceptLoginResponse(response: ApiSuccess<AuthResult>): Promise<SessionSnapshot> {
    if (response.data.token === null || response.data.token.length === 0) {
      this.session = null
      await secureStore.clearSession()
      return this.snapshotFromAuth(response.data, false)
    }
    if (response.refreshCookie.length === 0) {
      throw new ApiError('登录成功，但服务未返回会话凭证', 502, 502,
        'DEPENDENCY_PROTOCOL_INVALID', response.requestId)
    }
    await this.replaceSession(response.data, response.refreshCookie)
    return this.getSnapshot()
  }

  async logout(): Promise<void> {
    const current = this.session
    let localClearError: Error | null = null
    try {
      await this.clearIfCurrent(current)
    } catch (error) {
      localClearError = new Error(error instanceof Error ? error.message : '本地登录状态清理失败')
    }
    try {
      if (current !== null && current.refreshCookie.length > 0) {
        await authRepository.logout(current.refreshCookie)
      }
    } catch (error) {
      if (error instanceof ApiError) {
        throw new ApiError(
          error.message,
          error.httpStatus,
          error.code,
          error.errorKey,
          error.requestId,
          error.retryAfter,
          error.retryable
        )
      }
      throw new Error(error instanceof Error ? error.message : '退出登录失败')
    }
    if (localClearError !== null) {
      throw localClearError
    }
  }

  async authorizedRequest<T>(
    method: http.RequestMethod,
    path: string,
    body?: string,
    customMethod?: string
  ): Promise<ApiSuccess<T>> {
    const current = this.requireSession()
    const failedToken = current.auth.token === null ? '' : current.auth.token
    try {
      return await httpClient.request<T>({
        method: method,
        customMethod: customMethod,
        path: path,
        body: body,
        accessToken: failedToken
      })
    } catch (error) {
      if (!(error instanceof ApiError) || error.httpStatus !== 401) {
        if (error instanceof ApiError) {
          throw new ApiError(
            error.message,
            error.httpStatus,
            error.code,
            error.errorKey,
            error.requestId,
            error.retryAfter,
            error.retryable
          )
        }
        throw new Error(error instanceof Error ? error.message : '请求失败')
      }
      const latestToken = this.session?.auth.token ?? ''
      if (latestToken.length === 0 || latestToken === failedToken) {
        await this.refreshOnce()
      }
      const refreshed = this.requireSession()
      try {
        return await httpClient.request<T>({
          method: method,
          customMethod: customMethod,
          path: path,
          body: body,
          accessToken: refreshed.auth.token === null ? '' : refreshed.auth.token
        })
      } catch (replayError) {
        if (replayError instanceof ApiError && replayError.httpStatus === 401) {
          await this.clearIfCurrent(refreshed)
        }
        if (replayError instanceof ApiError) {
          throw new ApiError(
            replayError.message,
            replayError.httpStatus,
            replayError.code,
            replayError.errorKey,
            replayError.requestId,
            replayError.retryAfter,
            replayError.retryable
          )
        }
        throw new Error(replayError instanceof Error ? replayError.message : '请求失败')
      }
    }
  }

  getSnapshot(): SessionSnapshot {
    if (this.session === null) {
      return anonymousSnapshot()
    }
    return this.snapshotFromAuth(this.session.auth, true)
  }

  getAlertSocketCredentials(): AlertSocketCredentials | null {
    if (this.session === null || this.session.auth.token === null ||
      this.session.auth.token.length === 0) {
      return null
    }
    const auth = this.session.auth
    const context = auth.context
    const admin = auth.role === 0 || auth.role === 1
    if (!admin || context === null || context.tenantId.length === 0 ||
      (context.contextType !== 'TENANT' && context.contextType !== 'PLATFORM_TENANT')) {
      return null
    }
    const accessToken = auth.token
    if (accessToken === null) return null
    return {
      accessToken: accessToken,
      tenantId: context.tenantId,
      contextType: context.contextType
    }
  }

  private snapshotFromAuth(auth: AuthResult, authenticated: boolean): SessionSnapshot {
    return {
      authenticated: authenticated,
      accountState: auth.accountState,
      userId: auth.userId,
      username: auth.username,
      nickname: auth.nickname,
      role: auth.role,
      context: auth.context
    }
  }

  private requireSession(): StoredSession {
    if (this.session === null || this.session.auth.token === null || this.session.auth.token.length === 0) {
      throw new ApiError('请先登录', 401, 401, 'AUTHENTICATION_REQUIRED')
    }
    return this.session
  }

  private async refreshOnce(): Promise<void> {
    if (this.refreshTask === null) {
      this.refreshTask = this.refresh().finally(() => {
        this.refreshTask = null
      })
    }
    await this.refreshTask
  }

  private async refresh(): Promise<void> {
    const current = this.session
    if (current === null || current.refreshCookie.length === 0) {
      throw new ApiError('登录状态已过期，请重新登录', 401, 401, 'SESSION_EXPIRED')
    }
    try {
      const response = await authRepository.refresh(current.refreshCookie)
      if (this.session !== current) {
        throw new ApiError('登录状态已经变更', 409, 409, 'SESSION_CHANGED')
      }
      if (response.refreshCookie.length === 0) {
        await this.clearIfCurrent(current)
        throw new ApiError('登录状态更新失败，服务未返回新会话凭证', 502, 502,
          'DEPENDENCY_PROTOCOL_INVALID', response.requestId)
      }
      if (response.data.token === null || response.data.token.length === 0) {
        await this.clearIfCurrent(current)
        throw new ApiError('刷新响应缺少 Access Token', 502, 502,
          'DEPENDENCY_PROTOCOL_INVALID', response.requestId)
      }
      await this.replaceRefreshedSession(current, response.data, response.refreshCookie)
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        await this.clearIfCurrent(current)
      }
      if (error instanceof ApiError) {
        throw new ApiError(
          error.message,
          error.httpStatus,
          error.code,
          error.errorKey,
          error.requestId,
          error.retryAfter,
          error.retryable
        )
      }
      throw new Error(error instanceof Error ? error.message : '登录状态更新失败')
    }
  }

  private async replaceSession(auth: AuthResult, refreshCookie: string): Promise<void> {
    const next: StoredSession = {
      auth: auth,
      refreshCookie: refreshCookie
    }
    await secureStore.writeSession(JSON.stringify(next))
    this.session = next
  }

  private async replaceRefreshedSession(
    expected: StoredSession,
    auth: AuthResult,
    refreshCookie: string
  ): Promise<void> {
    const next: StoredSession = {
      auth: auth,
      refreshCookie: refreshCookie
    }
    await secureStore.writeSession(JSON.stringify(next))
    if (this.session !== expected) {
      const latest = this.session
      if (latest === null) {
        await secureStore.clearSession()
      } else {
        await secureStore.writeSession(JSON.stringify(latest))
      }
      throw new ApiError('登录状态已经变更', 409, 409, 'SESSION_CHANGED')
    }
    this.session = next
  }

  private async replaceContextSession(expected: StoredSession, auth: AuthResult): Promise<void> {
    const next: StoredSession = {
      auth: auth,
      refreshCookie: expected.refreshCookie
    }
    await secureStore.writeSession(JSON.stringify(next))
    if (this.session !== expected) {
      const latest = this.session
      if (latest === null) {
        await secureStore.clearSession()
      } else {
        await secureStore.writeSession(JSON.stringify(latest))
      }
      throw new ApiError('登录状态已经变更', 409, 409, 'SESSION_CHANGED')
    }
    this.session = next
  }

  private async clear(): Promise<void> {
    this.session = null
    await secureStore.clearSession()
  }

  private async clearIfCurrent(expected: StoredSession | null): Promise<void> {
    if (this.session !== expected) {
      return
    }
    await this.clear()
  }
}

export const sessionStore = new SessionStore()
