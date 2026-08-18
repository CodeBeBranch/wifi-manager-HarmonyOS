import http from '@ohos.net.http'
import { DeviceNode, DevicePageResult } from '../model/DeviceModels'
import { sessionStore } from '../session/SessionStore'

class DeviceRepository {
  async list(current: number, size: number, keyword: string): Promise<DevicePageResult> {
    const query = keyword.trim().length > 0
      ? `&keyword=${encodeURIComponent(keyword.trim())}`
      : ''
    const response = await sessionStore.authorizedRequest<DevicePageResult>(
      http.RequestMethod.GET,
      `/admin/devices?current=${current}&size=${size}${query}`
    )
    return response.data
  }

  async detail(nodeId: string): Promise<DeviceNode> {
    const response = await sessionStore.authorizedRequest<DeviceNode>(
      http.RequestMethod.GET,
      `/admin/devices/${encodeURIComponent(nodeId)}`
    )
    return response.data
  }
}

export const deviceRepository = new DeviceRepository()
