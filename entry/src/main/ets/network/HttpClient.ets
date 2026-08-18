import http from '@ohos.net.http'
import util from '@ohos.util'
import {
  AccessRequestHeaders,
  ApiError,
  ApiSuccess,
  CookieRequestHeaders,
  PublicRequestHeaders
} from '../model/ApiModels'
import { runtimeSettings } from '../storage/RuntimeSettings'
import { runtimeModeStore } from '../preview/RuntimeMode'
import { extractRefreshCookie, parseApiResponse } from './ApiParser'
import { networkTransportFactory } from './TransportFactory'

export interface ApiRequest {
  method: http.RequestMethod
  customMethod?: string
  path: string
  body?: string
  accessToken?: string
  refreshCookie?: string
}

class HttpClient {
  private activeClients: http.HttpRequest[] = []

  constructor() {
    runtimeModeStore.addListener((): void => {
      this.cancelAll()
    })
  }

  private buildHeaders(request: ApiRequest): Object {
    const clientInstanceId = runtimeSettings.getClientInstanceId()
    const requestId = util.generateRandomUUID()
    if (request.accessToken !== undefined && request.accessToken.length > 0) {
      const accessHeaders: AccessRequestHeaders = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Client-Instance-Id': clientInstanceId,
        'X-Request-Id': requestId,
        'Authorization': `Bearer ${request.accessToken}`
      }
      return accessHeaders
    }
    if (request.refreshCookie !== undefined && request.refreshCookie.length > 0) {
      const cookieHeaders: CookieRequestHeaders = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Client-Instance-Id': clientInstanceId,
        'X-Request-Id': requestId,
        'Cookie': request.refreshCookie
      }
      return cookieHeaders
    }
    const publicHeaders: PublicRequestHeaders = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Client-Instance-Id': clientInstanceId,
      'X-Request-Id': requestId
    }
    return publicHeaders
  }

  async request<T>(request: ApiRequest): Promise<ApiSuccess<T>> {
    runtimeModeStore.guardNetwork('HTTP')
    const client = networkTransportFactory.createHttp()
    this.activeClients.push(client)
    const headers = this.buildHeaders(request)

    try {
      const response = await client.request(
        `${runtimeSettings.getGatewayUrl()}${request.path}`,
        {
          method: request.method,
          customMethod: request.customMethod,
          header: headers,
          extraData: request.body,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 15000,
          readTimeout: 15000,
          usingCache: false
        }
      )
      const responseText = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result)
      return parseApiResponse<T>(
        responseText,
        Number(response.responseCode),
        JSON.stringify(response.header),
        extractRefreshCookie(response.cookies)
      )
    } catch (error) {
      if (error instanceof ApiError) {
        throw error
      }
      throw new ApiError('无法连接服务，请检查网络后重试', 0, 0, '', '', '', true)
    } finally {
      this.removeClient(client)
      client.destroy()
    }
  }

  cancelAll(): void {
    const clients = this.activeClients.slice()
    this.activeClients = []
    for (const client of clients) {
      try {
        client.destroy()
      } catch (_) {
      }
    }
  }

  private removeClient(client: http.HttpRequest): void {
    const index = this.activeClients.indexOf(client)
    if (index >= 0) {
      this.activeClients.splice(index, 1)
    }
  }
}

export const httpClient = new HttpClient()
