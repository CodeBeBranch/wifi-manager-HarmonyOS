import http from '@ohos.net.http'
import { realApiPath, resolveRealApiPath } from '../config/RealApiCatalog'
import {
  AlertEvent,
  AlertPageResult,
  AlertQuery
} from '../model/AlertModels'
import { sessionStore } from '../session/SessionStore'

function addQuery(query: string, name: string, value: string): string {
  return value.length === 0
    ? query
    : `${query}&${name}=${encodeURIComponent(value)}`
}

class AlertRepository {
  async list(query: AlertQuery): Promise<AlertPageResult> {
    let params = `?current=${query.current}&size=${query.size}`
    params = addQuery(params, 'level', query.level)
    params = addQuery(params, 'status', query.status)
    params = addQuery(params, 'mac', query.mac.trim().toUpperCase())
    const response = await sessionStore.authorizedRequest<AlertPageResult>(
      http.RequestMethod.GET,
      `${realApiPath('alerts.list')}${params}`
    )
    return response.data
  }

  async detail(id: number): Promise<AlertEvent> {
    const response = await sessionStore.authorizedRequest<AlertEvent>(
      http.RequestMethod.GET,
      resolveRealApiPath('alerts.detail', ['alertId'], [String(id)])
    )
    return response.data
  }

  async handle(id: number): Promise<void> {
    await sessionStore.authorizedRequest<Object | null>(
      http.RequestMethod.POST,
      resolveRealApiPath('alerts.handle', ['alertId'], [String(id)]),
      undefined,
      'PATCH'
    )
  }
}

export const alertRepository = new AlertRepository()
