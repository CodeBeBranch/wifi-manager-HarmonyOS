import router from '@ohos.router'

const NOTICE_TARGET_ROUTES: string[] = [
  'pages/MainPage',
  'pages/ProfilePage',
  'pages/SecurityPage'
]

export function resetTo(url: string): void {
  router.clear()
  router.replaceUrl({ url: url }).catch(() => {})
}

export function resetToLogin(): void {
  resetTo('pages/LoginPage')
}

export function resetToMain(): void {
  resetTo('pages/MainPage')
}

export function resolveNoticeTargetRoute(targetRoute: string): string {
  return NOTICE_TARGET_ROUTES.includes(targetRoute)
    ? targetRoute
    : 'pages/MainPage'
}
