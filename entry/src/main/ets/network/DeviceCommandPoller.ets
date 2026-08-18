import { ApiError } from '../model/ApiModels'
import {
  DeviceCommandPollState,
  DeviceCommandRecord,
  isDeviceCommandTerminal
} from '../model/DeviceCommandModels'
import { repositoryFactory } from '../repository/RepositoryFactory'

const MAX_POLL_ATTEMPTS = 20
const POLL_INTERVAL_MS = 3000

export type DeviceCommandPollListener = (
  state: DeviceCommandPollState,
  attempt: number,
  record: DeviceCommandRecord | null,
  error: ApiError | null
) => void

class DeviceCommandPoller {
  private timer: number = -1
  private listener: DeviceCommandPollListener | null = null
  private deviceCode: string = ''
  private requestId: string = ''
  private attempt: number = 0
  private generation: number = 0
  private desired: boolean = false
  private paused: boolean = false
  private busy: boolean = false

  start(deviceCode: string, requestId: string, listener: DeviceCommandPollListener): void {
    this.stop()
    this.deviceCode = deviceCode
    this.requestId = requestId
    this.listener = listener
    this.attempt = 0
    this.desired = true
    this.paused = false
    this.poll()
  }

  pause(): void {
    if (!this.desired || this.paused) return
    this.paused = true
    this.generation += 1
    this.busy = false
    this.clearTimer()
    this.publish('paused', null, null)
  }

  resume(): void {
    if (!this.desired || !this.paused) return
    this.paused = false
    this.poll()
  }

  stop(): void {
    this.desired = false
    this.paused = false
    this.busy = false
    this.clearTimer()
    this.generation += 1
    this.attempt = 0
    this.deviceCode = ''
    this.requestId = ''
    this.listener = null
  }

  private async poll(): Promise<void> {
    if (!this.desired || this.paused || this.busy) return
    if (this.attempt >= MAX_POLL_ATTEMPTS) {
      this.desired = false
      this.publish('exhausted', null, null)
      return
    }

    const generation = this.generation
    const deviceCode = this.deviceCode
    const requestId = this.requestId
    this.attempt += 1
    this.busy = true
    this.publish('polling', null, null)

    try {
      const record = await repositoryFactory.deviceCommand().findByRequestId(deviceCode, requestId)
      if (!this.isCurrent(generation, deviceCode, requestId)) return
      if (record !== null && isDeviceCommandTerminal(record.status)) {
        this.desired = false
        this.clearTimer()
        this.publish('terminal', record, null)
        return
      }
      this.publish('polling', record, null)
    } catch (error) {
      if (!this.isCurrent(generation, deviceCode, requestId)) return
      const apiError = error instanceof ApiError
        ? error
        : new ApiError('设备执行状态查询失败')
      this.publish('failed', null, apiError)
      if (apiError.httpStatus === 401) {
        this.desired = false
        this.clearTimer()
        return
      }
    } finally {
      if (this.isCurrent(generation, deviceCode, requestId)) {
        this.busy = false
      }
    }

    if (!this.isCurrent(generation, deviceCode, requestId) || !this.desired || this.paused) return
    if (this.attempt >= MAX_POLL_ATTEMPTS) {
      this.desired = false
      this.publish('exhausted', null, null)
      return
    }
    this.timer = setTimeout(() => {
      this.timer = -1
      this.poll()
    }, POLL_INTERVAL_MS)
  }

  private isCurrent(generation: number, deviceCode: string, requestId: string): boolean {
    return this.generation === generation &&
      this.deviceCode === deviceCode &&
      this.requestId === requestId
  }

  private publish(
    state: DeviceCommandPollState,
    record: DeviceCommandRecord | null,
    error: ApiError | null
  ): void {
    if (this.listener !== null) {
      this.listener(state, this.attempt, record, error)
    }
  }

  private clearTimer(): void {
    if (this.timer >= 0) {
      clearTimeout(this.timer)
      this.timer = -1
    }
  }
}

export const deviceCommandPoller = new DeviceCommandPoller()
