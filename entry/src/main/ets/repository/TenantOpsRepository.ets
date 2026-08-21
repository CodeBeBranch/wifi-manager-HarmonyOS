import { ApiError } from '../model/ApiModels'
import { BlacklistEntry, BlacklistQuery } from '../model/Hm3Models'

export interface TenantOpsRepositoryContract {
  listBlacklist(tenantId: string, query: BlacklistQuery): Promise<BlacklistEntry[]>
  addBlacklist(tenantId: string, mac: string, reason: string): Promise<BlacklistEntry>
  removeBlacklist(tenantId: string, id: number): Promise<void>
  resetDemo(): Promise<void>
}

function nowText(): string {
  return '2026-08-19 20:00:00'
}

function copyEntry(entry: BlacklistEntry): BlacklistEntry {
  return {
    id: entry.id,
    tenantId: entry.tenantId,
    mac: entry.mac,
    reason: entry.reason,
    status: entry.status,
    createdAt: entry.createdAt
  }
}

function seedEntries(tenantId: string): BlacklistEntry[] {
  if (tenantId !== 'preview-tenant-01') return []
  return [
    {
      id: 1,
      tenantId: tenantId,
      mac: 'AA:BB:CC:11:22:33',
      reason: '异常流量，等待管理员复核',
      status: 'ACTIVE',
      createdAt: '2026-08-18 10:24:00'
    },
    {
      id: 2,
      tenantId: tenantId,
      mac: 'AA:BB:CC:44:55:66',
      reason: '重复认证失败',
      status: 'ACTIVE',
      createdAt: '2026-08-17 16:40:00'
    }
  ]
}

export class DemoTenantOpsRepository implements TenantOpsRepositoryContract {
  private readonly entriesByTenant: Map<string, BlacklistEntry[]> = new Map()
  private nextId: number = 100

  private entries(tenantId: string): BlacklistEntry[] {
    const existing = this.entriesByTenant.get(tenantId)
    if (existing !== undefined) return existing
    const seeded = seedEntries(tenantId)
    this.entriesByTenant.set(tenantId, seeded)
    return seeded
  }

  async listBlacklist(tenantId: string, query: BlacklistQuery): Promise<BlacklistEntry[]> {
    const keyword = query.keyword.trim().toLowerCase()
    return this.entries(tenantId)
      .filter((entry: BlacklistEntry): boolean =>
        keyword.length === 0 ||
        entry.mac.toLowerCase().includes(keyword) ||
        entry.reason.toLowerCase().includes(keyword))
      .map((entry: BlacklistEntry): BlacklistEntry => copyEntry(entry))
  }

  async addBlacklist(tenantId: string, mac: string, reason: string): Promise<BlacklistEntry> {
    const normalizedMac = mac.trim().toUpperCase()
    const normalizedReason = reason.trim()
    if (!/^[0-9A-F]{2}(:[0-9A-F]{2}){5}$/.test(normalizedMac)) {
      throw new ApiError('MAC 地址格式不正确', 400, 400, 'BLACKLIST_MAC_INVALID')
    }
    if (normalizedReason.length < 2 || normalizedReason.length > 120) {
      throw new ApiError('请输入 2 到 120 个字符的加入原因', 400, 400, 'BLACKLIST_REASON_INVALID')
    }
    const entries = this.entries(tenantId)
    if (entries.some((entry: BlacklistEntry): boolean => entry.mac === normalizedMac)) {
      throw new ApiError('该 MAC 已在黑名单中', 409, 409, 'BLACKLIST_DUPLICATE')
    }
    const entry: BlacklistEntry = {
      id: this.nextId++,
      tenantId: tenantId,
      mac: normalizedMac,
      reason: normalizedReason,
      status: 'ACTIVE',
      createdAt: nowText()
    }
    entries.unshift(entry)
    return copyEntry(entry)
  }

  async removeBlacklist(tenantId: string, id: number): Promise<void> {
    const entries = this.entries(tenantId)
    const index = entries.findIndex((entry: BlacklistEntry): boolean => entry.id === id)
    if (index < 0) {
      throw new ApiError('黑名单记录不存在', 404, 404, 'BLACKLIST_NOT_FOUND')
    }
    entries.splice(index, 1)
  }

  async resetDemo(): Promise<void> {
    this.entriesByTenant.clear()
    this.nextId = 100
  }
}

export class RealTenantOpsRepository implements TenantOpsRepositoryContract {
  private pending(): ApiError {
    return new ApiError(
      '真实黑名单接口等待后端契约确认',
      501,
      501,
      'REAL_API_PENDING'
    )
  }

  async listBlacklist(_tenantId: string, _query: BlacklistQuery): Promise<BlacklistEntry[]> {
    throw this.pending()
  }

  async addBlacklist(
    _tenantId: string,
    _mac: string,
    _reason: string
  ): Promise<BlacklistEntry> {
    throw this.pending()
  }

  async removeBlacklist(_tenantId: string, _id: number): Promise<void> {
    throw this.pending()
  }

  async resetDemo(): Promise<void> {
    return
  }
}
