import http from '@ohos.net.http'
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

    const path = admin ? '/admin/sessions' : '/sessions'
    const response = await sessionStore.authorizedRequest<SessionPageResult>(
      http.RequestMethod.GET,
      `${path}${params}`
    )
    return response.data
  }

  async close(sessionId: number, admin: boolean): Promise<NetworkSession> {
    const action = admin ? 'revoke' : 'logout'
    const path = admin ? '/admin/sessions' : '/sessions'
    const response = await sessionStore.authorizedRequest<NetworkSession>(
      http.RequestMethod.POST,
      `${path}/${sessionId}/${action}`
    )
    return response.data
  }
}

export const sessionRepository = new SessionRepository()
