export interface NetworkSession {
  sessionId: number
  userId: number | null
  nodeId: number | null
  replacedSessionId: number | null
  mac: string
  ip: string
  deviceInfo: string
  loginTime: string | null
  expireTime: string | null
  logoutTime: string | null
  status: number
  bytesUp: number
  bytesDown: number
}

export interface SessionPageResult {
  total: number
  current: number
  size: number
  records: NetworkSession[]
}

export interface SessionQuery {
  current: number
  size: number
  mac: string
  nodeId: string
  userId: string
  status: string
}
