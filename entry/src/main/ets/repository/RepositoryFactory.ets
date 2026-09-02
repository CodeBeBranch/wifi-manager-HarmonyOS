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
  MemberEntitlement,
  MemberLocationPermission,
  MemberLocationRecord,
  MemberOrder,
  MemberPayment,
  MemberProduct,
  MemberPurchase,
  MemberRefund,
  MemberSummary,
  MemberUsageRecord
} from '../model/Hm5Models'
import {
  TenantAnalyticsSnapshot,
  TenantGeofence,
  TenantGeofenceEvent,
  TenantGeofenceInput,
  TenantGisSnapshot,
  TenantLocation
} from '../model/Hm6Models'
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
import { DemoHm5MemberRepository, RealHm5MemberRepository } from './Hm5MemberRepository'
import { DemoHm6LocationRepository, RealHm6LocationRepository } from './Hm6LocationRepository'
import {
  DemoHm7CapabilityRepository,
  Hm7CapabilityRepositoryContract,
  RealHm7CapabilityRepository
} from './Hm7CapabilityRepository'

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

export interface Hm5MemberRepositoryContract {
  summary(): Promise<MemberSummary>
  entitlement(): Promise<MemberEntitlement>
  products(keyword: string): Promise<MemberProduct[]>
  purchases(): Promise<MemberPurchase[]>
  usage(): Promise<MemberUsageRecord[]>
  orders(): Promise<MemberOrder[]>
  orderDetail(id: string): Promise<MemberOrder>
  createOrder(productId: string): Promise<MemberOrder>
  cancelOrder(id: string): Promise<MemberOrder>
  paymentForOrder(orderId: string): Promise<MemberPayment | null>
  createPayment(orderId: string): Promise<MemberPayment>
  refunds(): Promise<MemberRefund[]>
  refundDetail(id: string): Promise<MemberRefund>
  applyRefund(orderId: string, reason: string): Promise<MemberRefund>
  locationPermission(): Promise<MemberLocationPermission>
  setLocationPermission(granted: boolean): Promise<MemberLocationPermission>
  locationHistory(): Promise<MemberLocationRecord[]>
  clearLocationHistory(): Promise<void>
  tenantRefunds(): Promise<MemberRefund[]>
  tenantRefundDetail(id: string): Promise<MemberRefund>
  reviewTenantRefund(id: string, approved: boolean, note: string): Promise<MemberRefund>
}

export interface Hm6LocationRepositoryContract {
  locations(keyword: string): Promise<TenantLocation[]>
  gis(): Promise<TenantGisSnapshot>
  geofences(keyword: string): Promise<TenantGeofence[]>
  geofenceDetail(id: number): Promise<TenantGeofence>
  saveGeofence(input: TenantGeofenceInput, id: number | null): Promise<TenantGeofence>
  toggleGeofence(id: number): Promise<TenantGeofence>
  deleteGeofence(id: number): Promise<void>
  geofenceEvents(geofenceId: number, keyword: string): Promise<TenantGeofenceEvent[]>
  analytics(): Promise<TenantAnalyticsSnapshot>
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

function currentMemberKey(): string {
  const snapshot = sessionStore.getSnapshot()
  if (!snapshot.authenticated || snapshot.role !== 2 || snapshot.userId.length === 0) {
    throw new ApiError('当前账号不是成员账号', 403, 403, 'MEMBER_ROLE_REQUIRED')
  }
  return `${currentTenantId()}|${snapshot.userId}`
}

function hasAuthority(authority: string): boolean {
  return sessionStore.getSnapshot().context?.authorities.includes(authority) ?? false
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

class DemoHm5MemberAdapter implements Hm5MemberRepositoryContract {
  private readonly data: DemoHm5MemberRepository

  constructor(data: DemoHm5MemberRepository) {
    this.data = data
  }

  async summary(): Promise<MemberSummary> { return this.data.summary(currentMemberKey()) }
  async entitlement(): Promise<MemberEntitlement> { return this.data.entitlement(currentMemberKey()) }
  async products(keyword: string): Promise<MemberProduct[]> {
    return this.data.products(currentMemberKey(), keyword)
  }
  async purchases(): Promise<MemberPurchase[]> { return this.data.purchases(currentMemberKey()) }
  async usage(): Promise<MemberUsageRecord[]> { return this.data.usage(currentMemberKey()) }
  async orders(): Promise<MemberOrder[]> { return this.data.orders(currentMemberKey()) }
  async orderDetail(id: string): Promise<MemberOrder> { return this.data.orderDetail(currentMemberKey(), id) }
  async createOrder(productId: string): Promise<MemberOrder> {
    return this.data.createOrder(currentMemberKey(), productId, hasAuthority('ORDER_SELF_WRITE'))
  }
  async cancelOrder(id: string): Promise<MemberOrder> {
    return this.data.cancelOrder(currentMemberKey(), id, hasAuthority('ORDER_SELF_WRITE'))
  }
  async paymentForOrder(orderId: string): Promise<MemberPayment | null> {
    return this.data.paymentForOrder(currentMemberKey(), orderId)
  }
  async createPayment(orderId: string): Promise<MemberPayment> {
    return this.data.createPayment(currentMemberKey(), orderId, hasAuthority('PAYMENT_SELF_WRITE'))
  }
  async refunds(): Promise<MemberRefund[]> { return this.data.refunds(currentMemberKey()) }
  async refundDetail(id: string): Promise<MemberRefund> {
    return this.data.refundDetail(currentMemberKey(), id)
  }
  async applyRefund(orderId: string, reason: string): Promise<MemberRefund> {
    return this.data.applyRefund(currentMemberKey(), orderId, reason, hasAuthority('REFUND_SELF_WRITE'))
  }
  async locationPermission(): Promise<MemberLocationPermission> {
    return this.data.locationPermission(currentMemberKey())
  }
  async setLocationPermission(granted: boolean): Promise<MemberLocationPermission> {
    return this.data.setLocationPermission(currentMemberKey(), granted, hasAuthority('LOCATION_SELF_WRITE'))
  }
  async locationHistory(): Promise<MemberLocationRecord[]> {
    return this.data.locationHistory(currentMemberKey())
  }
  async clearLocationHistory(): Promise<void> {
    this.data.clearLocationHistory(currentMemberKey(), hasAuthority('LOCATION_SELF_WRITE'))
  }
  async tenantRefunds(): Promise<MemberRefund[]> {
    requireAuthority('REFUND_REVIEW')
    return this.data.tenantRefunds(currentTenantId())
  }
  async tenantRefundDetail(id: string): Promise<MemberRefund> {
    requireAuthority('REFUND_REVIEW')
    return this.data.tenantRefundDetail(currentTenantId(), id)
  }
  async reviewTenantRefund(id: string, approved: boolean, note: string): Promise<MemberRefund> {
    return this.data.reviewTenantRefund(currentTenantId(), id, approved, note,
      hasAuthority('REFUND_REVIEW'))
  }
}

class RealHm5MemberAdapter implements Hm5MemberRepositoryContract {
  private readonly real: RealHm5MemberRepository = new RealHm5MemberRepository()

  async summary(): Promise<MemberSummary> { return this.real.summary() }
  async entitlement(): Promise<MemberEntitlement> { return this.real.entitlement() }
  async products(keyword: string): Promise<MemberProduct[]> { return this.real.products(keyword) }
  async purchases(): Promise<MemberPurchase[]> { return this.real.purchases() }
  async usage(): Promise<MemberUsageRecord[]> { return this.real.usage() }
  async orders(): Promise<MemberOrder[]> { return this.real.orders() }
  async orderDetail(id: string): Promise<MemberOrder> { return this.real.orderDetail(id) }
  async createOrder(productId: string): Promise<MemberOrder> { return this.real.createOrder(productId) }
  async cancelOrder(id: string): Promise<MemberOrder> { return this.real.cancelOrder(id) }
  async paymentForOrder(orderId: string): Promise<MemberPayment | null> {
    return this.real.paymentForOrder(orderId)
  }
  async createPayment(orderId: string): Promise<MemberPayment> { return this.real.createPayment(orderId) }
  async refunds(): Promise<MemberRefund[]> { return this.real.refunds() }
  async refundDetail(id: string): Promise<MemberRefund> { return this.real.refundDetail(id) }
  async applyRefund(orderId: string, reason: string): Promise<MemberRefund> {
    return this.real.applyRefund(orderId, reason)
  }
  async locationPermission(): Promise<MemberLocationPermission> {
    return this.real.locationPermission()
  }
  async setLocationPermission(granted: boolean): Promise<MemberLocationPermission> {
    return this.real.setLocationPermission(granted)
  }
  async locationHistory(): Promise<MemberLocationRecord[]> { return this.real.locationHistory() }
  async clearLocationHistory(): Promise<void> { return this.real.clearLocationHistory() }
  async tenantRefunds(): Promise<MemberRefund[]> { return this.real.tenantRefunds() }
  async tenantRefundDetail(id: string): Promise<MemberRefund> { return this.real.tenantRefundDetail(id) }
  async reviewTenantRefund(id: string, approved: boolean, note: string): Promise<MemberRefund> {
    return this.real.reviewTenantRefund(id, approved, note)
  }
}

class DemoHm6LocationAdapter implements Hm6LocationRepositoryContract {
  private readonly data: DemoHm6LocationRepository

  constructor(data: DemoHm6LocationRepository) {
    this.data = data
  }

  async locations(keyword: string): Promise<TenantLocation[]> {
    requireAuthority('LOCATION_READ')
    return this.data.locations(currentTenantId(), keyword)
  }
  async gis(): Promise<TenantGisSnapshot> {
    requireAuthority('LOCATION_READ')
    return this.data.gis(currentTenantId())
  }
  async geofences(keyword: string): Promise<TenantGeofence[]> {
    requireAuthority('GEOFENCE_READ')
    return this.data.geofences(currentTenantId(), keyword)
  }
  async geofenceDetail(id: number): Promise<TenantGeofence> {
    requireAuthority('GEOFENCE_READ')
    return this.data.geofenceDetail(currentTenantId(), id)
  }
  async saveGeofence(input: TenantGeofenceInput, id: number | null): Promise<TenantGeofence> {
    return this.data.saveGeofence(currentTenantId(), input, id, hasAuthority('GEOFENCE_WRITE'))
  }
  async toggleGeofence(id: number): Promise<TenantGeofence> {
    return this.data.toggleGeofence(currentTenantId(), id, hasAuthority('GEOFENCE_WRITE'))
  }
  async deleteGeofence(id: number): Promise<void> {
    this.data.deleteGeofence(currentTenantId(), id, hasAuthority('GEOFENCE_WRITE'))
  }
  async geofenceEvents(geofenceId: number, keyword: string): Promise<TenantGeofenceEvent[]> {
    requireAuthority('GEOFENCE_READ')
    return this.data.geofenceEvents(currentTenantId(), geofenceId, keyword)
  }
  async analytics(): Promise<TenantAnalyticsSnapshot> {
    requireAuthority('ANALYTICS_READ')
    return this.data.analytics(currentTenantId())
  }
}

class RealHm6LocationAdapter implements Hm6LocationRepositoryContract {
  private readonly real: RealHm6LocationRepository = new RealHm6LocationRepository()

  async locations(keyword: string): Promise<TenantLocation[]> { return this.real.locations(keyword) }
  async gis(): Promise<TenantGisSnapshot> { return this.real.gis() }
  async geofences(keyword: string): Promise<TenantGeofence[]> { return this.real.geofences(keyword) }
  async geofenceDetail(id: number): Promise<TenantGeofence> { return this.real.geofenceDetail(id) }
  async saveGeofence(input: TenantGeofenceInput, id: number | null): Promise<TenantGeofence> {
    return this.real.saveGeofence(input, id)
  }
  async toggleGeofence(id: number): Promise<TenantGeofence> { return this.real.toggleGeofence(id) }
  async deleteGeofence(id: number): Promise<void> { return this.real.deleteGeofence(id) }
  async geofenceEvents(geofenceId: number, keyword: string): Promise<TenantGeofenceEvent[]> {
    return this.real.geofenceEvents(geofenceId, keyword)
  }
  async analytics(): Promise<TenantAnalyticsSnapshot> { return this.real.analytics() }
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
  private readonly demoHm5 = new DemoHm5MemberRepository()
  private readonly demoHm6 = new DemoHm6LocationRepository()
  private readonly demoHm7 = new DemoHm7CapabilityRepository()
  private readonly demoAlert = new DemoAlertRepository(this.demoHm4)
  private readonly demoHm4Security = new DemoHm4SecurityAdapter(this.demoHm4)
  private readonly realHm4Security = new RealHm4SecurityAdapter()
  private readonly demoHm5Member = new DemoHm5MemberAdapter(this.demoHm5)
  private readonly realHm5Member = new RealHm5MemberAdapter()
  private readonly demoHm6Location = new DemoHm6LocationAdapter(this.demoHm6)
  private readonly realHm6Location = new RealHm6LocationAdapter()
  private readonly realHm7 = new RealHm7CapabilityRepository()
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

  hm5Member(): Hm5MemberRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoHm5Member : this.realHm5Member
  }

  hm6Location(): Hm6LocationRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoHm6Location : this.realHm6Location
  }

  hm7Capability(): Hm7CapabilityRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoHm7 : this.realHm7
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
    this.demoHm5.setScenario(scenario)
    this.demoHm6.setScenario(scenario)
    this.demoHm7.setScenario(scenario)
    this.demoAlertEvents.dispose()
  }

  async resetDemoTenantOps(): Promise<void> {
    this.demoTenantData.reset()
    await this.demoTenantOps.resetDemo()
    this.demoHm4.reset()
    this.demoHm5.reset()
    this.demoHm6.reset()
    this.demoHm7.reset()
    this.demoAlertEvents.dispose()
  }
}

export const repositoryFactory = new RepositoryFactory()
