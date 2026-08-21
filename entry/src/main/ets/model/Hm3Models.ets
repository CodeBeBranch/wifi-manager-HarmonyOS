export interface BlacklistEntry {
  id: number
  tenantId: string
  mac: string
  reason: string
  status: string
  createdAt: string
}

export interface BlacklistQuery {
  keyword: string
}

export interface DeviceSignalRecord {
  signalId: number
  nodeId: number
  sessionId: number | null
  mac: string
  rssi: number
  distanceMeters: number
  recordedAt: string
}

export interface DeviceTrafficPoint {
  pointId: number
  nodeId: number
  bytesUp: number
  bytesDown: number
  recordedAt: string
}

export interface DeviceEditInput {
  deviceCode: string
  name: string
  location: string
  ip: string
  maxClients: number
}

export type Hm3DemoScenario =
  'NORMAL' | 'EMPTY' | 'FILTER_EMPTY' | 'LOADING' | 'PARTIAL_FAILURE' |
  'FORBIDDEN' | 'CONFLICT' | 'RATE_LIMITED' | 'DEPENDENCY_DOWN'
