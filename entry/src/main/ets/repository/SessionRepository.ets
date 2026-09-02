import http from '@ohos.net.http'
import { realApiPath, resolveRealApiPath } from '../config/RealApiCatalog'
import {
  NetworkSession,
  SessionPageResult,
  SessionQuery
} from '../model/SessionModels'
import { sessionStore } from '../session/SessionStore'

function addQuery(query: string, name: string, value: string): string {
  return value.length === 0
    ? query
    : `${query}&${name}=${encodeURIComponent(value)}`
}

class SessionRepository {
  async list(query: SessionQuery, admin: boolean): Promise<SessionPageResult> {
    let params = `?current=${query.current}&size=${query.size}`
    params = addQuery(params, 'mac', query.mac.trim().toUpperCase())
    params = addQuery(params, 'nodeId', query.nodeId.trim())
    if (admin) {
      params = addQuery(params, 'userId', query.userId.trim())
    }
    params = addQuery(params, 'status', query.status)

    const path = realApiPath(admin ? 'sessions.admin' : 'sessions.mine')
    const response = await sessionStore.authorizedRequest<SessionPageResult>(
      http.RequestMethod.GET,
      `${path}${params}`
    )
    return response.data
  }

  async close(sessionId: number, admin: boolean): Promise<NetworkSession> {
    const path = resolveRealApiPath(
      admin ? 'sessions.revoke' : 'sessions.logout',
      ['sessionId'],
      [String(sessionId)])
    const response = await sessionStore.authorizedRequest<NetworkSession>(
      http.RequestMethod.POST,
      path
    )
    return response.data
  }
}

export const sessionRepository = new SessionRepository()
