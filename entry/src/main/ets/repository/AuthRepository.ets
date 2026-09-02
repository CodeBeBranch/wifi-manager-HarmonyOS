import http from '@ohos.net.http'
import { realApiPath } from '../config/RealApiCatalog'
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
import { runtimeModeStore } from '../preview/RuntimeMode'

export class RealAuthRepository {
  login(request: LoginRequest): Promise<ApiSuccess<AuthResult>> {
    return httpClient.request<AuthResult>({
      method: http.RequestMethod.POST,
      path: realApiPath('auth.login'),
      body: JSON.stringify(request)
    })
  }

  loginByCode(request: LoginByCodeRequest): Promise<ApiSuccess<AuthResult>> {
    return httpClient.request<AuthResult>({
      method: http.RequestMethod.POST,
      path: realApiPath('auth.codeLogin'),
      body: JSON.stringify(request)
    })
  }

  sendVerifyCode(request: SendVerifyCodeRequest): Promise<ApiSuccess<Object | null>> {
    return httpClient.request<Object | null>({
      method: http.RequestMethod.POST,
      path: realApiPath('auth.codes'),
      body: JSON.stringify(request)
    })
  }

  register(request: RegisterRequest): Promise<ApiSuccess<RegisterResult>> {
    return httpClient.request<RegisterResult>({
      method: http.RequestMethod.POST,
      path: realApiPath('auth.register'),
      body: JSON.stringify(request)
    })
  }

  resetPassword(request: ResetPasswordRequest): Promise<ApiSuccess<Object | null>> {
    return httpClient.request<Object | null>({
      method: http.RequestMethod.POST,
      path: realApiPath('auth.resetPassword'),
      body: JSON.stringify(request)
    })
  }

  refresh(refreshCookie: string): Promise<ApiSuccess<AuthResult>> {
    return httpClient.request<AuthResult>({
      method: http.RequestMethod.POST,
      path: realApiPath('auth.refresh'),
      refreshCookie: refreshCookie
    })
  }

  logout(refreshCookie: string): Promise<ApiSuccess<Object | null>> {
    return httpClient.request<Object | null>({
      method: http.RequestMethod.POST,
      path: realApiPath('auth.logout'),
      refreshCookie: refreshCookie
    })
  }
}

export const realAuthRepository = new RealAuthRepository()

export interface PublicAuthRepositoryContract {
  sendVerifyCode(request: SendVerifyCodeRequest): Promise<ApiSuccess<Object | null>>
  register(request: RegisterRequest): Promise<ApiSuccess<RegisterResult>>
  resetPassword(request: ResetPasswordRequest): Promise<ApiSuccess<Object | null>>
}

class DemoPublicAuthRepository implements PublicAuthRepositoryContract {
  async sendVerifyCode(_request: SendVerifyCodeRequest): Promise<ApiSuccess<Object | null>> {
    return {
      data: null,
      refreshCookie: '',
      requestId: 'demo-verify-code'
    }
  }

  async register(_request: RegisterRequest): Promise<ApiSuccess<RegisterResult>> {
    return {
      data: {
        status: 'SUCCESS',
        message: '本地演示注册流程已完成',
        conflictFields: null
      },
      refreshCookie: '',
      requestId: 'demo-register'
    }
  }

  async resetPassword(_request: ResetPasswordRequest): Promise<ApiSuccess<Object | null>> {
    return {
      data: null,
      refreshCookie: '',
      requestId: 'demo-reset-password'
    }
  }
}

class PublicAuthRepositoryFactory {
  private readonly demo = new DemoPublicAuthRepository()

  current(): PublicAuthRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demo : realAuthRepository
  }
}

export const publicAuthRepositoryFactory = new PublicAuthRepositoryFactory()
