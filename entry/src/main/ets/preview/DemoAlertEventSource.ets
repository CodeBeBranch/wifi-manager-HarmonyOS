import { DemoAlertConnection, Hm4DemoScenario } from '../model/Hm4Models'
import { DemoHm4SecurityRepository } from '../repository/Hm4SecurityRepository'

export type DemoAlertListener = (connection: DemoAlertConnection) => void

export class DemoAlertEventSource {
  private listener: DemoAlertListener | null = null
  private tenantId: string = ''
  private scenario: Hm4DemoScenario = 'NORMAL'
  private version: number = 0
  private active: boolean = false

  start(
    tenantId: string,
    scenario: Hm4DemoScenario,
    repository: DemoHm4SecurityRepository,
    listener: DemoAlertListener
  ): void {
    this.dispose()
    this.tenantId = tenantId
    this.scenario = scenario
    this.listener = listener
    this.active = true
    this.publish(repository, 'connecting')
    this.publish(repository, scenario === 'DEPENDENCY_DOWN' ? 'failed' : 'online')
  }

  replay(repository: DemoHm4SecurityRepository): void {
    if (!this.active || this.listener === null) return
    this.publish(repository, 'reconnecting')
    this.publish(repository, 'catch-up')
    this.publish(repository, this.scenario === 'DEPENDENCY_DOWN' ? 'failed' : 'online')
  }

  dispose(): void {
    this.listener = null
    this.tenantId = ''
    this.active = false
  }

  private publish(
    repository: DemoHm4SecurityRepository,
    state: 'connecting' | 'online' | 'reconnecting' | 'catch-up' | 'failed'
  ): void {
    if (!this.active || this.listener === null) return
    this.version += 1
    repository.applyEvent(this.tenantId, 8100 + (this.tenantId === 'preview-tenant-01' ? 0 : 100), this.version)
    this.listener({ state: state, version: this.version })
  }
}
