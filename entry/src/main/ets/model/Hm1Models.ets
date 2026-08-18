export interface AppNotice {
  id: string
  category: string
  title: string
  summary: string
  content: string
  createTime: string
  read: boolean
  targetRoute: string
}

export interface UserProfile {
  username: string
  nickname: string
  email: string
  phone: string
  department: string
}

export interface SocialIdentity {
  provider: string
  label: string
  account: string
  bound: boolean
}

export interface SecuritySession {
  id: string
  deviceName: string
  location: string
  lastActive: string
  current: boolean
}

export interface DemoAccountState {
  notices: AppNotice[]
  profile: UserProfile
  socialIdentities: SocialIdentity[]
  securitySessions: SecuritySession[]
}

export function unreadNoticeCount(notices: AppNotice[]): number {
  return notices.filter((notice: AppNotice): boolean => !notice.read).length
}
