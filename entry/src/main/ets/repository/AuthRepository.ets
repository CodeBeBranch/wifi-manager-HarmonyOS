import http from '@ohos.net.http'
import {
  AuthResult,
  LoginByCodeRequest,
  LoginRequest,
  SendVerifyCodeRequest
} from '../model/AuthModels'
import { ApiSuccess } from '../model/ApiModels'
import { httpClient } from '../network/HttpClient'

class AuthRepository {
  login(request: LoginRequest): Promise<ApiSuccess<AuthResult>> {
    return httpClient.request<AuthResult>({
      method: http.RequestMethod.POST,
      path: '/auth/login',
      body: JSON.stringify(request)
    })
  }

  loginByCode(request: LoginByCodeRequest): Promise<ApiSuccess<AuthResult>> {
    return httpClient.request<AuthResult>({
      method: http.RequestMethod.POST,
      path: '/auth/code-login',
      body: JSON.stringify(request)
    })
  }

  sendVerifyCode(request: SendVerifyCodeRequest): Promise<ApiSuccess<Object | null>> {
    return httpClient.request<Object | null>({
      method: http.RequestMethod.POST,
      path: '/auth/codes',
      body: JSON.stringify(request)
    })
  }

  refresh(refreshCookie: string): Promise<ApiSuccess<AuthResult>> {
    return httpClient.request<AuthResult>({
      method: http.RequestMethod.POST,
      path: '/auth/refresh',
      refreshCookie: refreshCookie
    })
  }

  logout(refreshCookie: string): Promise<ApiSuccess<Object | null>> {
    return httpClient.request<Object | null>({
      method: http.RequestMethod.POST,
      path: '/auth/logout',
      refreshCookie: refreshCookie
    })
  }
}

export const authRepository = new AuthRepository()
