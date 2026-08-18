import http from '@ohos.net.http'
import {
  AuthResult,
  LoginByCodeRequest,
  LoginRequest,
  RegisterRequest,
  RegisterResult,
  ResetPasswordRequest,
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

  register(request: RegisterRequest): Promise<ApiSuccess<RegisterResult>> {
    return httpClient.request<RegisterResult>({
      method: http.RequestMethod.POST,
      path: '/auth/register',
      body: JSON.stringify(request)
    })
  }

  resetPassword(request: ResetPasswordRequest): Promise<ApiSuccess<Object | null>> {
    return httpClient.request<Object | null>({
      method: http.RequestMethod.POST,
      path: '/auth/reset-password',
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
