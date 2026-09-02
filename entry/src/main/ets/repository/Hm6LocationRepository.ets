import http from '@ohos.net.http'
import { realApiPath, resolveRealApiPath } from '../config/RealApiCatalog'
import { ApiError } from '../model/ApiModels'
import { Hm3DemoScenario } from '../model/Hm3Models'
import {
  TenantAnalyticsSnapshot,
  TenantCoverageNode,
  TenantGeofence,
  TenantGeofenceEvent,
  TenantGeofenceInput,
  TenantGisSnapshot,
  TenantHeatPoint,
  TenantLocation,
  TenantSignalInsight,
  TenantStayPoint,
  TenantTrackPoint,
  TenantTrafficInsight
} from '../model/Hm6Models'
import { sessionStore } from '../session/SessionStore'

interface TenantHm6Data {
  locations: TenantLocation[]
  track: TenantTrackPoint[]
  stays: TenantStayPoint[]
  heat: TenantHeatPoint[]
  coverage: TenantCoverageNode[]
  geofences: TenantGeofence[]
  events: TenantGeofenceEvent[]
  signals: TenantSignalInsight[]
  traffic: TenantTrafficInsight[]
}

function cloneLocation(value: TenantLocation): TenantLocation {
  return {
    id: value.id, subjectId: value.subjectId, subjectName: value.subjectName,
    subjectType: value.subjectType, zoneName: value.zoneName, latitude: value.latitude,
    longitude: value.longitude, accuracyMeters: value.accuracyMeters, capturedAt: value.capturedAt
  }
}

function cloneTrack(value: TenantTrackPoint): TenantTrackPoint {
  return {
    id: value.id, sequence: value.sequence, latitude: value.latitude, longitude: value.longitude,
    zoneName: value.zoneName, capturedAt: value.capturedAt
  }
}

function cloneStay(value: TenantStayPoint): TenantStayPoint {
  return {
    id: value.id, zoneName: value.zoneName, durationMinutes: value.durationMinutes,
    latitude: value.latitude, longitude: value.longitude, startedAt: value.startedAt
  }
}

function cloneHeat(value: TenantHeatPoint): TenantHeatPoint {
  return {
    id: value.id, zoneName: value.zoneName, intensity: value.intensity,
    latitude: value.latitude, longitude: value.longitude
  }
}

function cloneCoverage(value: TenantCoverageNode): TenantCoverageNode {
  return {
    id: value.id, nodeName: value.nodeName, zoneName: value.zoneName,
    clientCount: value.clientCount, averageRssi: value.averageRssi,
    latitude: value.latitude, longitude: value.longitude
  }
}

function cloneGeofence(value: TenantGeofence): TenantGeofence {
  return {
    id: value.id, code: value.code, name: value.name, shape: value.shape,
    enabled: value.enabled, centerLatitude: value.centerLatitude,
    centerLongitude: value.centerLongitude, radiusMeters: value.radiusMeters,
    vertexCount: value.vertexCount, eventCount: value.eventCount, updatedAt: value.updatedAt
  }
}

function cloneEvent(value: TenantGeofenceEvent): TenantGeofenceEvent {
  return {
    id: value.id, geofenceId: value.geofenceId, geofenceName: value.geofenceName,
    eventType: value.eventType, subjectName: value.subjectName, zoneName: value.zoneName,
    accuracyMeters: value.accuracyMeters, occurredAt: value.occurredAt
  }
}

function cloneSignal(value: TenantSignalInsight): TenantSignalInsight {
  return {
    id: value.id, zoneName: value.zoneName, averageRssi: value.averageRssi,
    qualityLabel: value.qualityLabel, clientCount: value.clientCount
  }
}

function cloneTraffic(value: TenantTrafficInsight): TenantTrafficInsight {
  return {
    id: value.id, period: value.period, uploadMb: value.uploadMb,
    downloadMb: value.downloadMb, activeClients: value.activeClients
  }
}

function createTenantData(offset: number): TenantHm6Data {
  const suffix = offset === 0 ? 'A' : 'B'
  return {
    locations: [
      {
        id: 1200 + offset, subjectId: `MEMBER-${suffix}-01`, subjectName: '张晨',
        subjectType: 'MEMBER', zoneName: 'A 栋共享办公区', latitude: 31.2304,
        longitude: 121.4737, accuracyMeters: 8, capturedAt: '2026-09-01 10:24'
      },
      {
        id: 1201 + offset, subjectId: `EDGE-${suffix}-01`, subjectName: '一层边缘节点',
        subjectType: 'DEVICE', zoneName: '一层访客区', latitude: 31.2301,
        longitude: 121.4742, accuracyMeters: 5, capturedAt: '2026-09-01 10:23'
      },
      {
        id: 1202 + offset, subjectId: `MEMBER-${suffix}-02`, subjectName: '李妍',
        subjectType: 'MEMBER', zoneName: '二层会议区', latitude: 31.2308,
        longitude: 121.4733, accuracyMeters: 12, capturedAt: '2026-09-01 10:21'
      }
    ],
    track: [
      {
        id: 1300 + offset, sequence: 1, latitude: 31.2300, longitude: 121.4743,
        zoneName: '一层访客区', capturedAt: '10:02'
      },
      {
        id: 1301 + offset, sequence: 2, latitude: 31.2303, longitude: 121.4740,
        zoneName: 'A 栋共享办公区', capturedAt: '10:11'
      },
      {
        id: 1302 + offset, sequence: 3, latitude: 31.2307, longitude: 121.4734,
        zoneName: '二层会议区', capturedAt: '10:20'
      }
    ],
    stays: [
      {
        id: 1400 + offset, zoneName: 'A 栋共享办公区', durationMinutes: 46,
        latitude: 31.2304, longitude: 121.4737, startedAt: '09:18'
      },
      {
        id: 1401 + offset, zoneName: '二层会议区', durationMinutes: 28,
        latitude: 31.2308, longitude: 121.4733, startedAt: '10:02'
      }
    ],
    heat: [
      {
        id: 1500 + offset, zoneName: 'A 栋共享办公区', intensity: 92,
        latitude: 31.2304, longitude: 121.4737
      },
      {
        id: 1501 + offset, zoneName: '一层访客区', intensity: 64,
        latitude: 31.2301, longitude: 121.4742
      },
      {
        id: 1502 + offset, zoneName: '二层会议区', intensity: 48,
        latitude: 31.2308, longitude: 121.4733
      }
    ],
    coverage: [
      {
        id: 1600 + offset, nodeName: '一层边缘节点', zoneName: '一层访客区',
        clientCount: 14, averageRssi: -51, latitude: 31.2301, longitude: 121.4742
      },
      {
        id: 1601 + offset, nodeName: '二层边缘节点', zoneName: '二层会议区',
        clientCount: 9, averageRssi: -63, latitude: 31.2308, longitude: 121.4733
      }
    ],
    geofences: [
      {
        id: 1700 + offset, code: 'GEOFENCE-OFFICE', name: '办公区域',
        shape: 'POLYGON', enabled: true, centerLatitude: 31.2304,
        centerLongitude: 121.4737, radiusMeters: 0, vertexCount: 6,
        eventCount: 3, updatedAt: '2026-09-01 09:40'
      },
      {
        id: 1701 + offset, code: 'GEOFENCE-VISITOR', name: '访客停留区',
        shape: 'CIRCLE', enabled: false, centerLatitude: 31.2301,
        centerLongitude: 121.4742, radiusMeters: 80, vertexCount: 0,
        eventCount: 2, updatedAt: '2026-09-01 09:20'
      }
    ],
    events: [
      {
        id: 1800 + offset, geofenceId: 1700 + offset, geofenceName: '办公区域',
        eventType: 'ENTER', subjectName: '张晨', zoneName: 'A 栋共享办公区',
        accuracyMeters: 8, occurredAt: '2026-09-01 10:12'
      },
      {
        id: 1801 + offset, geofenceId: 1700 + offset, geofenceName: '办公区域',
        eventType: 'EXIT', subjectName: '李妍', zoneName: '二层会议区',
        accuracyMeters: 12, occurredAt: '2026-09-01 09:54'
      },
      {
        id: 1802 + offset, geofenceId: 1701 + offset, geofenceName: '访客停留区',
        eventType: 'ENTER', subjectName: '访客设备', zoneName: '一层访客区',
        accuracyMeters: 16, occurredAt: '2026-09-01 09:33'
      }
    ],
    signals: [
      {
        id: 1900 + offset, zoneName: 'A 栋共享办公区', averageRssi: -49,
        qualityLabel: '优秀', clientCount: 18
      },
      {
        id: 1901 + offset, zoneName: '一层访客区', averageRssi: -61,
        qualityLabel: '良好', clientCount: 11
      },
      {
        id: 1902 + offset, zoneName: '二层会议区', averageRssi: -72,
        qualityLabel: '需关注', clientCount: 7
      }
    ],
    traffic: [
      { id: 2000 + offset, period: '09:00', uploadMb: 420, downloadMb: 1380, activeClients: 21 },
      { id: 2001 + offset, period: '10:00', uploadMb: 560, downloadMb: 1840, activeClients: 29 },
      { id: 2002 + offset, period: '11:00', uploadMb: 310, downloadMb: 1120, activeClients: 18 }
    ]
  }
}

export class DemoHm6LocationRepository {
  private scenario: Hm3DemoScenario = 'NORMAL'
  private readonly tenants: Map<string, TenantHm6Data> = new Map<string, TenantHm6Data>()
  private nextGeofenceId: number = 1750

  private data(tenantId: string): TenantHm6Data {
    const key = tenantId.trim()
    if (key.length === 0) throw new ApiError('当前租户上下文无效', 409, 409, 'TENANT_CONTEXT_REQUIRED')
    const existing = this.tenants.get(key)
    if (existing !== undefined) return existing
    const created = createTenantData(this.tenants.size * 100)
    this.tenants.set(key, created)
    return created
  }

  private guardRead(): void {
    if (this.scenario === 'FORBIDDEN') {
      throw new ApiError('当前场景拒绝位置与分析数据访问', 403, 403, 'HM6_SCENARIO_FORBIDDEN')
    }
    if (this.scenario === 'RATE_LIMITED') {
      throw new ApiError('位置与分析请求过于频繁', 429, 429, 'HM6_SCENARIO_RATE_LIMITED', '', '3', true)
    }
    if (this.scenario === 'DEPENDENCY_DOWN') {
      throw new ApiError('位置与分析依赖暂不可用', 503, 503, 'HM6_SCENARIO_DEPENDENCY_DOWN', '', '', true)
    }
  }

  private guardWrite(authorized: boolean): void {
    this.guardRead()
    if (!authorized) {
      throw new ApiError('当前账号没有编辑围栏的权限', 403, 403, 'GEOFENCE_WRITE_FORBIDDEN')
    }
    if (this.scenario === 'CONFLICT') {
      throw new ApiError('围栏状态已变化，请刷新后重试', 409, 409, 'GEOFENCE_SCENARIO_CONFLICT')
    }
  }

  setScenario(scenario: Hm3DemoScenario): void { this.scenario = scenario }
  getScenario(): Hm3DemoScenario { return this.scenario }

  reset(): void {
    this.scenario = 'NORMAL'
    this.tenants.clear()
    this.nextGeofenceId = 1750
  }

  locations(tenantId: string, keyword: string): TenantLocation[] {
    this.guardRead()
    if (this.scenario === 'EMPTY' || this.scenario === 'FILTER_EMPTY') return []
    const normalized = keyword.trim().toUpperCase()
    return this.data(tenantId).locations.filter((item: TenantLocation): boolean =>
      normalized.length === 0 || item.subjectId.toUpperCase().includes(normalized) ||
      item.subjectName.toUpperCase().includes(normalized) ||
      item.zoneName.toUpperCase().includes(normalized)).map(cloneLocation)
  }

  gis(tenantId: string): TenantGisSnapshot {
    if (this.scenario === 'FORBIDDEN') {
      return {
        state: 'PERMISSION_DENIED', accuracyMeters: 0,
        track: [], stays: [], heat: [], coverage: []
      }
    }
    this.guardRead()
    if (this.scenario === 'EMPTY' || this.scenario === 'FILTER_EMPTY') {
      return { state: 'NO_DATA', accuracyMeters: 0, track: [], stays: [], heat: [], coverage: [] }
    }
    const data = this.data(tenantId)
    return {
      state: this.scenario === 'PARTIAL_FAILURE' ? 'LOW_ACCURACY' : 'READY',
      accuracyMeters: this.scenario === 'PARTIAL_FAILURE' ? 120 : 8,
      track: data.track.map(cloneTrack),
      stays: data.stays.map(cloneStay),
      heat: data.heat.map(cloneHeat),
      coverage: data.coverage.map(cloneCoverage)
    }
  }

  geofences(tenantId: string, keyword: string): TenantGeofence[] {
    this.guardRead()
    if (this.scenario === 'EMPTY' || this.scenario === 'FILTER_EMPTY') return []
    const normalized = keyword.trim().toUpperCase()
    return this.data(tenantId).geofences.filter((item: TenantGeofence): boolean =>
      normalized.length === 0 || item.code.includes(normalized) ||
      item.name.toUpperCase().includes(normalized)).map(cloneGeofence)
  }

  geofenceDetail(tenantId: string, id: number): TenantGeofence {
    this.guardRead()
    const item = this.data(tenantId).geofences.find((value: TenantGeofence): boolean => value.id === id)
    if (item === undefined) throw new ApiError('没有找到当前组织的围栏', 404, 404, 'GEOFENCE_NOT_FOUND')
    return cloneGeofence(item)
  }

  saveGeofence(tenantId: string, input: TenantGeofenceInput, id: number | null,
    authorized: boolean): TenantGeofence {
    this.guardWrite(authorized)
    const code = input.code.trim().toUpperCase()
    const name = input.name.trim()
    if (!/^[A-Z][A-Z0-9-]{2,39}$/.test(code) || name.length < 2 || name.length > 60 ||
      input.centerLatitude < -90 || input.centerLatitude > 90 ||
      input.centerLongitude < -180 || input.centerLongitude > 180 ||
      (input.shape === 'CIRCLE' && (input.radiusMeters < 20 || input.radiusMeters > 5000)) ||
      (input.shape === 'POLYGON' && (input.vertexCount < 3 || input.vertexCount > 20))) {
      throw new ApiError('围栏编码、名称或边界参数不符合要求', 400, 400, 'GEOFENCE_INPUT_INVALID')
    }
    const geofences = this.data(tenantId).geofences
    if (geofences.some((item: TenantGeofence): boolean => item.code === code && item.id !== id)) {
      throw new ApiError('围栏编码已存在', 409, 409, 'GEOFENCE_CODE_DUPLICATE')
    }
    let target: TenantGeofence | undefined
    if (id === null) {
      target = {
        id: this.nextGeofenceId++, code: code, name: name, shape: input.shape, enabled: true,
        centerLatitude: input.centerLatitude, centerLongitude: input.centerLongitude,
        radiusMeters: input.shape === 'CIRCLE' ? input.radiusMeters : 0,
        vertexCount: input.shape === 'POLYGON' ? input.vertexCount : 0,
        eventCount: 0, updatedAt: '2026-09-01 13:40'
      }
      geofences.unshift(target)
    } else {
      target = geofences.find((item: TenantGeofence): boolean => item.id === id)
      if (target === undefined) {
        throw new ApiError('没有找到当前组织的围栏', 404, 404, 'GEOFENCE_NOT_FOUND')
      }
      target.code = code
      target.name = name
      target.shape = input.shape
      target.centerLatitude = input.centerLatitude
      target.centerLongitude = input.centerLongitude
      target.radiusMeters = input.shape === 'CIRCLE' ? input.radiusMeters : 0
      target.vertexCount = input.shape === 'POLYGON' ? input.vertexCount : 0
      target.updatedAt = '2026-09-01 13:40'
    }
    return cloneGeofence(target)
  }

  toggleGeofence(tenantId: string, id: number, authorized: boolean): TenantGeofence {
    this.guardWrite(authorized)
    const target = this.data(tenantId).geofences
      .find((item: TenantGeofence): boolean => item.id === id)
    if (target === undefined) throw new ApiError('没有找到当前组织的围栏', 404, 404, 'GEOFENCE_NOT_FOUND')
    target.enabled = !target.enabled
    target.updatedAt = '2026-09-01 13:41'
    return cloneGeofence(target)
  }

  deleteGeofence(tenantId: string, id: number, authorized: boolean): void {
    this.guardWrite(authorized)
    const data = this.data(tenantId)
    const index = data.geofences.findIndex((item: TenantGeofence): boolean => item.id === id)
    if (index < 0) throw new ApiError('没有找到当前组织的围栏', 404, 404, 'GEOFENCE_NOT_FOUND')
    data.geofences.splice(index, 1)
    data.events = data.events.filter((item: TenantGeofenceEvent): boolean => item.geofenceId !== id)
  }

  geofenceEvents(tenantId: string, geofenceId: number, keyword: string): TenantGeofenceEvent[] {
    this.guardRead()
    if (this.scenario === 'EMPTY' || this.scenario === 'FILTER_EMPTY') return []
    const normalized = keyword.trim().toUpperCase()
    return this.data(tenantId).events.filter((item: TenantGeofenceEvent): boolean =>
      (geofenceId <= 0 || item.geofenceId === geofenceId) &&
      (normalized.length === 0 || item.subjectName.toUpperCase().includes(normalized) ||
        item.zoneName.toUpperCase().includes(normalized) ||
        item.eventType.includes(normalized))).map(cloneEvent)
  }

  analytics(tenantId: string): TenantAnalyticsSnapshot {
    this.guardRead()
    if (this.scenario === 'PARTIAL_FAILURE') {
      throw new ApiError('流量分析暂不可用，位置与围栏仍可查看', 502, 502, 'ANALYTICS_PARTIAL_FAILURE')
    }
    if (this.scenario === 'EMPTY' || this.scenario === 'FILTER_EMPTY') {
      return { averageRssi: 0, totalTrafficMb: 0, peakClients: 0, signals: [], traffic: [] }
    }
    const data = this.data(tenantId)
    const trafficTotal = data.traffic.reduce((sum: number, item: TenantTrafficInsight): number =>
      sum + item.uploadMb + item.downloadMb, 0)
    const peakClients = data.traffic.reduce((peak: number, item: TenantTrafficInsight): number =>
      Math.max(peak, item.activeClients), 0)
    const signalTotal = data.signals.reduce((sum: number, item: TenantSignalInsight): number =>
      sum + item.averageRssi, 0)
    return {
      averageRssi: Math.round(signalTotal / data.signals.length),
      totalTrafficMb: trafficTotal,
      peakClients: peakClients,
      signals: data.signals.map(cloneSignal),
      traffic: data.traffic.map(cloneTraffic)
    }
  }
}

export interface Hm6PageWire<T> {
  total: number
  current: number
  size: number
  records: T[]
}

export interface TenantLocationWire {
  id: number
  mac?: string
  userId?: number
  sessionId?: number
  nodeId?: number
  deviceCode?: string
  latitude: number
  longitude: number
  accuracy: number
  reportTime: string
}

export interface GeofenceWire {
  fenceId: number
  name: string
  centerLatitude: number
  centerLongitude: number
  radiusMeters: number
  enabled: number
  updateTime: string
}

export interface GeofenceEventWire {
  eventId: number
  fenceId: number
  fenceName: string
  userId?: number
  sessionId?: number
  deviceCode?: string
  mac?: string
  eventType: string
  eventTime: string
}

interface GeofenceBody {
  name: string
  centerLatitude: number
  centerLongitude: number
  radiusMeters: number
  enabled?: number
  description: string
}

export function mapHm6Location(value: TenantLocationWire): TenantLocation {
  const member = value.userId !== undefined
  const subjectId = member
    ? `USER-${value.userId}`
    : value.deviceCode ?? value.mac ?? `NODE-${value.nodeId ?? 0}`
  return {
    id: value.id,
    subjectId: subjectId,
    subjectName: member ? `成员 ${value.userId}` : value.deviceCode ?? value.mac ?? '边缘设备',
    subjectType: member ? 'MEMBER' : 'DEVICE',
    zoneName: value.deviceCode ?? value.mac ?? '已上报位置',
    latitude: value.latitude,
    longitude: value.longitude,
    accuracyMeters: value.accuracy,
    capturedAt: value.reportTime
  }
}

export function mapHm6Geofence(value: GeofenceWire): TenantGeofence {
  return {
    id: value.fenceId,
    code: String(value.fenceId),
    name: value.name,
    shape: 'CIRCLE',
    enabled: value.enabled === 1,
    centerLatitude: value.centerLatitude,
    centerLongitude: value.centerLongitude,
    radiusMeters: value.radiusMeters,
    vertexCount: 0,
    eventCount: 0,
    updatedAt: value.updateTime
  }
}

export function mapHm6GeofenceEvent(value: GeofenceEventWire): TenantGeofenceEvent {
  const subject = value.userId !== undefined
    ? `成员 ${value.userId}`
    : value.deviceCode ?? value.mac ?? `会话 ${value.sessionId ?? 0}`
  return {
    id: value.eventId,
    geofenceId: value.fenceId,
    geofenceName: value.fenceName,
    eventType: value.eventType === 'EXIT' ? 'EXIT' : 'ENTER',
    subjectName: subject,
    zoneName: value.fenceName,
    accuracyMeters: 0,
    occurredAt: value.eventTime
  }
}

export class RealHm6LocationRepository {
  private pending(message: string): ApiError {
    return new ApiError(message, 503, 503, 'REAL_API_PENDING')
  }

  private body(input: TenantGeofenceInput, includeEnabled: boolean): GeofenceBody {
    if (input.shape !== 'CIRCLE') {
      throw new ApiError('真实围栏接口当前仅支持圆形围栏', 409, 409,
        'REAL_GEOFENCE_SHAPE_UNSUPPORTED')
    }
    const body: GeofenceBody = {
      name: input.name,
      centerLatitude: input.centerLatitude,
      centerLongitude: input.centerLongitude,
      radiusMeters: input.radiusMeters,
      description: input.code
    }
    if (includeEnabled) body.enabled = 1
    return body
  }

  async locations(keyword: string): Promise<TenantLocation[]> {
    const response = await sessionStore.authorizedRequest<Hm6PageWire<TenantLocationWire>>(
      http.RequestMethod.GET, `${realApiPath('locations.admin')}?current=1&size=100`)
    const records = response.data.records.map(
      (item: TenantLocationWire): TenantLocation => mapHm6Location(item))
    const normalized = keyword.trim().toLowerCase()
    return normalized.length === 0
      ? records
      : records.filter((item: TenantLocation): boolean =>
        item.subjectId.toLowerCase().includes(normalized) ||
        item.subjectName.toLowerCase().includes(normalized) ||
        item.zoneName.toLowerCase().includes(normalized))
  }

  async gis(): Promise<TenantGisSnapshot> {
    throw this.pending('真实轨迹、停留点和热力图等待租户查询修复')
  }

  async geofences(keyword: string): Promise<TenantGeofence[]> {
    const normalized = keyword.trim()
    const suffix = normalized.length === 0 ? '' : `&keyword=${encodeURIComponent(normalized)}`
    const response = await sessionStore.authorizedRequest<Hm6PageWire<GeofenceWire>>(
      http.RequestMethod.GET, `${realApiPath('geofences.list')}?current=1&size=100${suffix}`)
    return response.data.records.map(
      (item: GeofenceWire): TenantGeofence => mapHm6Geofence(item))
  }

  async geofenceDetail(id: number): Promise<TenantGeofence> {
    const response = await sessionStore.authorizedRequest<GeofenceWire>(
      http.RequestMethod.GET, resolveRealApiPath(
        'geofences.detail', ['fenceId'], [String(id)]))
    return mapHm6Geofence(response.data)
  }

  async saveGeofence(input: TenantGeofenceInput, id: number | null): Promise<TenantGeofence> {
    const response = id === null
      ? await sessionStore.authorizedRequest<GeofenceWire>(
        http.RequestMethod.POST, realApiPath('geofences.list'), JSON.stringify(this.body(input, true)))
      : await sessionStore.authorizedRequest<GeofenceWire>(
        http.RequestMethod.PUT, resolveRealApiPath(
          'geofences.detail', ['fenceId'], [String(id)]), JSON.stringify(this.body(input, false)))
    return mapHm6Geofence(response.data)
  }

  async toggleGeofence(id: number): Promise<TenantGeofence> {
    const current = await this.geofenceDetail(id)
    const enabled = current.enabled ? 0 : 1
    const response = await sessionStore.authorizedRequest<GeofenceWire>(
      http.RequestMethod.POST,
      `${resolveRealApiPath('geofences.enabled', ['fenceId'], [String(id)])}?enabled=${enabled}`,
      undefined, 'PATCH')
    return mapHm6Geofence(response.data)
  }

  async deleteGeofence(id: number): Promise<void> {
    await sessionStore.authorizedRequest<Object | null>(
      http.RequestMethod.DELETE, resolveRealApiPath(
        'geofences.detail', ['fenceId'], [String(id)]))
  }

  async geofenceEvents(geofenceId: number, keyword: string): Promise<TenantGeofenceEvent[]> {
    const response = await sessionStore.authorizedRequest<Hm6PageWire<GeofenceEventWire>>(
      http.RequestMethod.GET,
      `${realApiPath('geofences.events')}?current=1&size=100&fenceId=${geofenceId}`)
    const records = response.data.records.map(
      (item: GeofenceEventWire): TenantGeofenceEvent => mapHm6GeofenceEvent(item))
    const normalized = keyword.trim().toLowerCase()
    return normalized.length === 0
      ? records
      : records.filter((item: TenantGeofenceEvent): boolean =>
        item.subjectName.toLowerCase().includes(normalized) ||
        item.eventType.toLowerCase().includes(normalized))
  }

  async analytics(): Promise<TenantAnalyticsSnapshot> {
    throw this.pending('真实 GIS 与租户分析等待租户查询修复')
  }
}
