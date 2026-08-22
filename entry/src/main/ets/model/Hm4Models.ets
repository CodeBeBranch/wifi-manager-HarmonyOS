export type Hm4DemoScenario =
  'NORMAL' | 'EMPTY' | 'FILTER_EMPTY' | 'LOADING' | 'PARTIAL_FAILURE' |
  'FORBIDDEN' | 'CONFLICT' | 'RATE_LIMITED' | 'DEPENDENCY_DOWN'

export interface TenantAlertRule {
  id: number
  code: string
  name: string
  enabled: boolean
  level: number
  condition: string
  updateTime: string
}

export interface TenantAuditRecord {
  id: number
  action: string
  operator: string
  target: string
  detail: string
  createTime: string
}

export interface AlertAnalytics {
  total: number
  handled: number
  pending: number
  highLevel: number
  topRule: string
}

export interface DemoAlertConnection {
  state: 'connecting' | 'online' | 'reconnecting' | 'catch-up' | 'failed'
  version: number
}

export interface AlertHandleResult {
  alertId: number
  version: number
}

export interface AlertRuleInput {
  code: string
  name: string
  level: number
  condition: string
}
