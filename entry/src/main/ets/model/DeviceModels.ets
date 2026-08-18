export interface DeviceNode {
  nodeId: number
  deviceCode: string
  name: string
  location: string
  latitude: number | null
  longitude: number | null
  ip: string
  status: number
  firmwareVersion: string
  wifiStatus: string
  maxClients: number
  currentClients: number
  lastHeartbeat: string | null
  rssiAtOneMeter: number | null
  pathLossExponent: number | null
  createTime: string | null
  updateTime: string | null
}

export interface DevicePageResult {
  total: number
  current: number
  size: number
  records: DeviceNode[]
}
