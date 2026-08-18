export interface AlertEvent {
  id: number
  level: number
  ruleCode: string
  title: string
  mac: string
  userId: number | null
  detail: string
  status: number
  handleUserId: number | null
  handleTime: string | null
  createTime: string | null
}

export interface AlertPageResult {
  total: number
  current: number
  size: number
  records: AlertEvent[]
}

export interface AlertQuery {
  current: number
  size: number
  level: string
  status: string
  mac: string
}

export type AlertSocketState =
  'idle' | 'connecting' | 'connected' | 'reconnecting' | 'disconnected' | 'auth-required'

export interface AlertPushEvent {
  type: string
  alertId: number
  tenantId: string
  level: number
  ruleCode: string
  title: string
  mac: string
  userId: number | null
  createTime: string
}

interface AlertSocketPayload {
  type?: string
  alertId?: number
  tenantId?: string | number
  level?: number
  ruleCode?: string
  title?: string
  mac?: string
  userId?: number | null
  createTime?: string
}

export interface ParsedAlertSocketMessage {
  type: string
  alert: AlertPushEvent | null
}

export function parseAlertSocketMessage(
  message: string,
  expectedTenantId: string
): ParsedAlertSocketMessage | null {
  try {
    const payload = JSON.parse(message) as AlertSocketPayload
    const type = String(payload.type ?? '').toUpperCase()
    if (type === 'PING') {
      return { type: 'PING', alert: null }
    }
    if (type !== 'ALERT') return null

    const alertId = Number(payload.alertId ?? 0)
    const tenantId = String(payload.tenantId ?? '')
    if (!Number.isInteger(alertId) || alertId <= 0 ||
      tenantId.length === 0 || tenantId !== expectedTenantId) {
      return null
    }
    return {
      type: 'ALERT',
      alert: {
        type: 'alert',
        alertId: alertId,
        tenantId: tenantId,
        level: Number(payload.level ?? 0),
        ruleCode: String(payload.ruleCode ?? ''),
        title: String(payload.title ?? ''),
        mac: String(payload.mac ?? ''),
        userId: payload.userId === null || payload.userId === undefined
          ? null
          : Number(payload.userId),
        createTime: String(payload.createTime ?? '')
      }
    }
  } catch (_) {
    return null
  }
}

export function alertReconnectDelay(attempt: number): number {
  const normalized = Math.max(0, Math.floor(attempt))
  return Math.min(1000 * Math.pow(2, normalized), 30000)
}
