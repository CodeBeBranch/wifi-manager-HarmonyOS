export type WifiConfigPollState =
  'idle' | 'polling' | 'paused' | 'terminal' | 'exhausted' | 'failed'

export interface WifiConfigStageRequest {
  ssid: string
  password: string
}

export interface WifiConfigTask {
  wifiConfigId: number
  nodeId: number
  deviceCode: string
  requestId: string
  configVersion: number
  ssid: string
  passwordConfigured: boolean
  status: number
  statusName: string
  stagedTime: string | null
  activatedTime: string | null
  failureMessage: string | null
  createTime: string | null
  updateTime: string | null
}

export function isWifiConfigTerminal(status: number | null | undefined): boolean {
  return status === 2 || status === 3 || status === 5
}

export function wifiConfigStatusLabel(status: number | null | undefined): string {
  if (status === 0) return '正在下发'
  if (status === 1) return '新配置已保存，等待设备连接'
  if (status === 2) return '配置已生效'
  if (status === 3) return '配置失败'
  if (status === 4) return '结果未知'
  if (status === 5) return '已被新配置替代'
  return status === null || status === undefined ? '暂无配置任务' : `未知状态 (${status})`
}

export function isValidWifiConfigRequestId(value: string): boolean {
  return /^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$/.test(value.trim())
}

export function utf8ByteLength(value: string): number {
  let bytes = 0
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index)
    if (code <= 0x7F) {
      bytes += 1
    } else if (code <= 0x7FF) {
      bytes += 2
    } else if (code >= 0xD800 && code <= 0xDBFF) {
      if (index + 1 >= value.length) return -1
      const next = value.charCodeAt(index + 1)
      if (next < 0xDC00 || next > 0xDFFF) return -1
      bytes += 4
      index += 1
    } else if (code >= 0xDC00 && code <= 0xDFFF) {
      return -1
    } else {
      bytes += 3
    }
  }
  return bytes
}

export function validateWifiCredentials(ssid: string, password: string): string {
  const normalizedSsid = ssid.trim()
  const ssidBytes = utf8ByteLength(normalizedSsid)
  if (ssidBytes < 1 || ssidBytes > 32 || normalizedSsid.indexOf('\0') >= 0) {
    return 'SSID 的 UTF-8 长度必须在 1 到 32 字节之间'
  }

  const passwordBytes = utf8ByteLength(password)
  if (passwordBytes < 0 || (passwordBytes !== 0 && (passwordBytes < 8 || passwordBytes > 63))) {
    return 'WiFi 密码需留空，或使用 8 到 63 个 UTF-8 字节'
  }
  if (password.indexOf('\0') >= 0) {
    return 'WiFi 密码不能包含空字符'
  }
  return ''
}
