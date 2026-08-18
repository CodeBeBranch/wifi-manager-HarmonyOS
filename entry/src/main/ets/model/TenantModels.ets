export interface PlatformTenant {
  tenantId: string
  tenantCode: string
  name: string
  status: string
  timezone: string
  ownerUserId: string
  contextVersion: number
  version: number
  memberCount: number
  subscriptionStatus: string
  createTime: string | null
  updateTime: string | null
}

export interface PlatformTenantPageResult {
  total: number
  current: number
  size: number
  records: PlatformTenant[]
}
