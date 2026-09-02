import http from '@ohos.net.http'
import { realApiPath, resolveRealApiPath } from '../config/RealApiCatalog'
import { ApiError } from '../model/ApiModels'
import {
  BlockTrafficRequest,
  DeviceCommandPageResult,
  DeviceCommandQuery,
  DeviceCommandRecord,
  DeviceCommandResult,
  DisconnectMacRequest,
  RestartDeviceRequest,
  isValidDeviceCommandRequestId
} from '../model/DeviceCommandModels'
import { sessionStore } from '../session/SessionStore'

function addQuery(query: string, name: string, value: string): string {
  return value.length === 0
    ? query
    : `${query}&${name}=${encodeURIComponent(value)}`
}

class DeviceCommandRepository {
  async restart(deviceCode: string, reason: string): Promise<DeviceCommandResult> {
    const body: RestartDeviceRequest = { reason: reason.trim() }
    const response = await sessionStore.authorizedRequest<DeviceCommandResult>(
      http.RequestMethod.POST,
      resolveRealApiPath('devices.kick', ['deviceCode'], [deviceCode]),
      JSON.stringify(body)
    )
    return this.validateSubmitResult(response.data, response.requestId)
  }

  async disconnectMac(deviceCode: string, mac: string): Promise<DeviceCommandResult> {
    const body: DisconnectMacRequest = { mac: mac.trim().toUpperCase() }
    const response = await sessionStore.authorizedRequest<DeviceCommandResult>(
      http.RequestMethod.POST,
      resolveRealApiPath('devices.disconnectMac', ['deviceCode'], [deviceCode]),
      JSON.stringify(body)
    )
    return this.validateSubmitResult(response.data, response.requestId)
  }

  async blockTraffic(deviceCode: string, dstIp: string, sni: string): Promise<DeviceCommandResult> {
    const body: BlockTrafficRequest = { dstIp: dstIp.trim() }
    if (sni.trim().length > 0) {
      body.sni = sni.trim()
    }
    const response = await sessionStore.authorizedRequest<DeviceCommandResult>(
      http.RequestMethod.POST,
      resolveRealApiPath('devices.blockTraffic', ['deviceCode'], [deviceCode]),
      JSON.stringify(body)
    )
    return this.validateSubmitResult(response.data, response.requestId)
  }

  async list(query: DeviceCommandQuery): Promise<DeviceCommandPageResult> {
    let params = `?current=${query.current}&size=${query.size}`
    params = addQuery(params, 'requestId', query.requestId.trim())
    params = addQuery(params, 'deviceCode', query.deviceCode.trim())
    const response = await sessionStore.authorizedRequest<DeviceCommandPageResult>(
      http.RequestMethod.GET,
      `${realApiPath('devices.commands')}${params}`
    )
    const result = response.data
    if (result === null || typeof result !== 'object' ||
      typeof result.total !== 'number' ||
      typeof result.current !== 'number' ||
      typeof result.size !== 'number' ||
      !Array.isArray(result.records)) {
      throw new ApiError('设备执行记录响应无效', 502, 502,
        'DEPENDENCY_PROTOCOL_INVALID', response.requestId)
    }
    for (const record of result.records) {
      if (record === null || typeof record !== 'object' ||
        typeof record.requestId !== 'string' ||
        typeof record.deviceCode !== 'string' ||
        typeof record.commandType !== 'string' ||
        typeof record.purpose !== 'string' ||
        typeof record.status !== 'number' ||
        !Number.isInteger(record.status) ||
        record.status < 0 || record.status > 5) {
        throw new ApiError('设备执行记录字段无效', 502, 502,
          'DEPENDENCY_PROTOCOL_INVALID', response.requestId)
      }
    }
    return result
  }

  async findByRequestId(deviceCode: string, requestId: string): Promise<DeviceCommandRecord | null> {
    const result = await this.list({
      current: 1,
      size: 1,
      requestId: requestId,
      deviceCode: deviceCode
    })
    if (result.records.length === 0) return null
    const record = result.records[0]
    if (record.requestId !== requestId || record.deviceCode !== deviceCode) {
      throw new ApiError('设备执行记录与查询条件不一致', 502, 502,
        'DEPENDENCY_PROTOCOL_INVALID')
    }
    return record
  }

  private validateSubmitResult(result: DeviceCommandResult, traceRequestId: string): DeviceCommandResult {
    if (result === null || typeof result !== 'object' ||
      typeof result.requestId !== 'string' ||
      !isValidDeviceCommandRequestId(result.requestId)) {
      throw new ApiError('命令提交响应缺少有效操作编号', 502, 502,
        'DEPENDENCY_PROTOCOL_INVALID', traceRequestId)
    }
    return result
  }
}

export const deviceCommandRepository = new DeviceCommandRepository()
