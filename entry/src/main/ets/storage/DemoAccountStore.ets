import {
  AppNotice,
  DemoAccountState,
  SecuritySession,
  SocialIdentity,
  UserProfile
} from '../model/Hm1Models'
import { appPreferences } from './AppPreferences'

const DEMO_STATE_PREFIX = 'demo_account_state_v1_'
const DEMO_ACCOUNTS: string[] = ['superadmin', 'tenantadmin', 'member']

function accountLabel(username: string): string {
  if (username === 'superadmin') return '超级管理员'
  if (username === 'tenantadmin') return '租户管理员'
  return '普通成员'
}

function defaultNotices(username: string): AppNotice[] {
  return [
    {
      id: `${username}-notice-1`,
      category: '安全',
      title: '新设备登录提醒',
      summary: 'HarmonyOS 真机已登录本地演示账号',
      content: '本次登录来自当前 HarmonyOS 设备。演示模式没有发送任何网络请求。',
      createTime: '今天 09:32',
      read: false,
      targetRoute: 'pages/SecurityPage'
    },
    {
      id: `${username}-notice-2`,
      category: '服务',
      title: '服务状态摘要',
      summary: '边缘网络实验室运行状态正常',
      content: '设备、连接和告警均来自本地演示数据，真实服务升级完成后再执行独立联调。',
      createTime: '昨天 18:20',
      read: false,
      targetRoute: 'pages/MainPage'
    },
    {
      id: `${username}-notice-3`,
      category: '账号',
      title: '资料检查完成',
      summary: '账号基础资料已同步到本地演示空间',
      content: '你可以在资料页修改昵称、邮箱、手机号和部门，修改仅保存在 Demo 命名空间。',
      createTime: '周一 11:08',
      read: true,
      targetRoute: 'pages/ProfilePage'
    }
  ]
}

function defaultProfile(username: string): UserProfile {
  return {
    username: username,
    nickname: accountLabel(username),
    email: `${username}@wifi.local`,
    phone: '13800138000',
    department: username === 'superadmin' ? '平台运营' : '网络运维'
  }
}

function defaultSocialIdentities(): SocialIdentity[] {
  return [
    { provider: 'HUAWEI', label: '华为账号', account: '', bound: false },
    { provider: 'WECHAT', label: '微信', account: '演示用户', bound: true },
    { provider: 'GITHUB', label: 'GitHub', account: '', bound: false }
  ]
}

function defaultSecuritySessions(): SecuritySession[] {
  return [
    {
      id: 'current-harmony',
      deviceName: 'HarmonyOS 当前设备',
      location: '本机',
      lastActive: '刚刚',
      current: true
    },
    {
      id: 'desktop-browser',
      deviceName: '桌面浏览器',
      location: '上海',
      lastActive: '2 小时前',
      current: false
    }
  ]
}

function defaultState(username: string): DemoAccountState {
  return {
    notices: defaultNotices(username),
    profile: defaultProfile(username),
    socialIdentities: defaultSocialIdentities(),
    securitySessions: defaultSecuritySessions()
  }
}

class DemoAccountStore {
  private operation: Promise<void> = Promise.resolve()

  async load(username: string): Promise<DemoAccountState> {
    try {
      await this.operation
    } catch (_) {
    }
    return this.loadUnsafe(username)
  }

  private async loadUnsafe(username: string): Promise<DemoAccountState> {
    const normalized = username.trim() || 'member'
    const serialized = await appPreferences.getString(`${DEMO_STATE_PREFIX}${normalized}`)
    if (serialized.length === 0) {
      return defaultState(normalized)
    }
    try {
      return JSON.parse(serialized) as DemoAccountState
    } catch (_) {
      const state = defaultState(normalized)
      await this.save(normalized, state)
      return state
    }
  }

  async save(username: string, state: DemoAccountState): Promise<void> {
    await appPreferences.putString(
      `${DEMO_STATE_PREFIX}${username.trim() || 'member'}`,
      JSON.stringify(state)
    )
  }

  async update(
    username: string,
    updater: (state: DemoAccountState) => void
  ): Promise<DemoAccountState> {
    const previous = this.operation
    let result = defaultState(username)
    this.operation = (async (): Promise<void> => {
      try {
        await previous
      } catch (_) {
      }
      const state = await this.loadUnsafe(username)
      updater(state)
      await this.save(username, state)
      result = state
    })()
    await this.operation
    return result
  }

  async resetAll(): Promise<void> {
    const previous = this.operation
    this.operation = (async (): Promise<void> => {
      try {
        await previous
      } catch (_) {
      }
      for (const username of DEMO_ACCOUNTS) {
        await appPreferences.remove(`${DEMO_STATE_PREFIX}${username}`)
      }
    })()
    await this.operation
  }
}

export const demoAccountStore = new DemoAccountStore()
