import { ApiError } from '../model/ApiModels'
import { appPreferences } from '../storage/AppPreferences'

export enum RuntimeMode {
  REAL = 'REAL',
  DEMO = 'DEMO'
}

export type NetworkChannel = 'HTTP' | 'WEBSOCKET' | 'MQTT'
export type RuntimeModeListener = (nextMode: RuntimeMode) => void

const RUNTIME_MODE_KEY = 'runtime_mode_namespace'

export function normalizeRuntimeMode(value: string): RuntimeMode {
  return value === RuntimeMode.DEMO ? RuntimeMode.DEMO : RuntimeMode.REAL
}

class RuntimeModeStore {
  private mode: RuntimeMode = RuntimeMode.REAL
  private blockedNetworkAttempts: number = 0
  private blockedChannels: string[] = []
  private listeners: RuntimeModeListener[] = []

  async initialize(): Promise<void> {
    const stored = await appPreferences.getString(RUNTIME_MODE_KEY, RuntimeMode.REAL)
    this.setMode(normalizeRuntimeMode(stored))
  }

  activateDemo(): void {
    this.setMode(RuntimeMode.DEMO)
  }

  activateReal(): void {
    this.setMode(RuntimeMode.REAL)
  }

  async persistCurrentMode(): Promise<void> {
    await appPreferences.putString(RUNTIME_MODE_KEY, this.mode)
  }

  addListener(listener: RuntimeModeListener): void {
    this.listeners.push(listener)
  }

  private setMode(nextMode: RuntimeMode): void {
    if (this.mode === nextMode) {
      return
    }
    for (const listener of this.listeners) {
      listener(nextMode)
    }
    this.mode = nextMode
    this.blockedNetworkAttempts = 0
    this.blockedChannels = []
  }

  getMode(): RuntimeMode {
    return this.mode
  }

  isDemo(): boolean {
    return this.mode === RuntimeMode.DEMO
  }

  recordBlockedNetworkAttempt(): void {
    if (this.mode === RuntimeMode.DEMO) {
      this.blockedNetworkAttempts += 1
    }
  }

  guardNetwork(channel: NetworkChannel): void {
    if (!this.isDemo()) {
      return
    }
    this.recordBlockedNetworkAttempt()
    this.blockedChannels.push(channel)
    throw new ApiError(
      `本地演示已阻止 ${channel} 真实网络请求`,
      0,
      0,
      'DEMO_NETWORK_BLOCKED'
    )
  }

  getBlockedNetworkAttempts(): number {
    return this.blockedNetworkAttempts
  }

  getBlockedChannels(): string[] {
    return this.blockedChannels.slice()
  }

  resetNetworkSentinel(): void {
    this.blockedNetworkAttempts = 0
    this.blockedChannels = []
  }
}

export const runtimeModeStore = new RuntimeModeStore()
