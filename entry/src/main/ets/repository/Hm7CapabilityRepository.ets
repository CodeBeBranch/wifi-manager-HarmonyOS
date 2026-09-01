import { ApiError } from '../model/ApiModels'
import { Hm3DemoScenario } from '../model/Hm3Models'
import {
  Hm7ActionResult,
  Hm7Capability,
  Hm7Record,
  Hm7RecordInput,
  Hm7RequestContext,
  Hm7Scope
} from '../model/Hm7Models'

export interface Hm7CapabilityRepositoryContract {
  list(context: Hm7RequestContext, capability: Hm7Capability,
    keyword: string, status: string): Promise<Hm7Record[]>
  detail(context: Hm7RequestContext, capability: Hm7Capability, id: number): Promise<Hm7Record>
  save(context: Hm7RequestContext, capability: Hm7Capability,
    id: number, input: Hm7RecordInput): Promise<Hm7ActionResult>
  act(context: Hm7RequestContext, capability: Hm7Capability,
    id: number, action: string): Promise<Hm7ActionResult>
}

interface Hm7Seed {
  title: string
  subtitle: string
  status: string
  summary: string
  detail: string
  metricLabel: string
  metricValue: string
}

function cloneRecord(value: Hm7Record): Hm7Record {
  return {
    id: value.id,
    capability: value.capability,
    tenantId: value.tenantId,
    ownerId: value.ownerId,
    title: value.title,
    subtitle: value.subtitle,
    status: value.status,
    summary: value.summary,
    detail: value.detail,
    metricLabel: value.metricLabel,
    metricValue: value.metricValue,
    updatedAt: value.updatedAt
  }
}

function seeds(capability: Hm7Capability, scope: Hm7Scope): Hm7Seed[] {
  if (capability === 'ENTITLEMENT') {
    return [
      {
        title: '专业版权益', subtitle: 'branch-office · 年度订阅', status: 'ACTIVE',
        summary: '设备、成员和流量权益统一管理', detail: '设备 120 台，成员 500 位，每月 8 TB 流量。',
        metricLabel: '剩余流量', metricValue: '6.4 TB'
      },
      {
        title: '活动奖励订单', subtitle: '新组织开通奖励', status: 'PENDING',
        summary: '待确认的本地演示奖励', detail: '奖励 200 GB，有效期 30 天。',
        metricLabel: '奖励额度', metricValue: '200 GB'
      }
    ]
  }
  if (capability === 'SAAS') {
    return [
      {
        title: scope === 'PLATFORM' ? '专业版订阅' : '当前专业版',
        subtitle: 'SAAS-PRO-2026 · v3', status: 'ACTIVE',
        summary: '适用于多节点办公网络', detail: '包含设备管理、告警、位置和分析能力。',
        metricLabel: '设备配额', metricValue: '120 / 200'
      },
      {
        title: '成长版订阅', subtitle: 'SAAS-GROWTH-2026 · v2', status: 'DRAFT',
        summary: '适用于成长型组织', detail: '包含 80 台设备和 300 位成员配额。',
        metricLabel: '成员配额', metricValue: '186 / 300'
      }
    ]
  }
  if (capability === 'MARKETPLACE') {
    return [
      {
        title: '访客网络增强包', subtitle: 'SKU-MKT-001 · 华东履约', status: 'ON_SALE',
        summary: '访客 Portal、短信额度和访问分析', detail: '包含 10 万次 Portal 认证和 1 万条短信。',
        metricLabel: '价格', metricValue: '¥699 / 月'
      },
      {
        title: '边缘节点巡检服务', subtitle: 'SKU-MKT-002 · 上门服务', status: 'FULFILLING',
        summary: '季度巡检和故障定位', detail: '当前订单已分派服务工程师，预计 9 月 3 日完成。',
        metricLabel: '履约进度', metricValue: '2 / 3'
      },
      {
        title: '安全分析扩展包', subtitle: 'SKU-MKT-003 · AI 辅助', status: 'OFF_SALE',
        summary: '扩展告警分析和人工复核额度', detail: '下架商品保留历史订单和审计记录。',
        metricLabel: '历史订单', metricValue: '28'
      }
    ]
  }
  if (capability === 'CONTENT') {
    return [
      {
        title: '九月网络维护窗口', subtitle: '平台运维 · 2026-09-01', status: 'PUBLISHED',
        summary: '周日凌晨进行边缘节点滚动升级', detail: '维护期间连接会自动迁移，不影响已登录成员。',
        metricLabel: '评论', metricValue: '12'
      },
      {
        title: '访客网络使用规范', subtitle: '组织管理员 · 2026-08-29', status: 'REVIEW',
        summary: '访客认证和隐私说明更新', detail: '内容正在等待平台审核，尚未对成员发布。',
        metricLabel: '审核状态', metricValue: '待审核'
      }
    ]
  }
  if (capability === 'SUPPORT') {
    return [
      {
        title: '会议区信号不稳定', subtitle: 'SUP-20260901-001 · 网络问题', status: 'ASSIGNED',
        summary: '二层会议区午间出现漫游抖动', detail: '已分派网络支持组，正在对比节点信号记录。',
        metricLabel: '响应时限', metricValue: '42 分钟'
      },
      {
        title: '订单发票信息修改', subtitle: 'SUP-20260831-018 · 账户问题', status: 'OPEN',
        summary: '需要更新发票抬头', detail: '工单由成员创建，等待租户管理员首次回复。',
        metricLabel: '消息', metricValue: '3'
      }
    ]
  }
  if (capability === 'AI_REVIEW') {
    return [
      {
        title: '异常漫游行为复核', subtitle: 'AI-REV-001 · 置信度 82%', status: 'PENDING',
        summary: '模型建议标记为节点覆盖重叠', detail: '证据包含 3 个节点的信号切换和 2 次重连。',
        metricLabel: '证据项', metricValue: '5'
      },
      {
        title: '高流量账号复核', subtitle: 'AI-REV-002 · 置信度 64%', status: 'MANUAL',
        summary: '模型置信度不足，已转人工', detail: '需要结合成员权益和业务时段判断。',
        metricLabel: '等待时间', metricValue: '18 分钟'
      }
    ]
  }
  if (capability === 'RUNTIME') {
    return [
      {
        title: '设备状态同步任务', subtitle: 'JOB-DEVICE-SYNC-8821', status: 'FAILED',
        summary: '第三批同步在依赖恢复前失败', detail: '任务可人工恢复，恢复操作需要二次确认。',
        metricLabel: '失败记录', metricValue: '14'
      },
      {
        title: '告警索引重建', subtitle: 'JOB-ALERT-INDEX-2170', status: 'RUNNING',
        summary: '索引重建进度正常', detail: '任务由系统调度，不需要人工干预。',
        metricLabel: '进度', metricValue: '68%'
      },
      {
        title: '通知分发补偿', subtitle: 'JOB-NOTICE-RETRY-6612', status: 'RECOVERED',
        summary: '异常任务已人工恢复', detail: '补偿发送完成，关联 requestId 已写入审计记录。',
        metricLabel: '补偿消息', metricValue: '31'
      }
    ]
  }
  if (capability === 'AUDIT') {
    return [
      {
        title: '人工恢复异常任务', subtitle: '超级管理员 · runtime-job', status: 'SUCCEEDED',
        summary: '恢复 JOB-NOTICE-RETRY-6612', detail: '二次确认后执行，clientRequestId 已记录。',
        metricLabel: 'requestId', metricValue: 'AUD-7001'
      },
      {
        title: '发布平台公告', subtitle: '超级管理员 · announcement', status: 'SUCCEEDED',
        summary: '发布九月网络维护窗口', detail: '公告审核通过并向三类工作区可见。',
        metricLabel: 'requestId', metricValue: 'AUD-7002'
      }
    ]
  }
  if (capability === 'ORGANIZATION') {
    return [
      {
        title: '分部办公网络', subtitle: 'branch-office · ACTIVE', status: 'ACTIVE',
        summary: '办公网络与访客网络统一管理', detail: '组织联系人、服务地址和安全策略均为本地演示数据。',
        metricLabel: '成员', metricValue: '186'
      }
    ]
  }
  if (capability === 'MEMBER') {
    return [
      {
        title: '陈晓', subtitle: 'TENANT_OWNER · chenxiao', status: 'ACTIVE',
        summary: '组织所有者', detail: '拥有组织资料、成员和所有权转移权限。',
        metricLabel: '最近登录', metricValue: '今天 09:42'
      },
      {
        title: '林悦', subtitle: 'TENANT_ADMIN · linyue', status: 'ACTIVE',
        summary: '租户管理员', detail: '可管理成员、服务和网络运维功能。',
        metricLabel: '最近登录', metricValue: '今天 10:16'
      },
      {
        title: '待加入成员', subtitle: 'INV-20260901-02 · user@example.com', status: 'INVITED',
        summary: '邀请等待接受', detail: '邀请有效期至 2026-09-08。',
        metricLabel: '已发送', metricValue: '2 次'
      }
    ]
  }
  return [
    {
      title: '工单状态已更新', subtitle: '支持中心 · 5 分钟前', status: 'UNREAD',
      summary: '会议区信号工单已分派', detail: '网络支持组已接单，预计 42 分钟内首次响应。',
      metricLabel: '关联页面', metricValue: '工单详情'
    },
    {
      title: '权益额度提醒', subtitle: '服务中心 · 今天 09:10', status: 'READ',
      summary: '本月流量权益剩余 20%', detail: '可在 Marketplace 查看扩展流量包。',
      metricLabel: '关联页面', metricValue: '权益详情'
    }
  ]
}

export class DemoHm7CapabilityRepository implements Hm7CapabilityRepositoryContract {
  private scenario: Hm3DemoScenario = 'NORMAL'
  private readonly records: Map<string, Hm7Record[]> = new Map<string, Hm7Record[]>()
  private sequence: number = 7000
  private requestSequence: number = 1

  setScenario(scenario: Hm3DemoScenario): void {
    this.scenario = scenario
  }

  reset(): void {
    this.records.clear()
    this.sequence = 7000
    this.requestSequence = 1
  }

  private key(context: Hm7RequestContext, capability: Hm7Capability): string {
    if (context.scope === 'PLATFORM') return `PLATFORM:${capability}`
    return `${context.tenantId}:${context.scope}:${context.userId}:${capability}`
  }

  private data(context: Hm7RequestContext, capability: Hm7Capability): Hm7Record[] {
    const key = this.key(context, capability)
    const existing = this.records.get(key)
    if (existing !== undefined) return existing
    const source = seeds(capability, context.scope)
    const created: Hm7Record[] = []
    source.forEach((seed: Hm7Seed) => {
      created.push({
        id: this.sequence++,
        capability: capability,
        tenantId: context.tenantId,
        ownerId: context.userId,
        title: seed.title,
        subtitle: seed.subtitle,
        status: seed.status,
        summary: seed.summary,
        detail: seed.detail,
        metricLabel: seed.metricLabel,
        metricValue: seed.metricValue,
        updatedAt: '2026-09-01 11:20'
      })
    })
    this.records.set(key, created)
    return created
  }

  private guard(context: Hm7RequestContext): void {
    if (context.scope === 'PLATFORM' &&
      (context.role !== 0 || context.contextType !== 'PLATFORM')) {
      throw new ApiError('当前账号无权访问平台计划能力', 403, 403, 'HM7_PLATFORM_FORBIDDEN')
    }
    if (context.scope === 'TENANT' &&
      (context.role > 1 || (context.contextType !== 'TENANT' &&
        context.contextType !== 'PLATFORM_TENANT'))) {
      throw new ApiError('当前账号无权访问租户计划能力', 403, 403, 'HM7_TENANT_FORBIDDEN')
    }
    if (context.scope === 'MEMBER' &&
      (context.role !== 2 || context.contextType !== 'TENANT')) {
      throw new ApiError('当前账号无权访问成员计划能力', 403, 403, 'HM7_MEMBER_FORBIDDEN')
    }
    if (context.scope !== 'PLATFORM' && context.tenantId.length === 0) {
      throw new ApiError('当前租户上下文无效', 409, 409, 'TENANT_CONTEXT_REQUIRED')
    }
    if (this.scenario === 'FORBIDDEN') {
      throw new ApiError('当前场景拒绝计划能力访问', 403, 403, 'HM7_SCENARIO_FORBIDDEN')
    }
    if (this.scenario === 'RATE_LIMITED') {
      throw new ApiError('计划能力请求过于频繁', 429, 429, 'HM7_SCENARIO_RATE_LIMITED', '', '3', true)
    }
    if (this.scenario === 'DEPENDENCY_DOWN') {
      throw new ApiError('计划能力依赖暂不可用', 503, 503, 'HM7_SCENARIO_DEPENDENCY_DOWN', '', '', true)
    }
  }

  private guardWrite(context: Hm7RequestContext, capability: Hm7Capability): void {
    this.guard(context)
    if (context.scope === 'TENANT' && context.role === 0) {
      if (capability === 'ENTITLEMENT') return
      throw new ApiError('平台代管仅可查看计划能力', 403, 403, 'PLATFORM_DELEGATE_READ_ONLY')
    }
    if (context.scope === 'TENANT' && context.tenantRole !== 'TENANT_OWNER' &&
      context.tenantRole !== 'TENANT_ADMIN') {
      throw new ApiError('当前组织角色无写入权限', 403, 403, 'TENANT_WRITE_FORBIDDEN')
    }
    if (this.scenario === 'CONFLICT') {
      throw new ApiError('记录已由其他操作更新', 409, 409, 'HM7_SCENARIO_CONFLICT')
    }
  }

  private requestId(): string {
    const value = `HM7-${String(this.requestSequence).padStart(4, '0')}`
    this.requestSequence += 1
    return value
  }

  async list(context: Hm7RequestContext, capability: Hm7Capability,
    keyword: string, status: string): Promise<Hm7Record[]> {
    this.guard(context)
    if (this.scenario === 'EMPTY') return []
    const normalizedKeyword = keyword.trim().toLowerCase()
    const source = this.data(context, capability)
    if (this.scenario === 'FILTER_EMPTY' && (normalizedKeyword.length > 0 || status.length > 0)) return []
    return source.filter((item: Hm7Record) => {
      const keywordMatch = normalizedKeyword.length === 0 ||
        item.title.toLowerCase().includes(normalizedKeyword) ||
        item.subtitle.toLowerCase().includes(normalizedKeyword)
      const statusMatch = status.length === 0 || item.status === status
      return keywordMatch && statusMatch
    }).map((item: Hm7Record) => cloneRecord(item))
  }

  async detail(context: Hm7RequestContext, capability: Hm7Capability, id: number): Promise<Hm7Record> {
    this.guard(context)
    const source = this.data(context, capability)
    const found = source.find((item: Hm7Record) => item.id === id) ?? source[0]
    if (found === undefined) {
      throw new ApiError('记录不存在', 404, 404, 'HM7_RECORD_NOT_FOUND')
    }
    return cloneRecord(found)
  }

  async save(context: Hm7RequestContext, capability: Hm7Capability,
    id: number, input: Hm7RecordInput): Promise<Hm7ActionResult> {
    this.guardWrite(context, capability)
    if (input.title.trim().length < 2) {
      throw new ApiError('标题至少需要 2 个字符', 400, 400, 'HM7_TITLE_REQUIRED')
    }
    const source = this.data(context, capability)
    let record = source.find((item: Hm7Record) => item.id === id)
    if (record === undefined) {
      record = {
        id: this.sequence++, capability: capability, tenantId: context.tenantId,
        ownerId: context.userId, title: input.title.trim(), subtitle: input.subtitle.trim(),
        status: 'DRAFT', summary: input.subtitle.trim(), detail: input.detail.trim(),
        metricLabel: '状态', metricValue: '草稿', updatedAt: '2026-09-01 11:36'
      }
      source.unshift(record)
    } else {
      record.title = input.title.trim()
      record.subtitle = input.subtitle.trim()
      record.summary = input.subtitle.trim()
      record.detail = input.detail.trim()
      record.updatedAt = '2026-09-01 11:36'
    }
    return { record: cloneRecord(record), requestId: this.requestId(), message: '已保存本地演示记录' }
  }

  async act(context: Hm7RequestContext, capability: Hm7Capability,
    id: number, action: string): Promise<Hm7ActionResult> {
    this.guardWrite(context, capability)
    const source = this.data(context, capability)
    const record = source.find((item: Hm7Record) => item.id === id) ?? source[0]
    if (record === undefined) {
      throw new ApiError('记录不存在', 404, 404, 'HM7_RECORD_NOT_FOUND')
    }
    if (action.includes('购买')) record.status = 'FULFILLING'
    else if (action.includes('发布')) record.status = 'PUBLISHED'
    else if (action.includes('上架')) record.status = 'ON_SALE'
    else if (action.includes('分派')) record.status = 'ASSIGNED'
    else if (action.includes('驳回')) record.status = 'REJECTED'
    else if (action.includes('转人工')) record.status = 'MANUAL'
    else if (action.includes('撤回') || action.includes('停用') || action.includes('下架')) record.status = 'INACTIVE'
    else if (action.includes('恢复')) record.status = 'RECOVERED'
    else if (action.includes('已读')) record.status = 'READ'
    else if (action.includes('关闭') || action.includes('解决')) record.status = 'RESOLVED'
    else if (action.includes('重新发送')) record.status = 'INVITED'
    else if (action.includes('发表评论')) {
      record.metricValue = String(Number(record.metricValue) + 1)
      record.status = 'PUBLISHED'
    }
    else record.status = 'ACTIVE'
    record.updatedAt = '2026-09-01 11:42'
    return {
      record: cloneRecord(record),
      requestId: this.requestId(),
      message: `${action}完成`
    }
  }
}

export class RealHm7CapabilityRepository implements Hm7CapabilityRepositoryContract {
  private pending(): ApiError {
    return new ApiError('真实计划能力接口等待公开契约', 503, 503, 'REAL_API_PENDING')
  }

  async list(_context: Hm7RequestContext, _capability: Hm7Capability,
    _keyword: string, _status: string): Promise<Hm7Record[]> {
    throw this.pending()
  }

  async detail(_context: Hm7RequestContext, _capability: Hm7Capability,
    _id: number): Promise<Hm7Record> {
    throw this.pending()
  }

  async save(_context: Hm7RequestContext, _capability: Hm7Capability,
    _id: number, _input: Hm7RecordInput): Promise<Hm7ActionResult> {
    throw this.pending()
  }

  async act(_context: Hm7RequestContext, _capability: Hm7Capability,
    _id: number, _action: string): Promise<Hm7ActionResult> {
    throw this.pending()
  }
}
