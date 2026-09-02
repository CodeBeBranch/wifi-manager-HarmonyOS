import http from '@ohos.net.http'
import { realApiPath, resolveRealApiPath } from '../config/RealApiCatalog'
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
import { persistentPreviewSnapshot, PreviewSession } from '../preview/PreviewMode'
import { RuntimeMode, runtimeModeStore } from '../preview/RuntimeMode'
import { realAuthRepository } from '../repository/AuthRepository'
import { appPreferences } from '../storage/AppPreferences'
import { runtimeSettings } from '../storage/RuntimeSettings'
import { secureStore } from '../storage/SecureStore'

const DEMO_SESSION_KEY = 'demo_session_v1'

export type SessionListener = (snapshot: SessionSnapshot) => void

export interface DemoSessionPreferenceStorage {
  getString(key: string, fallback?: string): Promise<string>
  putString(key: string, value: string): Promise<void>
  remove(key: string): Promise<void>
}

export class SessionStore {
  private session: StoredSession | null = null
  private refreshTask: Promise<void> | null = null
  private previewSession: PreviewSession = new PreviewSession()
  private listeners: SessionListener[] = []
  private demoSessionOperation: Promise<void> = Promise.resolve()
  private readonly demoPreferenceStorage: DemoSessionPreferenceStorage

  constructor(demoPreferenceStorage: DemoSessionPreferenceStorage = appPreferences) {
    this.demoPreferenceStorage = demoPreferenceStorage
  }

  async initialize(): Promise<void> {
    this.previewSession.clear()
    if (runtimeModeStore.isDemo()) {
      await this.waitForDemoSessionOperation()
      try {
        const serializedDemo = await this.demoPreferenceStorage.getString(DEMO_SESSION_KEY)
        if (serializedDemo.length > 0) {
          const demoSnapshot = JSON.parse(serializedDemo) as SessionSnapshot
          const persistentSnapshot = persistentPreviewSnapshot(demoSnapshot)
          if (!this.previewSession.restore(persistentSnapshot)) {
            await this.removePreferenceBestEffort(DEMO_SESSION_KEY)
          } else if (persistentSnapshot !== demoSnapshot) {
            await this.persistDemoSession(persistentSnapshot)
          }
        }
      } catch (_) {
        this.previewSession.clear()
        await this.removePreferenceBestEffort(DEMO_SESSION_KEY)
      }
      this.session = null
      this.publish()
      return
    }
    await this.loadRealSession()
    this.publish()
  }

  private async loadRealSession(): Promise<void> {
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
    if (runtimeModeStore.isDemo()) {
      return this.previewSession.isActive() ? 'active' : 'anonymous'
    }
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
    const previewSnapshot = this.previewSession.tryLogin(request)
    if (previewSnapshot !== null) {
      this.refreshTask = null
      runtimeModeStore.activateDemo()
      await runtimeModeStore.persistCurrentMode()
      await this.persistDemoSession(previewSnapshot)
      this.publish()
      return previewSnapshot
    }
    this.previewSession.clear()
    runtimeModeStore.activateReal()
    await runtimeModeStore.persistCurrentMode()
    await runtimeSettings.activateReal()
    const response = await realAuthRepository.login(request)
    return this.acceptLoginResponse(response)
  }

  async loginByCode(request: LoginByCodeRequest): Promise<SessionSnapshot> {
    const previewSnapshot = this.previewSession.tryLoginByCode(request)
    if (previewSnapshot !== null) {
      this.refreshTask = null
      runtimeModeStore.activateDemo()
      await runtimeModeStore.persistCurrentMode()
      await this.persistDemoSession(previewSnapshot)
      this.publish()
      return previewSnapshot
    }
    this.previewSession.clear()
    runtimeModeStore.activateReal()
    await runtimeModeStore.persistCurrentMode()
    await runtimeSettings.activateReal()
    const response = await realAuthRepository.loginByCode(request)
    return this.acceptLoginResponse(response)
  }

  async sendLoginCode(target: string): Promise<void> {
    if (this.previewSession.canSendCode(target)) {
      runtimeModeStore.activateDemo()
      await runtimeModeStore.persistCurrentMode()
      return
    }
    runtimeModeStore.activateReal()
    await runtimeModeStore.persistCurrentMode()
    await runtimeSettings.activateReal()
    await realAuthRepository.sendVerifyCode({
      target: target,
      scene: 'login'
    })
  }

  async enterPlatformTenant(tenantId: string, reason: string): Promise<SessionSnapshot> {
    if (runtimeModeStore.isDemo()) {
      if (!this.previewSession.isActive()) {
        throw new ApiError('请先登录', 401, 401, 'AUTHENTICATION_REQUIRED')
      }
      const previous = this.previewSession.getSnapshot()
      const snapshot = this.previewSession.enterTenant(tenantId)
      try {
        await this.persistDemoSession(snapshot)
      } catch (error) {
        this.previewSession.restore(previous)
        throw error instanceof Error ? error : new Error('演示会话保存失败')
      }
      this.publish()
      return snapshot
    }
    return this.switchContext(
      resolveRealApiPath('workspace.platformTenant', ['tenantId'], [tenantId]),
      JSON.stringify({ reason: reason.trim() }),
      'PLATFORM_TENANT',
      tenantId
    )
  }

  async returnPlatformContext(): Promise<SessionSnapshot> {
    if (runtimeModeStore.isDemo()) {
      if (!this.previewSession.isActive()) {
        throw new ApiError('请先登录', 401, 401, 'AUTHENTICATION_REQUIRED')
      }
      const previous = this.previewSession.getSnapshot()
      const snapshot = this.previewSession.returnToPlatform()
      try {
        await this.persistDemoSession(snapshot)
      } catch (error) {
        this.previewSession.restore(previous)
        throw error instanceof Error ? error : new Error('演示会话保存失败')
      }
      this.publish()
      return snapshot
    }
    return this.switchContext(realApiPath('workspace.platform'), undefined, 'PLATFORM', '')
  }

  async restoreWorkspaceSnapshot(snapshot: SessionSnapshot, reason: string): Promise<SessionSnapshot> {
    if (!snapshot.authenticated || snapshot.role !== 0 || snapshot.context === null) {
      throw new ApiError('工作区恢复目标无效', 409, 409, 'WORKSPACE_ROLLBACK_INVALID')
    }
    if (runtimeModeStore.isDemo()) {
      if (!this.previewSession.restore(snapshot)) {
        throw new ApiError('工作区恢复目标无效', 409, 409, 'WORKSPACE_ROLLBACK_INVALID')
      }
      try {
        await this.persistDemoSession(snapshot)
      } catch (error) {
        this.publish()
        throw error instanceof Error ? error : new Error('演示工作区恢复保存失败')
      }
      this.publish()
      return this.getSnapshot()
    }
    if (snapshot.context.contextType === 'PLATFORM_TENANT') {
      return this.enterPlatformTenant(snapshot.context.tenantId, reason)
    }
    if (snapshot.context.contextType === 'PLATFORM') {
      return this.returnPlatformContext()
    }
    throw new ApiError('工作区恢复目标无效', 409, 409, 'WORKSPACE_ROLLBACK_INVALID')
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
    if (runtimeModeStore.isDemo()) {
      this.previewSession.clear()
      this.publish()
      await this.removeDemoSession()
      return
    }
    const current = this.session
    let localClearError: Error | null = null
    try {
      await this.clearIfCurrent(current)
    } catch (error) {
      localClearError = new Error(error instanceof Error ? error.message : '本地登录状态清理失败')
    }
    try {
      if (current !== null && current.refreshCookie.length > 0) {
        await realAuthRepository.logout(current.refreshCookie)
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
    if (runtimeModeStore.isDemo()) {
      throw new ApiError(
        '本地预览为只读模式，不会向服务端提交请求',
        403,
        403,
        'PREVIEW_READ_ONLY'
      )
    }
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
    if (runtimeModeStore.isDemo()) {
      return this.previewSession.isActive()
        ? this.previewSession.getSnapshot()
        : anonymousSnapshot()
    }
    if (this.session === null) {
      return anonymousSnapshot()
    }
    return this.snapshotFromAuth(this.session.auth, true)
  }

  getAlertSocketCredentials(): AlertSocketCredentials | null {
    if (runtimeModeStore.isDemo()) {
      return null
    }
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

  isPreviewMode(): boolean {
    return runtimeModeStore.isDemo()
  }

  getRuntimeMode(): RuntimeMode {
    return runtimeModeStore.getMode()
  }

  addListener(listener: SessionListener): void {
    if (this.listeners.indexOf(listener) >= 0) {
      return
    }
    this.listeners.push(listener)
  }

  removeListener(listener: SessionListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }

  async activateRealMode(): Promise<SessionSnapshot> {
    this.previewSession.clear()
    runtimeModeStore.activateReal()
    await runtimeModeStore.persistCurrentMode()
    await runtimeSettings.activateReal()
    await this.loadRealSession()
    this.publish()
    return this.getSnapshot()
  }

  async updateDemoNickname(nickname: string): Promise<void> {
    if (!runtimeModeStore.isDemo() || !this.previewSession.isActive()) {
      return
    }
    const snapshot = this.previewSession.updateNickname(nickname.trim())
    await this.persistDemoSession(snapshot)
    this.publish()
  }

  async resetDemoSession(): Promise<void> {
    if (!runtimeModeStore.isDemo() || !this.previewSession.isActive()) {
      return
    }
    const snapshot = this.previewSession.resetCurrent()
    await this.persistDemoSession(snapshot)
    this.publish()
  }

  async refreshOnForeground(): Promise<void> {
    if (runtimeModeStore.isDemo() || this.session === null) {
      return
    }
    try {
      await this.refreshOnce()
    } catch (_) {
      // 401 会在 refresh 中清理会话；暂时性链路失败保留当前本地状态。
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
      const response = await realAuthRepository.refresh(current.refreshCookie)
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
    this.publish()
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
    this.publish()
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
    this.publish()
  }

  private async clear(): Promise<void> {
    this.session = null
    await secureStore.clearSession()
    this.publish()
  }

  private async clearIfCurrent(expected: StoredSession | null): Promise<void> {
    if (this.session !== expected) {
      return
    }
    await this.clear()
  }

  private async persistDemoSession(snapshot: SessionSnapshot): Promise<void> {
    const serialized = JSON.stringify(persistentPreviewSnapshot(snapshot))
    await this.enqueueDemoSessionOperation(async (): Promise<void> => {
      await this.demoPreferenceStorage.putString(DEMO_SESSION_KEY, serialized)
    })
  }

  private async removeDemoSession(): Promise<void> {
    await this.enqueueDemoSessionOperation(async (): Promise<void> => {
      await this.demoPreferenceStorage.remove(DEMO_SESSION_KEY)
    })
  }

  private async removePreferenceBestEffort(key: string): Promise<void> {
    try {
      await this.demoPreferenceStorage.remove(key)
    } catch (_) {
    }
  }

  private async waitForDemoSessionOperation(): Promise<void> {
    try {
      await this.demoSessionOperation
    } catch (_) {
    }
  }

  private async enqueueDemoSessionOperation(operation: () => Promise<void>): Promise<void> {
    const previous = this.demoSessionOperation
    this.demoSessionOperation = (async (): Promise<void> => {
      try {
        await previous
      } catch (_) {
      }
      await operation()
    })()
    await this.demoSessionOperation
  }

  private publish(): void {
    const snapshot = this.getSnapshot()
    for (const listener of this.listeners) {
      listener(snapshot)
    }
  }
}

export const sessionStore = new SessionStore()
