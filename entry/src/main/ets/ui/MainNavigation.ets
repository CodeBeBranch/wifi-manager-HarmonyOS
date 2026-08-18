import { SessionSnapshot } from '../model/AuthModels'

export const MAIN_PAGE_URL: string = 'pages/MainPage'

export type MainTabKey =
  'HOME' |
  'ORGANIZATIONS' |
  'ACCOUNTS' |
  'DEVICES' |
  'ALERTS' |
  'CONNECTIONS' |
  'SERVICES' |
  'ME'

export type MainRootRouteId =
  'platform/home' |
  'platform/tenants' |
  'platform/accounts' |
  'platform/services' |
  'tenant/home' |
  'tenant/devices' |
  'tenant/alerts' |
  'tenant/services' |
  'member/home' |
  'member/connections' |
  'member/services' |
  'me/home'

export interface MainTab {
  key: MainTabKey
  label: string
  routeId: MainRootRouteId
}

const PLATFORM_TABS: MainTab[] = [
  { key: 'HOME', label: '首页', routeId: 'platform/home' },
  { key: 'ORGANIZATIONS', label: '组织', routeId: 'platform/tenants' },
  { key: 'ACCOUNTS', label: '账号', routeId: 'platform/accounts' },
  { key: 'SERVICES', label: '服务', routeId: 'platform/services' },
  { key: 'ME', label: '我的', routeId: 'me/home' }
]

const TENANT_ADMIN_TABS: MainTab[] = [
  { key: 'HOME', label: '首页', routeId: 'tenant/home' },
  { key: 'DEVICES', label: '设备', routeId: 'tenant/devices' },
  { key: 'ALERTS', label: '告警', routeId: 'tenant/alerts' },
  { key: 'SERVICES', label: '服务', routeId: 'tenant/services' },
  { key: 'ME', label: '我的', routeId: 'me/home' }
]

const MEMBER_TABS: MainTab[] = [
  { key: 'HOME', label: '首页', routeId: 'member/home' },
  { key: 'CONNECTIONS', label: '连接', routeId: 'member/connections' },
  { key: 'SERVICES', label: '服务', routeId: 'member/services' },
  { key: 'ME', label: '我的', routeId: 'me/home' }
]

export function hasTenantWorkspace(snapshot: SessionSnapshot): boolean {
  const contextType = snapshot.context?.contextType ?? ''
  return contextType === 'TENANT' || contextType === 'PLATFORM_TENANT'
}

export function canReadAdminWorkspace(snapshot: SessionSnapshot): boolean {
  return hasTenantWorkspace(snapshot) && (snapshot.role === 0 || snapshot.role === 1)
}

export function isPlatformWorkspace(snapshot: SessionSnapshot): boolean {
  return snapshot.role === 0 && snapshot.context?.contextType === 'PLATFORM'
}

export function isManagedTenantWorkspace(snapshot: SessionSnapshot): boolean {
  return snapshot.role === 0 && snapshot.context?.contextType === 'PLATFORM_TENANT'
}

export function roleLabel(role: number): string {
  if (role === 0) return '超级管理员'
  if (role === 1) return '租户管理员'
  if (role === 2) return '成员'
  return '未知角色'
}

export function workspaceTitle(snapshot: SessionSnapshot): string {
  if (isPlatformWorkspace(snapshot)) return '系统管理'
  return snapshot.context?.tenantName || '工作区'
}

export function mainTabs(snapshot: SessionSnapshot): MainTab[] {
  if (isPlatformWorkspace(snapshot)) {
    return PLATFORM_TABS.slice()
  }
  if (canReadAdminWorkspace(snapshot)) {
    return TENANT_ADMIN_TABS.slice()
  }
  return MEMBER_TABS.slice()
}

export function mainTabKey(snapshot: SessionSnapshot, index: number): MainTabKey {
  const tabs = mainTabs(snapshot)
  const normalizedIndex = Math.max(0, Math.min(index, tabs.length - 1))
  return tabs[normalizedIndex].key
}

export function mainRootRouteId(snapshot: SessionSnapshot, index: number): MainRootRouteId {
  const tabs = mainTabs(snapshot)
  const normalizedIndex = Math.max(0, Math.min(index, tabs.length - 1))
  return tabs[normalizedIndex].routeId
}

export function mainTabRenderKey(snapshot: SessionSnapshot, tab: MainTab): string {
  const contextType = snapshot.context?.contextType ?? 'NONE'
  return `${snapshot.role}:${contextType}:${tab.routeId}`
}
