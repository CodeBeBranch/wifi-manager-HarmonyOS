import { ApiError } from '../model/ApiModels'
import { AlertEvent, AlertPageResult, AlertQuery } from '../model/AlertModels'
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
  previewAlertDetail,
  previewAlertPage,
  previewTenantPage
} from '../preview/PreviewData'
import { runtimeModeStore } from '../preview/RuntimeMode'
import { alertRepository } from './AlertRepository'
import { deviceCommandRepository } from './DeviceCommandRepository'
import { deviceRepository } from './DeviceRepository'
import { sessionRepository } from './SessionRepository'
import { tenantRepository } from './TenantRepository'
import { wifiConfigRepository } from './WifiConfigRepository'
import { DemoTenantOpsRepository, RealTenantOpsRepository } from './TenantOpsRepository'
import { DemoTenantDataRepository } from './DemoTenantDataRepository'
import { sessionStore } from '../session/SessionStore'

export interface AlertRepositoryContract {
  list(query: AlertQuery): Promise<AlertPageResult>
  detail(id: number): Promise<AlertEvent>
  handle(id: number): Promise<void>
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

function demoWriteBlocked(): ApiError {
  return new ApiError(
    '当前演示阶段只展示本地状态，不会提交真实操作',
    403,
    403,
    'DEMO_OPERATION_NOT_AVAILABLE'
  )
}

class DemoAlertRepository implements AlertRepositoryContract {
  async list(query: AlertQuery): Promise<AlertPageResult> {
    return previewAlertPage(query)
  }

  async detail(id: number): Promise<AlertEvent> {
    const alert = previewAlertDetail(id)
    if (alert === null) {
      throw new ApiError('没有找到告警', 404, 404, 'ALERT_NOT_FOUND')
    }
    return alert
  }

  async handle(_id: number): Promise<void> {
    throw demoWriteBlocked()
  }
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
  private readonly demoAlert = new DemoAlertRepository()
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

  alert(): AlertRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoAlert : alertRepository
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
  }

  async resetDemoTenantOps(): Promise<void> {
    this.demoTenantData.reset()
    await this.demoTenantOps.resetDemo()
  }
}

export const repositoryFactory = new RepositoryFactory()
