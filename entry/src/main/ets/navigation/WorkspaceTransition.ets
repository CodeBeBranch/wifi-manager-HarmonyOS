import { PlatformTenantDetailParams } from '../model/Hm2Models'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { platformAdminRepositoryFactory } from '../repository/PlatformAdminRepository'
import { sessionStore } from '../session/SessionStore'
import {
  commitStagedRoot,
  rollbackStagedRoot,
  stageMainRoot,
  stageRoot
} from './AppRouter'

let transitionActive: boolean = false
const ROUTE_LOG_DOMAIN = 0x0000

export function isWorkspaceTransitionActive(): boolean {
  return transitionActive
}

export interface WorkspaceTransitionSteps {
  switchContext(): Promise<void>
  stageRoot(): Promise<void>
  commitRoot(): void
  rollbackRoot(): Promise<void>
  rollbackContext(): Promise<void>
  commitCache(): void
  rollbackCache(): void
}

export class WorkspaceTransitionPlan implements WorkspaceTransitionSteps {
  private readonly switchAction: () => Promise<void>
  private readonly stageAction: () => Promise<void>
  private readonly commitRootAction: () => void
  private readonly rollbackRootAction: () => Promise<void>
  private readonly rollbackAction: () => Promise<void>
  private readonly commitCacheAction: () => void
  private readonly rollbackCacheAction: () => void

  constructor(
    switchAction: () => Promise<void>,
    stageAction: () => Promise<void>,
    rollbackAction: () => Promise<void>,
    commitCacheAction: () => void,
    rollbackCacheAction: () => void,
    commitRootAction?: () => void,
    rollbackRootAction?: () => Promise<void>
  ) {
    this.switchAction = switchAction
    this.stageAction = stageAction
    this.commitRootAction = commitRootAction ?? ((): void => {})
    this.rollbackRootAction = rollbackRootAction ?? (async (): Promise<void> => {})
    this.rollbackAction = rollbackAction
    this.commitCacheAction = commitCacheAction
    this.rollbackCacheAction = rollbackCacheAction
  }

  switchContext(): Promise<void> {
    return this.switchAction()
  }

  stageRoot(): Promise<void> {
    return this.stageAction()
  }

  commitRoot(): void {
    this.commitRootAction()
  }

  rollbackRoot(): Promise<void> {
    return this.rollbackRootAction()
  }

  rollbackContext(): Promise<void> {
    return this.rollbackAction()
  }

  commitCache(): void {
    this.commitCacheAction()
  }

  rollbackCache(): void {
    this.rollbackCacheAction()
  }
}

export async function executeWorkspaceTransition(steps: WorkspaceTransitionSteps): Promise<void> {
  if (transitionActive) {
    throw new Error('工作区切换正在进行中')
  }
  transitionActive = true
  let contextSwitched = false
  let cacheCommitted = false
  let rootStaged = false
  try {
    hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route', 'transition switch start')
    await steps.switchContext()
    hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route', 'transition switch done')
    contextSwitched = true
    steps.commitCache()
    cacheCommitted = true
    hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route', 'transition stage root start')
    await steps.stageRoot()
    rootStaged = true
    hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route', 'transition stage root done')
    steps.commitRoot()
    hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route', 'transition committed')
  } catch (error) {
    let routeRollbackError: Error | null = null
    let rollbackError: Error | null = null
    if (rootStaged) {
      try {
        await steps.rollbackRoot()
      } catch (caught) {
        routeRollbackError = caught instanceof Error ? caught : new Error('页面回滚失败')
      }
    }
    if (contextSwitched) {
      try {
        await steps.rollbackContext()
      } catch (caught) {
        rollbackError = caught instanceof Error ? caught : new Error('工作区回滚失败')
      }
    }
    if (cacheCommitted) {
      steps.rollbackCache()
    }
    if (routeRollbackError !== null) {
      throw routeRollbackError
    }
    if (rollbackError !== null) {
      throw rollbackError
    }
    throw error instanceof Error ? error : new Error('工作区切换失败')
  } finally {
    transitionActive = false
    hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route', 'transition inactive')
  }
}

export async function enterManagedTenant(tenantId: string, reason: string): Promise<void> {
  const repository = platformAdminRepositoryFactory.current()
  const previousSnapshot = sessionStore.getSnapshot()
  const params: PlatformTenantDetailParams = {
    tenantId: tenantId
  }
  const steps = new WorkspaceTransitionPlan(
    async (): Promise<void> => {
      await sessionStore.enterPlatformTenant(tenantId, reason)
    },
    async (): Promise<void> => {
      await stageRoot('pages/PlatformTenantDetailPage', params)
    },
    async (): Promise<void> => {
      await sessionStore.restoreWorkspaceSnapshot(previousSnapshot, '恢复进入代管前的工作区')
    },
    (): void => repository.cacheManagedTenant(tenantId),
    (): void => repository.clearManagedTenantCache(),
    (): void => commitStagedRoot(),
    async (): Promise<void> => {
      await rollbackStagedRoot()
    }
  )
  await executeWorkspaceTransition(steps)
}

export async function leaveManagedTenant(tenantId: string): Promise<void> {
  const repository = platformAdminRepositoryFactory.current()
  const previousSnapshot = sessionStore.getSnapshot()
  const steps = new WorkspaceTransitionPlan(
    async (): Promise<void> => {
      await sessionStore.returnPlatformContext()
    },
    async (): Promise<void> => {
      await stageMainRoot('platform/tenants')
    },
    async (): Promise<void> => {
      await sessionStore.restoreWorkspaceSnapshot(previousSnapshot, '恢复返回平台前的工作区')
    },
    (): void => repository.clearManagedTenantCache(),
    (): void => repository.cacheManagedTenant(tenantId),
    (): void => commitStagedRoot(),
    async (): Promise<void> => {
      await rollbackStagedRoot()
    }
  )
  await executeWorkspaceTransition(steps)
}
