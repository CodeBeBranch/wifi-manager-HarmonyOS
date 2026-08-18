export type DeviceCommandMode = 'restart' | 'disconnect' | 'block'

export type DeviceCommandPollState =
  'idle' | 'polling' | 'paused' | 'terminal' | 'exhausted' | 'failed'

export interface RestartDeviceRequest {
  reason: string
}

export interface DisconnectMacRequest {
  mac: string
}

export interface BlockTrafficRequest {
  dstIp: string
  sni?: string
}

export interface DeviceCommandResult {
  requestId: string
  topic: string
  payload: string
}

export interface DeviceCommandRecord {
  commandId: number
  requestId: string
  nodeId: number
  deviceCode: string
  commandType: string
  purpose: string
  sessionId: number | null
  mac: string | null
  alertId: number | null
  ttlSeconds: number | null
  topic: string
  payload: string
  status: number
  retryCount: number
  nextRetryTime: string | null
  publishTime: string | null
  deadlineTime: string | null
  resultTime: string | null
  resultMessage: string | null
  createTime: string | null
  updateTime: string | null
}

export interface DeviceCommandPageResult {
  total: number
  current: number
  size: number
  records: DeviceCommandRecord[]
}

export interface DeviceCommandQuery {
  current: number
  size: number
  requestId: string
  deviceCode: string
}

export function isDeviceCommandTerminal(status: number | null | undefined): boolean {
  return status === 2 || status === 3 || status === 4 || status === 5
}

export function deviceCommandStatusLabel(status: number | null | undefined): string {
  if (status === 0) return '等待发送'
  if (status === 1) return '已发送，等待设备结果'
  if (status === 2) return '执行成功'
  if (status === 3) return '设备执行失败'
  if (status === 4) return '指令发送失败'
  if (status === 5) return '等待结果超时'
  return status === null || status === undefined ? '暂未查询到记录' : `未知状态 (${status})`
}

export function deviceCommandTypeLabel(commandType: string, purpose: string): string {
  const normalized = commandType.trim().toUpperCase()
  if (normalized === 'KICK') return '重启设备'
  if (normalized === 'DISCONNECT_MAC') return '断开终端'
  if (normalized === 'BLOCK_TRAFFIC') return '阻断流量'
  if (normalized === 'ALLOW') return '允许联网'
  if (normalized === 'REVOKE_ACCESS') return '撤销联网'
  if (normalized === 'STAGE_WIFI_CONFIG') return '下发 WiFi 配置'
  return purpose.trim().length > 0 ? purpose : (commandType || '未知命令')
}

export function isValidDeviceCommandRequestId(value: string): boolean {
  return /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(value.trim())
}

export function isValidMacAddress(value: string): boolean {
  return /^[0-9A-F]{2}(:[0-9A-F]{2}){5}$/.test(value.trim().toUpperCase())
}

export function isValidIpv4Address(value: string): boolean {
  const normalized = value.trim()
  if (!/^\d{1,3}(?:\.\d{1,3}){3}$/.test(normalized)) return false
  const parts = normalized.split('.')
  return parts.every((part: string): boolean => {
    if (part.length > 1 && part.startsWith('0')) return false
    const segment = Number(part)
    return Number.isInteger(segment) && segment >= 0 && segment <= 255
  })
}
