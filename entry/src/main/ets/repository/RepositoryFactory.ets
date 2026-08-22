import { ApiError } from '../model/ApiModels'
import { AlertEvent, AlertPageResult, AlertQuery } from '../model/AlertModels'
import {
  AlertAnalytics,
  AlertRuleInput,
  Hm4DemoScenario,
  TenantAlertRule,
  TenantAuditRecord
} from '../model/Hm4Models'
import {
  DeviceCommandPageResult,
  DeviceCommandQuery,
  DeviceCommandRecord,
  DeviceCommandResult
} from '../model/DeviceCommandModels'
import { DeviceNode, DevicePageResult } from '../model/DeviceModels'
import { NetworkSession, SessionPageResult, SessionQuery } from '../model/SessionModels'
import { PlatformTenantPageResult } from '../model/TenantModels'
import { WifiConfigTask } from '../model/WifiConfigModels'
import {
  BlacklistEntry,
  BlacklistQuery,
  DeviceEditInput,
  DeviceSignalRecord,
  DeviceTrafficPoint,
  Hm3DemoScenario
} from '../model/Hm3Models'
import {
  previewTenantPage
} from '../preview/PreviewData'
import { runtimeModeStore } from '../preview/RuntimeMode'
import { DemoAlertEventSource, DemoAlertListener } from '../preview/DemoAlertEventSource'
import { alertRepository } from './AlertRepository'
import { deviceCommandRepository } from './DeviceCommandRepository'
import { deviceRepository } from './DeviceRepository'
import { sessionRepository } from './SessionRepository'
import { tenantRepository } from './TenantRepository'
import { wifiConfigRepository } from './WifiConfigRepository'
import { DemoTenantOpsRepository, RealTenantOpsRepository } from './TenantOpsRepository'
import { DemoTenantDataRepository } from './DemoTenantDataRepository'
import { sessionStore } from '../session/SessionStore'
import { DemoHm4SecurityRepository, RealHm4SecurityRepository } from './Hm4SecurityRepository'

export interface AlertRepositoryContract {
  list(query: AlertQuery): Promise<AlertPageResult>
  detail(id: number): Promise<AlertEvent>
  handle(id: number, expectedVersion?: number): Promise<void>
}

export interface Hm4SecurityRepositoryContract {
  listRules(keyword: string): Promise<TenantAlertRule[]>
  saveRule(input: AlertRuleInput, id: number | null): Promise<TenantAlertRule>
  toggleRule(id: number): Promise<TenantAlertRule>
  deleteRule(id: number): Promise<void>
  listAudits(keyword: string): Promise<TenantAuditRecord[]>
  auditDetail(id: number): Promise<TenantAuditRecord>
  analytics(): Promise<AlertAnalytics>
}

export interface DeviceRepositoryContract {
  list(current: number, size: number, keyword: string): Promise<DevicePageResult>
  detail(nodeId: string): Promise<DeviceNode>
  create(input: DeviceEditInput): Promise<DeviceNode>
  update(nodeId: string, input: DeviceEditInput): Promise<DeviceNode>
  delete(nodeId: string): Promise<DeviceNode>
  restore(nodeId: string): Promise<DeviceNode>
}

export interface SessionRepositoryContract {
  list(query: SessionQuery, admin: boolean): Promise<SessionPageResult>
  close(sessionId: number, admin: boolean): Promise<NetworkSession>
}

export interface TenantRepositoryContract {
  listPlatformTenants(current: number, size: number, keyword: string): Promise<PlatformTenantPageResult>
}

export interface DeviceCommandRepositoryContract {
  restart(deviceCode: string, reason: string): Promise<DeviceCommandResult>
  disconnectMac(deviceCode: string, mac: string): Promise<DeviceCommandResult>
  blockTraffic(deviceCode: string, dstIp: string, sni: string): Promise<DeviceCommandResult>
  list(query: DeviceCommandQuery): Promise<DeviceCommandPageResult>
  findByRequestId(deviceCode: string, requestId: string): Promise<DeviceCommandRecord | null>
}

export interface WifiConfigRepositoryContract {
  stage(deviceCode: string, ssid: string, password: string): Promise<WifiConfigTask>
  latest(deviceCode: string): Promise<WifiConfigTask | null>
  find(deviceCode: string, requestId: string): Promise<WifiConfigTask>
}

export interface BlacklistRepositoryContract {
  listBlacklist(tenantId: string, query: BlacklistQuery): Promise<BlacklistEntry[]>
  addBlacklist(tenantId: string, mac: string, reason: string): Promise<BlacklistEntry>
  removeBlacklist(tenantId: string, id: number): Promise<void>
  resetDemo(): Promise<void>
}

export interface DeviceMetricsRepositoryContract {
  listSignals(nodeId: string): Promise<DeviceSignalRecord[]>
  signalDetail(signalId: number): Promise<DeviceSignalRecord>
  listTraffic(nodeId: string): Promise<DeviceTrafficPoint[]>
}

function currentTenantId(): string {
  const snapshot = sessionStore.getSnapshot()
  const context = snapshot.context
  if (!snapshot.authenticated) {
    return 'preview-tenant-01'
  }
  if (!snapshot.authenticated || context === null ||
    (context.contextType !== 'TENANT' && context.contextType !== 'PLATFORM_TENANT') ||
    context.tenantId.length === 0) {
    throw new ApiError('当前租户上下文无效', 409, 409, 'TENANT_CONTEXT_REQUIRED')
  }
  return context.tenantId
}

function requireAuthority(authority: string): void {
  const context = sessionStore.getSnapshot().context
  if (context === null || !context.authorities.includes(authority)) {
    throw new ApiError('当前账号没有执行此操作的权限', 403, 403, 'AUTHORITY_REQUIRED')
  }
}

class DemoAlertRepository implements AlertRepositoryContract {
  private readonly data: DemoHm4SecurityRepository

  constructor(data: DemoHm4SecurityRepository) {
    this.data = data
  }

  async list(query: AlertQuery): Promise<AlertPageResult> {
    return this.data.listAlerts(currentTenantId(), query)
  }

  async detail(id: number): Promise<AlertEvent> {
    return this.data.alertDetail(currentTenantId(), id)
  }

  async handle(id: number, expectedVersion: number = 0): Promise<void> {
    requireAuthority('ALERT_HANDLE')
    const snapshot = sessionStore.getSnapshot()
    this.data.handleAlert(
      currentTenantId(),
      id,
      snapshot.userId,
      true,
      expectedVersion
    )
  }
}

class DemoHm4SecurityAdapter implements Hm4SecurityRepositoryContract {
  private readonly data: DemoHm4SecurityRepository

  constructor(data: DemoHm4SecurityRepository) {
    this.data = data
  }

  async listRules(keyword: string): Promise<TenantAlertRule[]> {
    return this.data.listRules(currentTenantId(), keyword)
  }

  async saveRule(input: AlertRuleInput, id: number | null): Promise<TenantAlertRule> {
    const context = sessionStore.getSnapshot().context
    return this.data.saveRule(currentTenantId(), input, id, context?.authorities.includes('RULE_WRITE') ?? false)
  }

  async toggleRule(id: number): Promise<TenantAlertRule> {
    const context = sessionStore.getSnapshot().context
    return this.data.toggleRule(currentTenantId(), id, context?.authorities.includes('RULE_WRITE') ?? false)
  }

  async deleteRule(id: number): Promise<void> {
    const context = sessionStore.getSnapshot().context
    this.data.deleteRule(currentTenantId(), id, context?.authorities.includes('RULE_WRITE') ?? false)
  }

  async listAudits(keyword: string): Promise<TenantAuditRecord[]> {
    return this.data.listAudits(currentTenantId(), keyword)
  }

  async auditDetail(id: number): Promise<TenantAuditRecord> {
    return this.data.auditDetail(currentTenantId(), id)
  }

  async analytics(): Promise<AlertAnalytics> {
    return this.data.analytics(currentTenantId())
  }
}

class RealHm4SecurityAdapter implements Hm4SecurityRepositoryContract {
  private readonly real: RealHm4SecurityRepository = new RealHm4SecurityRepository()

  async listRules(keyword: string): Promise<TenantAlertRule[]> { return this.real.listRules(keyword) }
  async saveRule(input: AlertRuleInput, id: number | null): Promise<TenantAlertRule> {
    return this.real.saveRule(input, id)
  }
  async toggleRule(id: number): Promise<TenantAlertRule> { return this.real.toggleRule(id) }
  async deleteRule(id: number): Promise<void> { return this.real.deleteRule(id) }
  async listAudits(keyword: string): Promise<TenantAuditRecord[]> { return this.real.listAudits(keyword) }
  async auditDetail(id: number): Promise<TenantAuditRecord> { return this.real.auditDetail(id) }
  async analytics(): Promise<AlertAnalytics> { return this.real.analytics() }
}

class DemoDeviceRepository implements DeviceRepositoryContract {
  private readonly data: DemoTenantDataRepository

  constructor(data: DemoTenantDataRepository) {
    this.data = data
  }

  async list(current: number, size: number, keyword: string): Promise<DevicePageResult> {
    return this.data.listDevices(currentTenantId(), current, size, keyword)
  }

  async detail(nodeId: string): Promise<DeviceNode> {
    return this.data.deviceDetail(currentTenantId(), nodeId)
  }

  async create(input: DeviceEditInput): Promise<DeviceNode> {
    requireAuthority('DEVICE_WRITE')
    return this.data.createDevice(currentTenantId(), input)
  }

  async update(nodeId: string, input: DeviceEditInput): Promise<DeviceNode> {
    requireAuthority('DEVICE_WRITE')
    return this.data.updateDevice(currentTenantId(), nodeId, input)
  }

  async delete(nodeId: string): Promise<DeviceNode> {
    requireAuthority('DEVICE_WRITE')
    return this.data.deleteDevice(currentTenantId(), nodeId)
  }

  async restore(nodeId: string): Promise<DeviceNode> {
    requireAuthority('DEVICE_WRITE')
    return this.data.restoreDevice(currentTenantId(), nodeId)
  }
}

class RealDeviceRepositoryAdapter implements DeviceRepositoryContract {
  async list(current: number, size: number, keyword: string): Promise<DevicePageResult> {
    return deviceRepository.list(current, size, keyword)
  }

  async detail(nodeId: string): Promise<DeviceNode> {
    return deviceRepository.detail(nodeId)
  }

  private pending(): ApiError {
    return new ApiError('真实设备写接口等待联调', 503, 503, 'REAL_API_PENDING')
  }

  async create(_input: DeviceEditInput): Promise<DeviceNode> {
    throw this.pending()
  }

  async update(_nodeId: string, _input: DeviceEditInput): Promise<DeviceNode> {
    throw this.pending()
  }

  async delete(_nodeId: string): Promise<DeviceNode> {
    throw this.pending()
  }

  async restore(_nodeId: string): Promise<DeviceNode> {
    throw this.pending()
  }
}

class DemoSessionRepository implements SessionRepositoryContract {
  private readonly data: DemoTenantDataRepository

  constructor(data: DemoTenantDataRepository) {
    this.data = data
  }

  async list(query: SessionQuery, admin: boolean): Promise<SessionPageResult> {
    return this.data.listSessions(currentTenantId(), query, admin)
  }

  async close(sessionId: number, admin: boolean): Promise<NetworkSession> {
    requireAuthority(admin ? 'SESSION_REVOKE' : 'SESSION_SELF_READ')
    return this.data.closeSession(currentTenantId(), sessionId)
  }
}

class DemoTenantRepository implements TenantRepositoryContract {
  async listPlatformTenants(
    current: number,
    size: number,
    keyword: string
  ): Promise<PlatformTenantPageResult> {
    return previewTenantPage(current, size, keyword)
  }
}

class DemoDeviceCommandRepository implements DeviceCommandRepositoryContract {
  private readonly data: DemoTenantDataRepository

  constructor(data: DemoTenantDataRepository) {
    this.data = data
  }

  async restart(deviceCode: string, _reason: string): Promise<DeviceCommandResult> {
    requireAuthority('COMMAND_SUBMIT')
    return this.data.submitCommand(currentTenantId(), deviceCode, 'KICK', 'MANUAL_RESTART', null)
  }

  async disconnectMac(deviceCode: string, mac: string): Promise<DeviceCommandResult> {
    requireAuthority('COMMAND_SUBMIT')
    return this.data.submitCommand(
      currentTenantId(),
      deviceCode,
      'DISCONNECT_MAC',
      'MANUAL_DISCONNECT',
      mac.trim().toUpperCase()
    )
  }

  async blockTraffic(deviceCode: string, _dstIp: string, _sni: string): Promise<DeviceCommandResult> {
    requireAuthority('COMMAND_SUBMIT')
    return this.data.submitCommand(currentTenantId(), deviceCode, 'BLOCK_TRAFFIC', 'MANUAL_BLOCK', null)
  }

  async list(query: DeviceCommandQuery): Promise<DeviceCommandPageResult> {
    return this.data.listCommands(currentTenantId(), query)
  }

  async findByRequestId(deviceCode: string, requestId: string): Promise<DeviceCommandRecord | null> {
    return this.data.findCommand(currentTenantId(), deviceCode, requestId)
  }
}

class DemoWifiConfigRepository implements WifiConfigRepositoryContract {
  private readonly data: DemoTenantDataRepository

  constructor(data: DemoTenantDataRepository) {
    this.data = data
  }

  async stage(deviceCode: string, ssid: string, password: string): Promise<WifiConfigTask> {
    requireAuthority('WIFI_CONFIG_SUBMIT')
    return this.data.stageWifi(currentTenantId(), deviceCode, ssid, password)
  }

  async latest(deviceCode: string): Promise<WifiConfigTask | null> {
    return this.data.latestWifi(currentTenantId(), deviceCode)
  }

  async find(deviceCode: string, requestId: string): Promise<WifiConfigTask> {
    return this.data.findWifi(currentTenantId(), deviceCode, requestId)
  }
}

class DemoDeviceMetricsRepository implements DeviceMetricsRepositoryContract {
  private readonly data: DemoTenantDataRepository

  constructor(data: DemoTenantDataRepository) {
    this.data = data
  }

  async listSignals(nodeId: string): Promise<DeviceSignalRecord[]> {
    return this.data.listSignals(currentTenantId(), nodeId)
  }

  async signalDetail(signalId: number): Promise<DeviceSignalRecord> {
    return this.data.signalDetail(currentTenantId(), signalId)
  }

  async listTraffic(nodeId: string): Promise<DeviceTrafficPoint[]> {
    return this.data.listTraffic(currentTenantId(), nodeId)
  }
}

class RealDeviceMetricsRepository implements DeviceMetricsRepositoryContract {
  private pending(): ApiError {
    return new ApiError('真实信号与流量接口等待联调', 503, 503, 'REAL_API_PENDING')
  }

  async listSignals(_nodeId: string): Promise<DeviceSignalRecord[]> {
    throw this.pending()
  }

  async signalDetail(_signalId: number): Promise<DeviceSignalRecord> {
    throw this.pending()
  }

  async listTraffic(_nodeId: string): Promise<DeviceTrafficPoint[]> {
    throw this.pending()
  }
}

class RepositoryFactory {
  private readonly demoTenantData = new DemoTenantDataRepository()
  private readonly demoHm4 = new DemoHm4SecurityRepository()
  private readonly demoAlert = new DemoAlertRepository(this.demoHm4)
  private readonly demoHm4Security = new DemoHm4SecurityAdapter(this.demoHm4)
  private readonly realHm4Security = new RealHm4SecurityAdapter()
  private readonly demoAlertEvents = new DemoAlertEventSource()
  private readonly demoDevice = new DemoDeviceRepository(this.demoTenantData)
  private readonly realDevice = new RealDeviceRepositoryAdapter()
  private readonly demoSession = new DemoSessionRepository(this.demoTenantData)
  private readonly demoTenant = new DemoTenantRepository()
  private readonly demoCommand = new DemoDeviceCommandRepository(this.demoTenantData)
  private readonly demoWifi = new DemoWifiConfigRepository(this.demoTenantData)
  private readonly demoMetrics = new DemoDeviceMetricsRepository(this.demoTenantData)
  private readonly realMetrics = new RealDeviceMetricsRepository()
  private readonly demoTenantOps = new DemoTenantOpsRepository()
  private readonly realTenantOps = new RealTenantOpsRepository()

  constructor() {
    runtimeModeStore.addListener(() => this.demoAlertEvents.dispose())
  }

  alert(): AlertRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoAlert : alertRepository
  }

  hm4Security(): Hm4SecurityRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoHm4Security : this.realHm4Security
  }

  startDemoAlertEvents(listener: DemoAlertListener): void {
    if (!runtimeModeStore.isDemo()) return
    this.demoAlertEvents.start(currentTenantId(), this.demoHm4.getScenario(), this.demoHm4, listener)
  }

  replayDemoAlertEvents(): void {
    if (!runtimeModeStore.isDemo()) return
    this.demoAlertEvents.replay(this.demoHm4)
  }

  stopDemoAlertEvents(): void {
    this.demoAlertEvents.dispose()
  }

  device(): DeviceRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoDevice : this.realDevice
  }

  session(): SessionRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoSession : sessionRepository
  }

  tenant(): TenantRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoTenant : tenantRepository
  }

  deviceCommand(): DeviceCommandRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoCommand : deviceCommandRepository
  }

  wifiConfig(): WifiConfigRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoWifi : wifiConfigRepository
  }

  blacklist(): BlacklistRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoTenantOps : this.realTenantOps
  }

  deviceMetrics(): DeviceMetricsRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoMetrics : this.realMetrics
  }

  demoScenario(): Hm3DemoScenario {
    return this.demoTenantData.demoScenario()
  }

  setDemoScenario(scenario: Hm3DemoScenario): void {
    this.demoTenantData.setDemoScenario(scenario)
    this.demoHm4.setScenario(scenario as Hm4DemoScenario)
    this.demoAlertEvents.dispose()
  }

  async resetDemoTenantOps(): Promise<void> {
    this.demoTenantData.reset()
    await this.demoTenantOps.resetDemo()
    this.demoHm4.reset()
    this.demoAlertEvents.dispose()
  }
}

export const repositoryFactory = new RepositoryFactory()
