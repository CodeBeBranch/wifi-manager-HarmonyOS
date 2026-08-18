import { ApiError } from '../model/ApiModels'
import {
  AppNotice,
  SecuritySession,
  SocialIdentity,
  UserProfile
} from '../model/Hm1Models'
import { runtimeModeStore } from '../preview/RuntimeMode'
import { demoAccountStore } from '../storage/DemoAccountStore'

export interface AccountRepositoryContract {
  listNotices(username: string): Promise<AppNotice[]>
  noticeDetail(username: string, id: string): Promise<AppNotice>
  markNoticeRead(username: string, id: string): Promise<void>
  markAllNoticesRead(username: string): Promise<void>
  getProfile(username: string): Promise<UserProfile>
  updateProfile(username: string, profile: UserProfile): Promise<UserProfile>
  listSocialIdentities(username: string): Promise<SocialIdentity[]>
  setSocialIdentity(username: string, provider: string, bound: boolean): Promise<SocialIdentity[]>
  listSecuritySessions(username: string): Promise<SecuritySession[]>
  revokeOtherSessions(username: string): Promise<SecuritySession[]>
  changePassword(username: string, currentPassword: string, newPassword: string): Promise<void>
  resetDemo(): Promise<void>
}

function realPending(): ApiError {
  return new ApiError(
    '该能力等待真实环境契约冻结后开放',
    503,
    503,
    'REAL_CONTRACT_PENDING'
  )
}

class RealAccountRepository implements AccountRepositoryContract {
  async listNotices(_username: string): Promise<AppNotice[]> {
    throw realPending()
  }

  async noticeDetail(_username: string, _id: string): Promise<AppNotice> {
    throw realPending()
  }

  async markNoticeRead(_username: string, _id: string): Promise<void> {
    throw realPending()
  }

  async markAllNoticesRead(_username: string): Promise<void> {
    throw realPending()
  }

  async getProfile(_username: string): Promise<UserProfile> {
    throw realPending()
  }

  async updateProfile(_username: string, _profile: UserProfile): Promise<UserProfile> {
    throw realPending()
  }

  async listSocialIdentities(_username: string): Promise<SocialIdentity[]> {
    throw realPending()
  }

  async setSocialIdentity(
    _username: string,
    _provider: string,
    _bound: boolean
  ): Promise<SocialIdentity[]> {
    throw realPending()
  }

  async listSecuritySessions(_username: string): Promise<SecuritySession[]> {
    throw realPending()
  }

  async revokeOtherSessions(_username: string): Promise<SecuritySession[]> {
    throw realPending()
  }

  async changePassword(
    _username: string,
    _currentPassword: string,
    _newPassword: string
  ): Promise<void> {
    throw realPending()
  }

  async resetDemo(): Promise<void> {
    throw realPending()
  }
}

class DemoAccountRepository implements AccountRepositoryContract {
  async listNotices(username: string): Promise<AppNotice[]> {
    const state = await demoAccountStore.load(username)
    return state.notices.slice()
  }

  async noticeDetail(username: string, id: string): Promise<AppNotice> {
    const notices = await this.listNotices(username)
    const notice = notices.find((item: AppNotice): boolean => item.id === id)
    if (notice === undefined) {
      throw new ApiError('没有找到通知', 404, 404, 'NOTICE_NOT_FOUND')
    }
    return notice
  }

  async markNoticeRead(username: string, id: string): Promise<void> {
    await demoAccountStore.update(username, (state): void => {
      const notice = state.notices.find((item: AppNotice): boolean => item.id === id)
      if (notice === undefined) {
        throw new ApiError('没有找到通知', 404, 404, 'NOTICE_NOT_FOUND')
      }
      notice.read = true
    })
  }

  async markAllNoticesRead(username: string): Promise<void> {
    await demoAccountStore.update(username, (state): void => {
      for (const notice of state.notices) {
        notice.read = true
      }
    })
  }

  async getProfile(username: string): Promise<UserProfile> {
    const state = await demoAccountStore.load(username)
    return state.profile
  }

  async updateProfile(username: string, profile: UserProfile): Promise<UserProfile> {
    const state = await demoAccountStore.update(username, (current): void => {
      current.profile = profile
    })
    return state.profile
  }

  async listSocialIdentities(username: string): Promise<SocialIdentity[]> {
    const state = await demoAccountStore.load(username)
    return state.socialIdentities.slice()
  }

  async setSocialIdentity(
    username: string,
    provider: string,
    bound: boolean
  ): Promise<SocialIdentity[]> {
    const state = await demoAccountStore.update(username, (current): void => {
      const identity = current.socialIdentities.find(
        (item: SocialIdentity): boolean => item.provider === provider
      )
      if (identity === undefined) {
        throw new ApiError('没有找到社交身份', 404, 404, 'SOCIAL_IDENTITY_NOT_FOUND')
      }
      identity.bound = bound
      identity.account = bound ? '演示用户' : ''
    })
    return state.socialIdentities.slice()
  }

  async listSecuritySessions(username: string): Promise<SecuritySession[]> {
    const state = await demoAccountStore.load(username)
    return state.securitySessions.slice()
  }

  async revokeOtherSessions(username: string): Promise<SecuritySession[]> {
    const state = await demoAccountStore.update(username, (current): void => {
      current.securitySessions = current.securitySessions.filter(
        (item: SecuritySession): boolean => item.current
      )
    })
    return state.securitySessions.slice()
  }

  async changePassword(
    _username: string,
    currentPassword: string,
    newPassword: string
  ): Promise<void> {
    if (currentPassword !== '123456') {
      throw new ApiError('当前密码不正确', 400, 400, 'CURRENT_PASSWORD_INVALID')
    }
    if (newPassword.length < 6 || newPassword.length > 20) {
      throw new ApiError('新密码长度需要在 6 到 20 位之间', 400, 400, 'PASSWORD_INVALID')
    }
  }

  async resetDemo(): Promise<void> {
    await demoAccountStore.resetAll()
  }
}

class AccountRepositoryFactory {
  private readonly demo = new DemoAccountRepository()
  private readonly real = new RealAccountRepository()

  current(): AccountRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demo : this.real
  }
}

export const accountRepositoryFactory = new AccountRepositoryFactory()
