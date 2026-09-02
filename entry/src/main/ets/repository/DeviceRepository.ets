import http from '@ohos.net.http'
import { realApiPath, resolveRealApiPath } from '../config/RealApiCatalog'
import { DeviceNode, DevicePageResult } from '../model/DeviceModels'
import { sessionStore } from '../session/SessionStore'

class DeviceRepository {
  async list(current: number, size: number, keyword: string): Promise<DevicePageResult> {
    const query = keyword.trim().length > 0
      ? `&keyword=${encodeURIComponent(keyword.trim())}`
      : ''
    const response = await sessionStore.authorizedRequest<DevicePageResult>(
      http.RequestMethod.GET,
      `${realApiPath('devices.list')}?current=${current}&size=${size}${query}`
    )
    return response.data
  }

  async detail(nodeId: string): Promise<DeviceNode> {
    const response = await sessionStore.authorizedRequest<DeviceNode>(
      http.RequestMethod.GET,
      resolveRealApiPath('devices.detail', ['nodeId'], [nodeId])
    )
    return response.data
  }
}

export const deviceRepository = new DeviceRepository()
