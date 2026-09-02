import http from '@ohos.net.http'
import { realApiPath } from '../config/RealApiCatalog'
import { PlatformTenantPageResult } from '../model/TenantModels'
import { sessionStore } from '../session/SessionStore'

class TenantRepository {
  async listPlatformTenants(
    current: number,
    size: number,
    keyword: string
  ): Promise<PlatformTenantPageResult> {
    const query = keyword.trim().length > 0
      ? `&keyword=${encodeURIComponent(keyword.trim())}`
      : ''
    const response = await sessionStore.authorizedRequest<PlatformTenantPageResult>(
      http.RequestMethod.GET,
      `${realApiPath('platform.tenants')}?current=${current}&size=${size}${query}`
    )
    return response.data
  }
}

export const tenantRepository = new TenantRepository()
