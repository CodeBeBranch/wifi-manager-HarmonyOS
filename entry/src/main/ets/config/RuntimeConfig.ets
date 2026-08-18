const DEFAULT_GATEWAY_URL = 'http://10.0.2.2:8080'
const DEFAULT_ALERT_WEBSOCKET_ORIGIN = 'http://portal.test:5173'

export function normalizeGatewayUrl(value: string): string {
  const normalized = value.trim().replace(/\/+$/, '')
  if (!/^https?:\/\/[^/\s]+(?::\d+)?$/i.test(normalized)) {
    throw new Error('请输入完整的 Gateway 地址，例如 http://192.168.1.10:8080')
  }
  return normalized
}

export function defaultGatewayUrl(): string {
  return DEFAULT_GATEWAY_URL
}

export function buildAlertWebSocketUrl(gatewayUrl: string): string {
  const normalized = normalizeGatewayUrl(gatewayUrl)
  const protocol = normalized.startsWith('https://') ? 'wss://' : 'ws://'
  return `${protocol}${normalized.replace(/^https?:\/\//i, '')}/ws/alerts`
}

export function defaultAlertWebSocketOrigin(): string {
  return DEFAULT_ALERT_WEBSOCKET_ORIGIN
}
