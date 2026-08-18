import { AlertEvent, AlertPageResult, AlertQuery } from '../model/AlertModels'
import {
  DeviceCommandPageResult,
  DeviceCommandQuery,
  DeviceCommandRecord
} from '../model/DeviceCommandModels'
import { DeviceNode, DevicePageResult } from '../model/DeviceModels'
import { NetworkSession, SessionPageResult, SessionQuery } from '../model/SessionModels'
import { PlatformTenant, PlatformTenantPageResult } from '../model/TenantModels'
import { WifiConfigTask } from '../model/WifiConfigModels'

const DEVICES: DeviceNode[] = [
  {
    nodeId: 101,
    deviceCode: 'EDGE-SH-01',
    name: '上海办公室主网关',
    location: '上海 · 浦东办公区',
    latitude: 31.2304,
    longitude: 121.4737,
    ip: '192.168.10.1',
    status: 1,
    firmwareVersion: '1.0.4',
    wifiStatus: 'CONNECTED',
    maxClients: 64,
    currentClients: 18,
    lastHeartbeat: '2026-08-18T14:26:31',
    rssiAtOneMeter: -41,
    pathLossExponent: 2.2,
    createTime: '2026-07-12T09:20:00',
    updateTime: '2026-08-18T14:26:31'
  },
  {
    nodeId: 102,
    deviceCode: 'EDGE-SZ-02',
    name: '深圳研发区网关',
    location: '深圳 · 研发实验室',
    latitude: 22.5431,
    longitude: 114.0579,
    ip: '192.168.20.1',
    status: 1,
    firmwareVersion: '1.0.4',
    wifiStatus: 'CONNECTED',
    maxClients: 48,
    currentClients: 11,
    lastHeartbeat: '2026-08-18T14:26:18',
    rssiAtOneMeter: -44,
    pathLossExponent: 2.4,
    createTime: '2026-07-20T13:40:00',
    updateTime: '2026-08-18T14:26:18'
  },
  {
    nodeId: 103,
    deviceCode: 'EDGE-HZ-03',
    name: '杭州访客网络',
    location: '杭州 · 一层接待区',
    latitude: 30.2741,
    longitude: 120.1551,
    ip: '192.168.30.1',
    status: 0,
    firmwareVersion: '1.0.3',
    wifiStatus: 'DISCONNECTED',
    maxClients: 32,
    currentClients: 0,
    lastHeartbeat: '2026-08-18T12:08:44',
    rssiAtOneMeter: -47,
    pathLossExponent: 2.7,
    createTime: '2026-08-02T10:15:00',
    updateTime: '2026-08-18T12:08:44'
  }
]

const SESSIONS: NetworkSession[] = [
  {
    sessionId: 8801,
    userId: 201,
    nodeId: 101,
    replacedSessionId: null,
    mac: '34:12:98:AB:70:21',
    ip: '192.168.10.36',
    deviceInfo: 'HarmonyOS Phone',
    loginTime: '2026-08-18T13:42:10',
    expireTime: '2026-08-18T21:42:10',
    logoutTime: null,
    status: 1,
    bytesUp: 18432000,
    bytesDown: 126877696
  },
  {
    sessionId: 8802,
    userId: 207,
    nodeId: 102,
    replacedSessionId: null,
    mac: '88:4A:EA:16:52:0C',
    ip: '192.168.20.57',
    deviceInfo: 'Windows 11 Notebook',
    loginTime: '2026-08-18T11:16:52',
    expireTime: '2026-08-18T19:16:52',
    logoutTime: null,
    status: 1,
    bytesUp: 79691776,
    bytesDown: 602931200
  },
  {
    sessionId: 8794,
    userId: null,
    nodeId: 101,
    replacedSessionId: null,
    mac: 'A0:B1:C2:D3:E4:F5',
    ip: '192.168.10.89',
    deviceInfo: 'Guest Device',
    loginTime: '2026-08-18T09:03:11',
    expireTime: '2026-08-18T11:03:11',
    logoutTime: '2026-08-18T10:48:37',
    status: 0,
    bytesUp: 7340032,
    bytesDown: 30408704
  }
]

const ALERTS: AlertEvent[] = [
  {
    id: 5101,
    level: 3,
    ruleCode: 'BLOCKED_DOMAIN',
    title: '检测到受限域名访问',
    mac: '88:4A:EA:16:52:0C',
    userId: 207,
    detail: '终端连续访问策略限制域名，流量已被网关阻断。',
    status: 0,
    handleUserId: null,
    handleTime: null,
    createTime: '2026-08-18T14:18:09'
  },
  {
    id: 5102,
    level: 2,
    ruleCode: 'DEVICE_OFFLINE',
    title: '杭州访客网关离线',
    mac: '',
    userId: null,
    detail: '设备 EDGE-HZ-03 已超过心跳容忍时间，请检查供电和上游网络。',
    status: 0,
    handleUserId: null,
    handleTime: null,
    createTime: '2026-08-18T12:10:44'
  },
  {
    id: 5096,
    level: 1,
    ruleCode: 'HIGH_TRAFFIC',
    title: '终端下行流量较高',
    mac: '34:12:98:AB:70:21',
    userId: 201,
    detail: '终端在最近 30 分钟内产生较高下行流量，已记录用于后续观察。',
    status: 1,
    handleUserId: 1,
    handleTime: '2026-08-18T11:28:03',
    createTime: '2026-08-18T11:03:24'
  }
]

const TENANTS: PlatformTenant[] = [
  {
    tenantId: 'preview-tenant-01',
    tenantCode: 'edge-lab',
    name: '边缘网络实验室',
    status: 'ACTIVE',
    timezone: 'Asia/Shanghai',
    ownerUserId: '1001',
    contextVersion: 3,
    version: 6,
    memberCount: 24,
    subscriptionStatus: 'ACTIVE',
    createTime: '2026-06-18T09:00:00',
    updateTime: '2026-08-18T10:12:00'
  },
  {
    tenantId: 'preview-tenant-02',
    tenantCode: 'branch-office',
    name: '分部办公网络',
    status: 'ACTIVE',
    timezone: 'Asia/Shanghai',
    ownerUserId: '1008',
    contextVersion: 2,
    version: 3,
    memberCount: 11,
    subscriptionStatus: 'ACTIVE',
    createTime: '2026-07-08T14:30:00',
    updateTime: '2026-08-17T18:40:00'
  }
]

const COMMANDS: DeviceCommandRecord[] = [
  {
    commandId: 9201,
    requestId: 'preview-command-9201',
    nodeId: 101,
    deviceCode: 'EDGE-SH-01',
    commandType: 'DISCONNECT_MAC',
    purpose: 'MANUAL_DISCONNECT',
    sessionId: 8790,
    mac: '54:7F:EE:20:19:AD',
    alertId: null,
    ttlSeconds: 60,
    topic: '',
    payload: '',
    status: 2,
    retryCount: 0,
    nextRetryTime: null,
    publishTime: '2026-08-18T10:22:10',
    deadlineTime: '2026-08-18T10:23:10',
    resultTime: '2026-08-18T10:22:12',
    resultMessage: 'terminal disconnected',
    createTime: '2026-08-18T10:22:09',
    updateTime: '2026-08-18T10:22:12'
  },
  {
    commandId: 9198,
    requestId: 'preview-command-9198',
    nodeId: 101,
    deviceCode: 'EDGE-SH-01',
    commandType: 'KICK',
    purpose: 'MANUAL_RESTART',
    sessionId: null,
    mac: null,
    alertId: null,
    ttlSeconds: 90,
    topic: '',
    payload: '',
    status: 2,
    retryCount: 0,
    nextRetryTime: null,
    publishTime: '2026-08-17T18:06:30',
    deadlineTime: '2026-08-17T18:08:00',
    resultTime: '2026-08-17T18:06:38',
    resultMessage: 'device restarted',
    createTime: '2026-08-17T18:06:29',
    updateTime: '2026-08-17T18:06:38'
  },
  {
    commandId: 9184,
    requestId: 'preview-command-9184',
    nodeId: 102,
    deviceCode: 'EDGE-SZ-02',
    commandType: 'BLOCK_TRAFFIC',
    purpose: 'MANUAL_BLOCK',
    sessionId: null,
    mac: null,
    alertId: 5078,
    ttlSeconds: 120,
    topic: '',
    payload: '',
    status: 5,
    retryCount: 1,
    nextRetryTime: null,
    publishTime: '2026-08-16T16:41:02',
    deadlineTime: '2026-08-16T16:43:02',
    resultTime: null,
    resultMessage: 'result timeout',
    createTime: '2026-08-16T16:41:01',
    updateTime: '2026-08-16T16:43:03'
  }
]

function normalizedPage(current: number): number {
  return Number.isInteger(current) && current > 0 ? current : 1
}

function normalizedSize(size: number): number {
  return Number.isInteger(size) && size > 0 ? size : 20
}

export function previewDevicePage(current: number, size: number, keyword: string): DevicePageResult {
  const normalizedKeyword = keyword.trim().toLowerCase()
  const filtered = normalizedKeyword.length === 0
    ? DEVICES
    : DEVICES.filter((device: DeviceNode): boolean =>
      device.name.toLowerCase().includes(normalizedKeyword) ||
      device.deviceCode.toLowerCase().includes(normalizedKeyword) ||
      device.location.toLowerCase().includes(normalizedKeyword))
  const page = normalizedPage(current)
  const pageSize = normalizedSize(size)
  const start = (page - 1) * pageSize
  return {
    total: filtered.length,
    current: page,
    size: pageSize,
    records: filtered.slice(start, start + pageSize)
  }
}

export function previewDeviceDetail(nodeId: string): DeviceNode | null {
  const normalized = Number(nodeId)
  return DEVICES.find((device: DeviceNode): boolean => device.nodeId === normalized) ?? null
}

export function previewSessionPage(query: SessionQuery, admin: boolean = true): SessionPageResult {
  const mac = query.mac.trim().toUpperCase()
  const nodeId = query.nodeId.trim()
  const userId = query.userId.trim()
  const filtered = SESSIONS.filter((session: NetworkSession): boolean =>
    (admin || session.userId === 201) &&
    (mac.length === 0 || session.mac.includes(mac)) &&
    (nodeId.length === 0 || String(session.nodeId ?? '') === nodeId) &&
    (userId.length === 0 || String(session.userId ?? '') === userId) &&
    (query.status.length === 0 || String(session.status) === query.status))
  const page = normalizedPage(query.current)
  const pageSize = normalizedSize(query.size)
  const start = (page - 1) * pageSize
  return {
    total: filtered.length,
    current: page,
    size: pageSize,
    records: filtered.slice(start, start + pageSize)
  }
}

export function previewAlertPage(query: AlertQuery): AlertPageResult {
  const mac = query.mac.trim().toUpperCase()
  const filtered = ALERTS.filter((alert: AlertEvent): boolean =>
    (mac.length === 0 || alert.mac.includes(mac)) &&
    (query.level.length === 0 || String(alert.level) === query.level) &&
    (query.status.length === 0 || String(alert.status) === query.status))
  const page = normalizedPage(query.current)
  const pageSize = normalizedSize(query.size)
  const start = (page - 1) * pageSize
  return {
    total: filtered.length,
    current: page,
    size: pageSize,
    records: filtered.slice(start, start + pageSize)
  }
}

export function previewAlertDetail(id: number): AlertEvent | null {
  return ALERTS.find((alert: AlertEvent): boolean => alert.id === id) ?? null
}

export function previewTenantPage(
  current: number,
  size: number,
  keyword: string
): PlatformTenantPageResult {
  const normalizedKeyword = keyword.trim().toLowerCase()
  const filtered = normalizedKeyword.length === 0
    ? TENANTS
    : TENANTS.filter((tenant: PlatformTenant): boolean =>
      tenant.name.toLowerCase().includes(normalizedKeyword) ||
      tenant.tenantCode.toLowerCase().includes(normalizedKeyword))
  const page = normalizedPage(current)
  const pageSize = normalizedSize(size)
  const start = (page - 1) * pageSize
  return {
    total: filtered.length,
    current: page,
    size: pageSize,
    records: filtered.slice(start, start + pageSize)
  }
}

export function previewDeviceCommandPage(query: DeviceCommandQuery): DeviceCommandPageResult {
  const requestId = query.requestId.trim()
  const deviceCode = query.deviceCode.trim()
  const filtered = COMMANDS.filter((record: DeviceCommandRecord): boolean =>
    (requestId.length === 0 || record.requestId === requestId) &&
    (deviceCode.length === 0 || record.deviceCode === deviceCode))
  const page = normalizedPage(query.current)
  const pageSize = normalizedSize(query.size)
  const start = (page - 1) * pageSize
  return {
    total: filtered.length,
    current: page,
    size: pageSize,
    records: filtered.slice(start, start + pageSize)
  }
}

export function previewLatestWifiConfig(deviceCode: string): WifiConfigTask | null {
  if (deviceCode !== 'EDGE-SH-01' && deviceCode !== 'EDGE-SZ-02') {
    return null
  }
  return {
    wifiConfigId: deviceCode === 'EDGE-SH-01' ? 7301 : 7302,
    nodeId: deviceCode === 'EDGE-SH-01' ? 101 : 102,
    deviceCode: deviceCode,
    requestId: deviceCode === 'EDGE-SH-01' ? 'preview-wifi-7301' : 'preview-wifi-7302',
    configVersion: deviceCode === 'EDGE-SH-01' ? 8 : 4,
    ssid: deviceCode === 'EDGE-SH-01' ? 'EdgeLab-Office' : 'EdgeLab-RD',
    passwordConfigured: true,
    status: 2,
    statusName: 'ACTIVATED',
    stagedTime: '2026-08-12T16:32:10',
    activatedTime: '2026-08-12T16:32:28',
    failureMessage: null,
    createTime: '2026-08-12T16:32:10',
    updateTime: '2026-08-12T16:32:28'
  }
}
