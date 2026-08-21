import { ApiError } from '../model/ApiModels'
import {
  DeviceCommandPageResult,
  DeviceCommandQuery,
  DeviceCommandRecord,
  DeviceCommandResult
} from '../model/DeviceCommandModels'
import { DeviceNode, DevicePageResult } from '../model/DeviceModels'
import { NetworkSession, SessionPageResult, SessionQuery } from '../model/SessionModels'
import { WifiConfigTask } from '../model/WifiConfigModels'
import {
  DeviceEditInput,
  DeviceSignalRecord,
  DeviceTrafficPoint,
  Hm3DemoScenario
} from '../model/Hm3Models'
import {
  previewDeviceCommandPage,
  previewDevicePage,
  previewLatestWifiConfig,
  previewSessionPage
} from '../preview/PreviewData'

function copyDevice(device: DeviceNode): DeviceNode {
  return {
    nodeId: device.nodeId,
    deviceCode: device.deviceCode,
    name: device.name,
    location: device.location,
    latitude: device.latitude,
    longitude: device.longitude,
    ip: device.ip,
    status: device.status,
    firmwareVersion: device.firmwareVersion,
    wifiStatus: device.wifiStatus,
    maxClients: device.maxClients,
    currentClients: device.currentClients,
    lastHeartbeat: device.lastHeartbeat,
    rssiAtOneMeter: device.rssiAtOneMeter,
    pathLossExponent: device.pathLossExponent,
    createTime: device.createTime,
    updateTime: device.updateTime
  }
}

function copySession(session: NetworkSession): NetworkSession {
  return {
    sessionId: session.sessionId,
    userId: session.userId,
    nodeId: session.nodeId,
    replacedSessionId: session.replacedSessionId,
    mac: session.mac,
    ip: session.ip,
    deviceInfo: session.deviceInfo,
    loginTime: session.loginTime,
    expireTime: session.expireTime,
    logoutTime: session.logoutTime,
    status: session.status,
    bytesUp: session.bytesUp,
    bytesDown: session.bytesDown
  }
}

function copyCommand(record: DeviceCommandRecord): DeviceCommandRecord {
  return {
    commandId: record.commandId,
    requestId: record.requestId,
    nodeId: record.nodeId,
    deviceCode: record.deviceCode,
    commandType: record.commandType,
    purpose: record.purpose,
    sessionId: record.sessionId,
    mac: record.mac,
    alertId: record.alertId,
    ttlSeconds: record.ttlSeconds,
    topic: record.topic,
    payload: record.payload,
    status: record.status,
    retryCount: record.retryCount,
    nextRetryTime: record.nextRetryTime,
    publishTime: record.publishTime,
    deadlineTime: record.deadlineTime,
    resultTime: record.resultTime,
    resultMessage: record.resultMessage,
    createTime: record.createTime,
    updateTime: record.updateTime
  }
}

function copyWifi(task: WifiConfigTask): WifiConfigTask {
  return {
    wifiConfigId: task.wifiConfigId,
    nodeId: task.nodeId,
    deviceCode: task.deviceCode,
    requestId: task.requestId,
    configVersion: task.configVersion,
    ssid: task.ssid,
    passwordConfigured: task.passwordConfigured,
    status: task.status,
    statusName: task.statusName,
    stagedTime: task.stagedTime,
    activatedTime: task.activatedTime,
    failureMessage: task.failureMessage,
    createTime: task.createTime,
    updateTime: task.updateTime
  }
}

function nowText(): string {
  return new Date().toISOString().replace('Z', '')
}

function normalizedPage(value: number): number {
  return Number.isInteger(value) && value > 0 ? value : 1
}

function normalizedSize(value: number): number {
  return Number.isInteger(value) && value > 0 ? value : 20
}

function branchDevices(): DeviceNode[] {
  return [
    {
      nodeId: 201,
      deviceCode: 'EDGE-BJ-01',
      name: '北京分部主网关',
      location: '北京分部 3 层',
      latitude: 39.9042,
      longitude: 116.4074,
      ip: '192.168.40.1',
      status: 1,
      firmwareVersion: '1.0.4',
      wifiStatus: 'CONNECTED',
      maxClients: 40,
      currentClients: 7,
      lastHeartbeat: '2026-08-19T09:18:20',
      rssiAtOneMeter: -43,
      pathLossExponent: 2.3,
      createTime: '2026-08-01T09:00:00',
      updateTime: '2026-08-19T09:18:20'
    },
    {
      nodeId: 202,
      deviceCode: 'EDGE-BJ-02',
      name: '北京访客网络',
      location: '北京分部接待区',
      latitude: 39.9046,
      longitude: 116.4081,
      ip: '192.168.41.1',
      status: 0,
      firmwareVersion: '1.0.3',
      wifiStatus: 'DISCONNECTED',
      maxClients: 24,
      currentClients: 0,
      lastHeartbeat: '2026-08-19T07:42:11',
      rssiAtOneMeter: -48,
      pathLossExponent: 2.8,
      createTime: '2026-08-03T11:20:00',
      updateTime: '2026-08-19T07:42:11'
    }
  ]
}

function branchSessions(): NetworkSession[] {
  return [
    {
      sessionId: 9901,
      userId: 301,
      nodeId: 201,
      replacedSessionId: null,
      mac: '18:65:90:31:4C:8A',
      ip: '192.168.40.28',
      deviceInfo: 'HarmonyOS Phone',
      loginTime: '2026-08-19T08:30:00',
      expireTime: '2026-08-19T16:30:00',
      logoutTime: null,
      status: 1,
      bytesUp: 8388608,
      bytesDown: 67108864
    }
  ]
}

export class DemoTenantDataRepository {
  private devicesByTenant: Map<string, DeviceNode[]> = new Map()
  private sessionsByTenant: Map<string, NetworkSession[]> = new Map()
  private commandsByTenant: Map<string, DeviceCommandRecord[]> = new Map()
  private wifiByTenant: Map<string, WifiConfigTask[]> = new Map()
  private commandPolls: Map<string, number> = new Map()
  private wifiPolls: Map<string, number> = new Map()
  private sequence: number = 10000
  private scenario: Hm3DemoScenario = 'NORMAL'

  demoScenario(): Hm3DemoScenario {
    return this.scenario
  }

  setDemoScenario(scenario: Hm3DemoScenario): void {
    this.scenario = scenario
  }

  private beforeRead(partial: boolean = false): void {
    if (this.scenario === 'FORBIDDEN') {
      throw new ApiError('当前场景无权读取租户运维数据', 403, 403, 'DEMO_FORBIDDEN')
    }
    if (this.scenario === 'RATE_LIMITED') {
      throw new ApiError('请求过于频繁', 429, 429, 'RATE_LIMITED')
    }
    if (this.scenario === 'DEPENDENCY_DOWN') {
      throw new ApiError('租户运维依赖暂不可用', 503, 503, 'DEPENDENCY_DOWN')
    }
    if (partial && this.scenario === 'PARTIAL_FAILURE') {
      throw new ApiError('局部运维数据加载失败', 502, 502, 'PARTIAL_FAILURE')
    }
  }

  private beforeWrite(): void {
    this.beforeRead()
    if (this.scenario === 'CONFLICT') {
      throw new ApiError('当前状态已变化，请刷新后重试', 409, 409, 'STATE_CONFLICT')
    }
  }

  private devices(tenantId: string): DeviceNode[] {
    const existing = this.devicesByTenant.get(tenantId)
    if (existing !== undefined) return existing
    const seeded = tenantId === 'preview-tenant-02'
      ? branchDevices()
      : previewDevicePage(1, 100, '').records.map(copyDevice)
    this.devicesByTenant.set(tenantId, seeded)
    return seeded
  }

  private sessions(tenantId: string): NetworkSession[] {
    const existing = this.sessionsByTenant.get(tenantId)
    if (existing !== undefined) return existing
    const seeded = tenantId === 'preview-tenant-02'
      ? branchSessions()
      : previewSessionPage({
        current: 1,
        size: 100,
        mac: '',
        nodeId: '',
        userId: '',
        status: ''
      }, true).records.map(copySession)
    this.sessionsByTenant.set(tenantId, seeded)
    return seeded
  }

  private commands(tenantId: string): DeviceCommandRecord[] {
    const existing = this.commandsByTenant.get(tenantId)
    if (existing !== undefined) return existing
    const seeded = tenantId === 'preview-tenant-02'
      ? []
      : previewDeviceCommandPage({
        current: 1,
        size: 100,
        requestId: '',
        deviceCode: ''
      }).records.map(copyCommand)
    this.commandsByTenant.set(tenantId, seeded)
    return seeded
  }

  private wifiTasks(tenantId: string): WifiConfigTask[] {
    const existing = this.wifiByTenant.get(tenantId)
    if (existing !== undefined) return existing
    const seeded: WifiConfigTask[] = []
    this.devices(tenantId).forEach((device: DeviceNode): void => {
      if (tenantId === 'preview-tenant-01') {
        const task = previewLatestWifiConfig(device.deviceCode)
        if (task !== null) seeded.push(copyWifi(task))
      }
    })
    this.wifiByTenant.set(tenantId, seeded)
    return seeded
  }

  listDevices(
    tenantId: string,
    current: number,
    size: number,
    keyword: string
  ): DevicePageResult {
    this.beforeRead()
    const search = keyword.trim().toLowerCase()
    if (this.scenario === 'EMPTY' ||
      (this.scenario === 'FILTER_EMPTY' && search.length > 0)) {
      return {
        total: 0,
        current: normalizedPage(current),
        size: normalizedSize(size),
        records: []
      }
    }
    const filtered = this.devices(tenantId).filter((device: DeviceNode): boolean =>
      search.length === 0 ||
      device.name.toLowerCase().includes(search) ||
      device.deviceCode.toLowerCase().includes(search) ||
      device.location.toLowerCase().includes(search))
    const page = normalizedPage(current)
    const pageSize = normalizedSize(size)
    const start = (page - 1) * pageSize
    return {
      total: filtered.length,
      current: page,
      size: pageSize,
      records: filtered.slice(start, start + pageSize).map(copyDevice)
    }
  }

  deviceDetail(tenantId: string, nodeId: string): DeviceNode {
    this.beforeRead()
    const id = Number(nodeId)
    const device = this.devices(tenantId).find((item: DeviceNode): boolean => item.nodeId === id)
    if (device === undefined) {
      throw new ApiError('没有找到当前租户的设备', 404, 404, 'DEVICE_NOT_FOUND')
    }
    return copyDevice(device)
  }

  createDevice(tenantId: string, input: DeviceEditInput): DeviceNode {
    this.beforeWrite()
    const devices = this.devices(tenantId)
    const code = input.deviceCode.trim().toUpperCase()
    if (devices.some((item: DeviceNode): boolean => item.deviceCode === code)) {
      throw new ApiError('设备编码已经存在', 409, 409, 'DEVICE_CODE_CONFLICT')
    }
    this.sequence += 1
    const createdAt = nowText()
    const device: DeviceNode = {
      nodeId: this.sequence,
      deviceCode: code,
      name: input.name.trim(),
      location: input.location.trim(),
      latitude: null,
      longitude: null,
      ip: input.ip.trim(),
      status: 0,
      firmwareVersion: '',
      wifiStatus: 'DISCONNECTED',
      maxClients: input.maxClients,
      currentClients: 0,
      lastHeartbeat: null,
      rssiAtOneMeter: null,
      pathLossExponent: null,
      createTime: createdAt,
      updateTime: createdAt
    }
    devices.unshift(device)
    return copyDevice(device)
  }

  updateDevice(tenantId: string, nodeId: string, input: DeviceEditInput): DeviceNode {
    this.beforeWrite()
    const devices = this.devices(tenantId)
    const device = devices.find((item: DeviceNode): boolean => item.nodeId === Number(nodeId))
    if (device === undefined) {
      throw new ApiError('没有找到当前租户的设备', 404, 404, 'DEVICE_NOT_FOUND')
    }
    const code = input.deviceCode.trim().toUpperCase()
    if (devices.some((item: DeviceNode): boolean =>
      item.nodeId !== device.nodeId && item.deviceCode === code)) {
      throw new ApiError('设备编码已经存在', 409, 409, 'DEVICE_CODE_CONFLICT')
    }
    device.deviceCode = code
    device.name = input.name.trim()
    device.location = input.location.trim()
    device.ip = input.ip.trim()
    device.maxClients = input.maxClients
    device.updateTime = nowText()
    return copyDevice(device)
  }

  deleteDevice(tenantId: string, nodeId: string): DeviceNode {
    this.beforeWrite()
    const device = this.devices(tenantId)
      .find((item: DeviceNode): boolean => item.nodeId === Number(nodeId))
    if (device === undefined) {
      throw new ApiError('没有找到当前租户的设备', 404, 404, 'DEVICE_NOT_FOUND')
    }
    if (device.status === -1) {
      throw new ApiError('设备已经删除', 409, 409, 'DEVICE_ALREADY_DELETED')
    }
    device.status = -1
    device.currentClients = 0
    device.wifiStatus = 'DISCONNECTED'
    device.updateTime = nowText()
    return copyDevice(device)
  }

  restoreDevice(tenantId: string, nodeId: string): DeviceNode {
    this.beforeWrite()
    const device = this.devices(tenantId)
      .find((item: DeviceNode): boolean => item.nodeId === Number(nodeId))
    if (device === undefined) {
      throw new ApiError('没有找到当前租户的设备', 404, 404, 'DEVICE_NOT_FOUND')
    }
    if (device.status !== -1) {
      throw new ApiError('设备未处于删除状态', 409, 409, 'DEVICE_NOT_DELETED')
    }
    device.status = 0
    device.updateTime = nowText()
    return copyDevice(device)
  }

  listSignals(tenantId: string, nodeId: string): DeviceSignalRecord[] {
    this.beforeRead(true)
    const device = this.deviceDetail(tenantId, nodeId)
    const base = device.nodeId * 10
    return [
      {
        signalId: base + 1,
        nodeId: device.nodeId,
        sessionId: this.sessions(tenantId).length > 0
          ? this.sessions(tenantId)[0].sessionId
          : null,
        mac: this.sessions(tenantId).length > 0
          ? this.sessions(tenantId)[0].mac
          : '02:00:00:00:00:01',
        rssi: device.status === 1 ? -52 : -83,
        distanceMeters: device.status === 1 ? 4.8 : 18.6,
        recordedAt: '2026-08-19T09:18:00'
      },
      {
        signalId: base + 2,
        nodeId: device.nodeId,
        sessionId: null,
        mac: '02:00:00:00:00:02',
        rssi: device.status === 1 ? -67 : -91,
        distanceMeters: device.status === 1 ? 9.7 : 26.4,
        recordedAt: '2026-08-19T09:13:00'
      }
    ]
  }

  signalDetail(tenantId: string, signalId: number): DeviceSignalRecord {
    this.beforeRead(true)
    const devices = this.devices(tenantId)
    for (let index = 0; index < devices.length; index += 1) {
      const signals = this.listSignals(tenantId, String(devices[index].nodeId))
      const signal = signals.find((item: DeviceSignalRecord): boolean => item.signalId === signalId)
      if (signal !== undefined) return signal
    }
    throw new ApiError('没有找到当前租户的信号记录', 404, 404, 'SIGNAL_NOT_FOUND')
  }

  listTraffic(tenantId: string, nodeId: string): DeviceTrafficPoint[] {
    this.beforeRead(true)
    const device = this.deviceDetail(tenantId, nodeId)
    const factor = device.nodeId
    return [
      {
        pointId: factor * 10 + 1,
        nodeId: device.nodeId,
        bytesUp: factor * 102400,
        bytesDown: factor * 524288,
        recordedAt: '2026-08-19T08:00:00'
      },
      {
        pointId: factor * 10 + 2,
        nodeId: device.nodeId,
        bytesUp: factor * 153600,
        bytesDown: factor * 786432,
        recordedAt: '2026-08-19T09:00:00'
      },
      {
        pointId: factor * 10 + 3,
        nodeId: device.nodeId,
        bytesUp: factor * 204800,
        bytesDown: factor * 1048576,
        recordedAt: '2026-08-19T10:00:00'
      }
    ]
  }

  listSessions(tenantId: string, query: SessionQuery, admin: boolean): SessionPageResult {
    this.beforeRead()
    if (this.scenario === 'EMPTY' ||
      (this.scenario === 'FILTER_EMPTY' &&
        (query.mac.length > 0 || query.nodeId.length > 0 ||
          query.userId.length > 0 || query.status.length > 0))) {
      return {
        total: 0,
        current: normalizedPage(query.current),
        size: normalizedSize(query.size),
        records: []
      }
    }
    const mac = query.mac.trim().toUpperCase()
    const filtered = this.sessions(tenantId).filter((session: NetworkSession): boolean =>
      (admin || session.userId === 201) &&
      (mac.length === 0 || session.mac.includes(mac)) &&
      (query.nodeId.length === 0 || String(session.nodeId ?? '') === query.nodeId) &&
      (query.userId.length === 0 || String(session.userId ?? '') === query.userId) &&
      (query.status.length === 0 || String(session.status) === query.status))
    const page = normalizedPage(query.current)
    const pageSize = normalizedSize(query.size)
    const start = (page - 1) * pageSize
    return {
      total: filtered.length,
      current: page,
      size: pageSize,
      records: filtered.slice(start, start + pageSize).map(copySession)
    }
  }

  closeSession(tenantId: string, sessionId: number): NetworkSession {
    this.beforeWrite()
    const session = this.sessions(tenantId)
      .find((item: NetworkSession): boolean => item.sessionId === sessionId)
    if (session === undefined) {
      throw new ApiError('没有找到当前租户的连接', 404, 404, 'SESSION_NOT_FOUND')
    }
    if (session.status === 0) {
      throw new ApiError('连接已经结束', 409, 409, 'SESSION_ALREADY_CLOSED')
    }
    session.status = 0
    session.logoutTime = nowText()
    return copySession(session)
  }

  submitCommand(
    tenantId: string,
    deviceCode: string,
    commandType: string,
    purpose: string,
    mac: string | null
  ): DeviceCommandResult {
    this.beforeWrite()
    const device = this.devices(tenantId)
      .find((item: DeviceNode): boolean => item.deviceCode === deviceCode)
    if (device === undefined) {
      throw new ApiError('没有找到当前租户的设备', 404, 404, 'DEVICE_NOT_FOUND')
    }
    this.sequence += 1
    const requestId = `demo-command-${this.sequence}`
    const createdAt = nowText()
    this.commands(tenantId).unshift({
      commandId: this.sequence,
      requestId: requestId,
      nodeId: device.nodeId,
      deviceCode: device.deviceCode,
      commandType: commandType,
      purpose: purpose,
      sessionId: null,
      mac: mac,
      alertId: null,
      ttlSeconds: 60,
      topic: '',
      payload: '',
      status: 1,
      retryCount: 0,
      nextRetryTime: null,
      publishTime: createdAt,
      deadlineTime: null,
      resultTime: null,
      resultMessage: null,
      createTime: createdAt,
      updateTime: createdAt
    })
    this.commandPolls.set(requestId, 0)
    return { requestId: requestId, topic: '', payload: '' }
  }

  listCommands(tenantId: string, query: DeviceCommandQuery): DeviceCommandPageResult {
    this.beforeRead()
    const filtered = this.commands(tenantId).filter((record: DeviceCommandRecord): boolean =>
      (query.requestId.length === 0 || record.requestId === query.requestId) &&
      (query.deviceCode.length === 0 || record.deviceCode === query.deviceCode))
    const page = normalizedPage(query.current)
    const pageSize = normalizedSize(query.size)
    const start = (page - 1) * pageSize
    return {
      total: filtered.length,
      current: page,
      size: pageSize,
      records: filtered.slice(start, start + pageSize).map(copyCommand)
    }
  }

  findCommand(tenantId: string, deviceCode: string, requestId: string): DeviceCommandRecord | null {
    this.beforeRead()
    const record = this.commands(tenantId).find((item: DeviceCommandRecord): boolean =>
      item.deviceCode === deviceCode && item.requestId === requestId)
    if (record === undefined) return null
    const polls = (this.commandPolls.get(requestId) ?? 0) + 1
    this.commandPolls.set(requestId, polls)
    if (record.status === 1 && polls >= 2) {
      record.status = 2
      record.resultTime = nowText()
      record.resultMessage = 'Demo 设备已确认执行'
      record.updateTime = record.resultTime
    }
    return copyCommand(record)
  }

  stageWifi(tenantId: string, deviceCode: string, ssid: string, password: string): WifiConfigTask {
    this.beforeWrite()
    const device = this.devices(tenantId)
      .find((item: DeviceNode): boolean => item.deviceCode === deviceCode)
    if (device === undefined) {
      throw new ApiError('没有找到当前租户的设备', 404, 404, 'DEVICE_NOT_FOUND')
    }
    this.sequence += 1
    const requestId = `demo-wifi-${this.sequence}`
    const createdAt = nowText()
    const task: WifiConfigTask = {
      wifiConfigId: this.sequence,
      nodeId: device.nodeId,
      deviceCode: device.deviceCode,
      requestId: requestId,
      configVersion: this.sequence,
      ssid: ssid.trim(),
      passwordConfigured: password.length > 0,
      status: 1,
      statusName: 'STAGED',
      stagedTime: createdAt,
      activatedTime: null,
      failureMessage: null,
      createTime: createdAt,
      updateTime: createdAt
    }
    this.wifiTasks(tenantId).unshift(task)
    this.wifiPolls.set(requestId, 0)
    return copyWifi(task)
  }

  latestWifi(tenantId: string, deviceCode: string): WifiConfigTask | null {
    this.beforeRead()
    const task = this.wifiTasks(tenantId)
      .find((item: WifiConfigTask): boolean => item.deviceCode === deviceCode)
    return task === undefined ? null : copyWifi(task)
  }

  findWifi(tenantId: string, deviceCode: string, requestId: string): WifiConfigTask {
    this.beforeRead()
    const task = this.wifiTasks(tenantId).find((item: WifiConfigTask): boolean =>
      item.deviceCode === deviceCode && item.requestId === requestId)
    if (task === undefined) {
      throw new ApiError('没有找到 WiFi 配置任务', 404, 404, 'WIFI_CONFIG_NOT_FOUND')
    }
    const polls = (this.wifiPolls.get(requestId) ?? 0) + 1
    this.wifiPolls.set(requestId, polls)
    if (task.status === 1 && polls >= 2) {
      task.status = 2
      task.statusName = 'ACTIVE'
      task.activatedTime = nowText()
      task.updateTime = task.activatedTime
    }
    return copyWifi(task)
  }

  reset(): void {
    this.devicesByTenant.clear()
    this.sessionsByTenant.clear()
    this.commandsByTenant.clear()
    this.wifiByTenant.clear()
    this.commandPolls.clear()
    this.wifiPolls.clear()
    this.sequence = 10000
    this.scenario = 'NORMAL'
  }
}
