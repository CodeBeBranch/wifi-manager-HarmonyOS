import { ApiError } from '../model/ApiModels'
import { AlertEvent, AlertPageResult, AlertQuery } from '../model/AlertModels'
import {
  AlertAnalytics,
  AlertHandleResult,
  AlertRuleInput,
  Hm4DemoScenario,
  TenantAlertRule,
  TenantAuditRecord
} from '../model/Hm4Models'

interface TenantSecurityData {
  alerts: AlertEvent[]
  rules: TenantAlertRule[]
  audits: TenantAuditRecord[]
  alertVersions: Map<number, number>
}

function cloneAlert(alert: AlertEvent): AlertEvent {
  return {
    id: alert.id, level: alert.level, ruleCode: alert.ruleCode, title: alert.title,
    mac: alert.mac, userId: alert.userId, detail: alert.detail, status: alert.status,
    handleUserId: alert.handleUserId, handleTime: alert.handleTime, createTime: alert.createTime,
    version: alert.version
  }
}

function cloneRule(rule: TenantAlertRule): TenantAlertRule {
  return {
    id: rule.id, code: rule.code, name: rule.name, enabled: rule.enabled,
    level: rule.level, condition: rule.condition, updateTime: rule.updateTime
  }
}

function cloneAudit(audit: TenantAuditRecord): TenantAuditRecord {
  return {
    id: audit.id,
    action: audit.action,
    operator: audit.operator,
    target: audit.target,
    detail: audit.detail,
    createTime: audit.createTime
  }
}

function errorForScenario(scenario: Hm4DemoScenario): ApiError | null {
  if (scenario === 'FORBIDDEN') return new ApiError('当前场景拒绝安全数据访问', 403, 403, 'HM4_SCENARIO_FORBIDDEN')
  if (scenario === 'RATE_LIMITED') return new ApiError('安全数据请求过于频繁', 429, 429, 'HM4_SCENARIO_RATE_LIMITED', '', '3', true)
  if (scenario === 'DEPENDENCY_DOWN') return new ApiError('安全数据依赖暂不可用', 503, 503, 'HM4_SCENARIO_DEPENDENCY_DOWN', '', '', true)
  return null
}

function createTenantData(tenantId: string, offset: number): TenantSecurityData {
  const mac = offset === 0 ? '70:66:55:01:01:01' : '70:66:55:02:01:01'
  return {
    alerts: [
      {
        id: 8100 + offset, level: 3, ruleCode: 'ALERT-ROGUE-AP',
        title: '检测到异常接入点', mac: mac, userId: null,
        detail: '本地演示检测到未经登记的接入点，需要管理员确认处理。',
        status: 0, handleUserId: null, handleTime: null, createTime: '2026-08-21T09:00:00'
      },
      {
        id: 8101 + offset, level: 2, ruleCode: 'ALERT-TRAFFIC-SPIKE',
        title: '设备流量异常升高', mac: mac, userId: 101 + offset,
        detail: '流量阈值已持续超过规则设定值。',
        status: 1, handleUserId: 1, handleTime: '2026-08-21T08:30:00', createTime: '2026-08-21T08:00:00'
      }
    ],
    rules: [
      {
        id: 9100 + offset, code: 'RULE-ROGUE-AP', name: '异常接入点识别',
        enabled: true, level: 3, condition: '未登记 BSSID 持续出现 3 分钟',
        updateTime: '2026-08-21T08:00:00'
      },
      {
        id: 9101 + offset, code: 'RULE-TRAFFIC-SPIKE', name: '流量峰值预警',
        enabled: true, level: 2, condition: '五分钟平均流量超过基线 200%',
        updateTime: '2026-08-21T07:30:00'
      }
    ],
    audits: [
      {
        id: 10100 + offset, action: 'ALERT_HANDLE', operator: 'tenantadmin',
        target: 'ALERT-TRAFFIC-SPIKE', detail: '确认流量异常已处理', createTime: '2026-08-21T08:30:00'
      },
      {
        id: 10101 + offset, action: 'RULE_UPDATE', operator: 'tenantadmin',
        target: 'RULE-ROGUE-AP', detail: '更新异常接入点识别阈值', createTime: '2026-08-21T08:00:00'
      }
    ],
    alertVersions: new Map<number, number>()
  }
}

export class DemoHm4SecurityRepository {
  private scenario: Hm4DemoScenario = 'NORMAL'
  private readonly tenants: Map<string, TenantSecurityData> = new Map<string, TenantSecurityData>()
  private nextRuleId: number = 9300

  private data(tenantId: string): TenantSecurityData {
    const key = tenantId.trim()
    if (key.length === 0) throw new ApiError('当前租户上下文无效', 409, 409, 'TENANT_CONTEXT_REQUIRED')
    const current = this.tenants.get(key)
    if (current !== undefined) return current
    const created = createTenantData(key, this.tenants.size * 100)
    this.tenants.set(key, created)
    return created
  }

  private guard(): void {
    const error = errorForScenario(this.scenario)
    if (error !== null) throw error
  }

  setScenario(scenario: Hm4DemoScenario): void {
    this.scenario = scenario
  }

  getScenario(): Hm4DemoScenario {
    return this.scenario
  }

  reset(): void {
    this.scenario = 'NORMAL'
    this.tenants.clear()
    this.nextRuleId = 9300
  }

  listAlerts(tenantId: string, query: AlertQuery): AlertPageResult {
    this.guard()
    if (this.scenario === 'EMPTY' || this.scenario === 'FILTER_EMPTY') {
      return { total: 0, current: query.current, size: query.size, records: [] }
    }
    const normalizedMac = query.mac.trim().toUpperCase()
    const records = this.data(tenantId).alerts.filter((alert: AlertEvent): boolean =>
      (query.level.length === 0 || String(alert.level) === query.level) &&
      (query.status.length === 0 || String(alert.status) === query.status) &&
      (normalizedMac.length === 0 || alert.mac === normalizedMac)
    )
    const size = Math.max(1, query.size)
    const current = Math.max(1, query.current)
    return {
      total: records.length, current: current, size: size,
      records: records.slice((current - 1) * size, current * size).map((alert: AlertEvent): AlertEvent => {
        const copy = cloneAlert(alert)
        copy.version = this.data(tenantId).alertVersions.get(alert.id) ?? 0
        return copy
      })
    }
  }

  alertDetail(tenantId: string, id: number): AlertEvent {
    this.guard()
    const alert = this.data(tenantId).alerts.find((item: AlertEvent): boolean => item.id === id)
    if (alert === undefined) throw new ApiError('没有找到当前租户的告警', 404, 404, 'ALERT_NOT_FOUND')
    const copy = cloneAlert(alert)
    copy.version = this.data(tenantId).alertVersions.get(id) ?? 0
    return copy
  }

  handleAlert(tenantId: string, id: number, userId: string, authorized: boolean, expectedVersion: number): AlertHandleResult {
    this.guard()
    if (!authorized) throw new ApiError('当前账号没有处理告警的权限', 403, 403, 'ALERT_HANDLE_FORBIDDEN')
    if (this.scenario === 'CONFLICT') throw new ApiError('当前场景拒绝处理告警', 409, 409, 'ALERT_HANDLE_SCENARIO_CONFLICT')
    const data = this.data(tenantId)
    const alert = data.alerts.find((item: AlertEvent): boolean => item.id === id)
    if (alert === undefined) throw new ApiError('没有找到当前租户的告警', 404, 404, 'ALERT_NOT_FOUND')
    const currentVersion = data.alertVersions.get(id) ?? 0
    if (expectedVersion !== currentVersion) throw new ApiError('告警状态已更新，请刷新后重试', 409, 409, 'ALERT_HANDLE_STALE')
    if (alert.status === 1) throw new ApiError('告警已处理，无需重复提交', 409, 409, 'ALERT_ALREADY_HANDLED')
    const version = currentVersion + 1
    alert.status = 1
    alert.handleUserId = userId.length > 0 ? 1 : null
    alert.handleTime = '2026-08-21T10:00:00'
    data.alertVersions.set(id, version)
    data.audits.unshift({
      id: 11000 + version, action: 'ALERT_HANDLE', operator: userId,
      target: alert.ruleCode, detail: '本地演示确认处理告警', createTime: alert.handleTime
    })
    return { alertId: id, version: version }
  }

  applyEvent(tenantId: string, alertId: number, eventVersion: number): boolean {
    const data = this.data(tenantId)
    const currentVersion = data.alertVersions.get(alertId) ?? 0
    if (eventVersion <= currentVersion) return false
    data.alertVersions.set(alertId, eventVersion)
    return true
  }

  alertVersion(tenantId: string, id: number): number {
    return this.data(tenantId).alertVersions.get(id) ?? 0
  }

  listRules(tenantId: string, keyword: string): TenantAlertRule[] {
    this.guard()
    if (this.scenario === 'EMPTY' || this.scenario === 'FILTER_EMPTY') return []
    const normalized = keyword.trim().toUpperCase()
    return this.data(tenantId).rules.filter((rule: TenantAlertRule): boolean =>
      normalized.length === 0 || rule.code.includes(normalized) || rule.name.toUpperCase().includes(normalized)
    ).map(cloneRule)
  }

  saveRule(tenantId: string, input: AlertRuleInput, id: number | null, authorized: boolean): TenantAlertRule {
    this.guard()
    if (!authorized) throw new ApiError('当前账号没有编辑规则的权限', 403, 403, 'RULE_WRITE_FORBIDDEN')
    if (this.scenario === 'CONFLICT') throw new ApiError('当前场景拒绝修改规则', 409, 409, 'RULE_SCENARIO_CONFLICT')
    const code = input.code.trim().toUpperCase()
    const name = input.name.trim()
    if (!/^[A-Z][A-Z0-9-]{2,39}$/.test(code) || name.length < 2 || name.length > 60) {
      throw new ApiError('规则编码或名称不符合要求', 400, 400, 'RULE_INPUT_INVALID')
    }
    const rules = this.data(tenantId).rules
    if (rules.some((rule: TenantAlertRule): boolean => rule.code === code && rule.id !== id)) {
      throw new ApiError('规则编码已存在', 409, 409, 'RULE_CODE_DUPLICATE')
    }
    let target: TenantAlertRule | undefined
    if (id === null) {
      target = {
        id: this.nextRuleId++,
        code: code,
        name: name,
        enabled: true,
        level: input.level,
        condition: input.condition.trim(),
        updateTime: '2026-08-21T10:00:00'
      }
    } else {
      target = rules.find((rule: TenantAlertRule): boolean => rule.id === id)
    }
    if (target === undefined) throw new ApiError('没有找到当前租户的规则', 404, 404, 'RULE_NOT_FOUND')
    target.code = code
    target.name = name
    target.level = input.level
    target.condition = input.condition.trim()
    target.updateTime = '2026-08-21T10:00:00'
    if (id === null) rules.unshift(target)
    return cloneRule(target)
  }

  toggleRule(tenantId: string, id: number, authorized: boolean): TenantAlertRule {
    this.guard()
    if (!authorized) throw new ApiError('当前账号没有编辑规则的权限', 403, 403, 'RULE_WRITE_FORBIDDEN')
    const rule = this.data(tenantId).rules.find((item: TenantAlertRule): boolean => item.id === id)
    if (rule === undefined) throw new ApiError('没有找到当前租户的规则', 404, 404, 'RULE_NOT_FOUND')
    rule.enabled = !rule.enabled
    rule.updateTime = '2026-08-21T10:00:00'
    return cloneRule(rule)
  }

  deleteRule(tenantId: string, id: number, authorized: boolean): void {
    this.guard()
    if (!authorized) throw new ApiError('当前账号没有编辑规则的权限', 403, 403, 'RULE_WRITE_FORBIDDEN')
    const rules = this.data(tenantId).rules
    const index = rules.findIndex((item: TenantAlertRule): boolean => item.id === id)
    if (index < 0) throw new ApiError('没有找到当前租户的规则', 404, 404, 'RULE_NOT_FOUND')
    rules.splice(index, 1)
  }

  listAudits(tenantId: string, keyword: string): TenantAuditRecord[] {
    this.guard()
    if (this.scenario === 'EMPTY' || this.scenario === 'FILTER_EMPTY') return []
    const normalized = keyword.trim().toUpperCase()
    return this.data(tenantId).audits.filter((audit: TenantAuditRecord): boolean =>
      normalized.length === 0 || audit.action.includes(normalized) || audit.target.toUpperCase().includes(normalized)
    ).map(cloneAudit)
  }

  auditDetail(tenantId: string, id: number): TenantAuditRecord {
    const audit = this.listAudits(tenantId, '').find((item: TenantAuditRecord): boolean => item.id === id)
    if (audit === undefined) throw new ApiError('没有找到当前租户的审计记录', 404, 404, 'AUDIT_NOT_FOUND')
    return audit
  }

  analytics(tenantId: string): AlertAnalytics {
    this.guard()
    if (this.scenario === 'PARTIAL_FAILURE') {
      throw new ApiError('告警分析暂不可用，其他安全数据仍可读取', 502, 502, 'PARTIAL_FAILURE')
    }
    const alerts = this.data(tenantId).alerts
    const handled = alerts.filter((alert: AlertEvent): boolean => alert.status === 1).length
    const high = alerts.filter((alert: AlertEvent): boolean => alert.level === 3).length
    return {
      total: alerts.length, handled: handled, pending: alerts.length - handled, highLevel: high,
      topRule: this.data(tenantId).rules[0]?.name ?? '-'
    }
  }
}

export class RealHm4SecurityRepository {
  private pending(): ApiError {
    return new ApiError('真实安全规则、审计与分析接口等待公开契约', 503, 503, 'REAL_API_PENDING')
  }

  async listRules(_keyword: string): Promise<TenantAlertRule[]> { throw this.pending() }
  async saveRule(_input: AlertRuleInput, _id: number | null): Promise<TenantAlertRule> { throw this.pending() }
  async toggleRule(_id: number): Promise<TenantAlertRule> { throw this.pending() }
  async deleteRule(_id: number): Promise<void> { throw this.pending() }
  async listAudits(_keyword: string): Promise<TenantAuditRecord[]> { throw this.pending() }
  async auditDetail(_id: number): Promise<TenantAuditRecord> { throw this.pending() }
  async analytics(): Promise<AlertAnalytics> { throw this.pending() }
}
