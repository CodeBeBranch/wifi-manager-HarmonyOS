import router from '@ohos.router'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { MainRootRouteId } from '../ui/MainNavigation'

const ROUTE_LOG_DOMAIN = 0x0000
let stagedRootPreviousPath: string | null = null
let stagedRootPreviousIndex: number = -1

const NOTICE_TARGET_ROUTES: string[] = [
  'pages/MainPage',
  'pages/ProfilePage',
  'pages/SecurityPage'
]

export function resetTo(url: string): void {
  router.replaceUrl({ url: url })
    .then((): void => router.clear())
    .catch(() => {})
}

export interface MainPageParams {
  rootRouteId: MainRootRouteId
}

export class MainRootRouteHandoff {
  private pending: MainRootRouteId | null = null

  prepare(rootRouteId: MainRootRouteId): void {
    this.pending = rootRouteId
  }

  clear(): void {
    this.pending = null
  }

  consume(params: MainPageParams | null | undefined): MainRootRouteId | null {
    const routeId = params === null || params === undefined
      ? null
      : params.rootRouteId
    if (routeId !== null && routeId !== undefined) {
      this.pending = null
      return routeId
    }
    const pending = this.pending
    this.pending = null
    return pending
  }
}

export type MainRootRouteListener = (rootRouteId: MainRootRouteId) => void

export class MainRootRouteNotifier {
  private listeners: MainRootRouteListener[] = []
  private pending: MainRootRouteId | null = null

  add(listener: MainRootRouteListener): void {
    if (!this.listeners.includes(listener)) {
      this.listeners.push(listener)
    }
    if (this.pending !== null) {
      const pending = this.pending
      this.pending = null
      listener(pending)
    }
  }

  remove(listener: MainRootRouteListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }

  publish(rootRouteId: MainRootRouteId): void {
    if (this.listeners.length === 0) {
      this.pending = rootRouteId
      return
    }
    this.pending = null
    this.listeners.slice().forEach((listener: MainRootRouteListener): void => {
      listener(rootRouteId)
    })
  }
}

const mainRootRouteHandoff = new MainRootRouteHandoff()
const mainRootRouteNotifier = new MainRootRouteNotifier()

export function addMainRootRouteListener(listener: MainRootRouteListener): void {
  mainRootRouteNotifier.add(listener)
}

export function removeMainRootRouteListener(listener: MainRootRouteListener): void {
  mainRootRouteNotifier.remove(listener)
}

export function mainRootRouteFromParams(
  params: MainPageParams | null | undefined
): MainRootRouteId | null {
  return mainRootRouteHandoff.consume(params)
}

export async function replaceRoot(url: string, params?: Object): Promise<void> {
  await router.replaceUrl({
    url: url,
    params: params
  })
  router.clear()
}

export async function stageRoot(url: string, params?: Object): Promise<void> {
  const previousState = router.getState()
  stagedRootPreviousPath = previousState.path
  stagedRootPreviousIndex = previousState.index
  try {
    await router.pushUrl({
      url: url,
      params: params
    })
  } catch (error) {
    stagedRootPreviousPath = null
    stagedRootPreviousIndex = -1
    throw error instanceof Error ? error : new Error('根页面暂存失败')
  }
}

export function commitStagedRoot(): void {
  router.clear()
  stagedRootPreviousPath = null
  stagedRootPreviousIndex = -1
}

export async function rollbackStagedRoot(): Promise<void> {
  const previousPath = stagedRootPreviousPath
  const previousIndex = stagedRootPreviousIndex
  router.back()
  for (let attempt = 0; attempt < 20; attempt += 1) {
    await new Promise<void>((resolve: () => void): void => {
      setTimeout(resolve, 50)
    })
    const currentState = router.getState()
    if (previousPath === null ||
      (currentState.path === previousPath && currentState.index === previousIndex)) {
      stagedRootPreviousPath = null
      stagedRootPreviousIndex = -1
      return
    }
  }
  stagedRootPreviousPath = null
  stagedRootPreviousIndex = -1
  throw new Error('暂存页面回退未完成')
}

export async function replaceMainRoot(rootRouteId: MainRootRouteId): Promise<void> {
  const params: MainPageParams = {
    rootRouteId: rootRouteId
  }
  mainRootRouteHandoff.prepare(rootRouteId)
  hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route', 'replace root start %{public}s', rootRouteId)
  try {
    await replaceRoot('pages/MainPage', params)
    hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route', 'replace root done %{public}s', rootRouteId)
    mainRootRouteNotifier.publish(rootRouteId)
  } catch (error) {
    mainRootRouteHandoff.clear()
    throw error instanceof Error ? error : new Error('根页面切换失败')
  }
}

export async function stageMainRoot(rootRouteId: MainRootRouteId): Promise<void> {
  const params: MainPageParams = {
    rootRouteId: rootRouteId
  }
  mainRootRouteHandoff.prepare(rootRouteId)
  hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route', 'stage root start %{public}s', rootRouteId)
  try {
    await stageRoot('pages/MainPage', params)
    hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route', 'stage root done %{public}s', rootRouteId)
    mainRootRouteNotifier.publish(rootRouteId)
  } catch (error) {
    mainRootRouteHandoff.clear()
    throw error instanceof Error ? error : new Error('根页面暂存失败')
  }
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
