import http from '@ohos.net.http'
import { resolveRealApiPath } from '../config/RealApiCatalog'
import { ApiError } from '../model/ApiModels'
import {
  WifiConfigStageRequest,
  WifiConfigTask,
  isValidWifiConfigRequestId,
  utf8ByteLength
} from '../model/WifiConfigModels'
import { sessionStore } from '../session/SessionStore'

class WifiConfigRepository {
  async stage(deviceCode: string, ssid: string, password: string): Promise<WifiConfigTask> {
    const body: WifiConfigStageRequest = {
      ssid: ssid.trim(),
      password: password
    }
    const response = await sessionStore.authorizedRequest<WifiConfigTask>(
      http.RequestMethod.POST,
      resolveRealApiPath('devices.wifiCandidate', ['deviceCode'], [deviceCode]),
      JSON.stringify(body)
    )
    return this.validateTask(response.data, deviceCode, '', response.requestId)
  }

  async latest(deviceCode: string): Promise<WifiConfigTask | null> {
    const response = await sessionStore.authorizedRequest<WifiConfigTask | null>(
      http.RequestMethod.GET,
      resolveRealApiPath('devices.wifiLatest', ['deviceCode'], [deviceCode])
    )
    if (response.data === null) return null
    return this.validateTask(response.data, deviceCode, '', response.requestId)
  }

  async find(deviceCode: string, requestId: string): Promise<WifiConfigTask> {
    const response = await sessionStore.authorizedRequest<WifiConfigTask>(
      http.RequestMethod.GET,
      resolveRealApiPath(
        'devices.wifiTask', ['deviceCode', 'requestId'], [deviceCode, requestId])
    )
    return this.validateTask(response.data, deviceCode, requestId, response.requestId)
  }

  private validateTask(
    task: WifiConfigTask,
    expectedDeviceCode: string,
    expectedRequestId: string,
    traceRequestId: string
  ): WifiConfigTask {
    if (task === null || typeof task !== 'object' ||
      typeof task.wifiConfigId !== 'number' || !Number.isInteger(task.wifiConfigId) ||
      task.wifiConfigId < 1 ||
      typeof task.nodeId !== 'number' || !Number.isInteger(task.nodeId) || task.nodeId < 1 ||
      typeof task.deviceCode !== 'string' || task.deviceCode !== expectedDeviceCode ||
      typeof task.requestId !== 'string' || !isValidWifiConfigRequestId(task.requestId) ||
      (expectedRequestId.length > 0 && task.requestId !== expectedRequestId) ||
      typeof task.configVersion !== 'number' || !Number.isInteger(task.configVersion) ||
      task.configVersion < 1 || task.configVersion > 0xFFFFFFFF ||
      typeof task.ssid !== 'string' || utf8ByteLength(task.ssid) < 1 ||
      utf8ByteLength(task.ssid) > 32 || task.ssid.indexOf('\0') >= 0 ||
      typeof task.passwordConfigured !== 'boolean' ||
      typeof task.status !== 'number' || !Number.isInteger(task.status) ||
      task.status < 0 || task.status > 5 ||
      typeof task.statusName !== 'string' ||
      !this.isNullableString(task.stagedTime) ||
      !this.isNullableString(task.activatedTime) ||
      !this.isNullableString(task.failureMessage) ||
      !this.isNullableString(task.createTime) ||
      !this.isNullableString(task.updateTime)) {
      throw new ApiError('WiFi 配置任务响应无效', 502, 502,
        'DEPENDENCY_PROTOCOL_INVALID', traceRequestId)
    }
    return task
  }

  private isNullableString(value: string | null): boolean {
    return value === null || typeof value === 'string'
  }
}

export const wifiConfigRepository = new WifiConfigRepository()
