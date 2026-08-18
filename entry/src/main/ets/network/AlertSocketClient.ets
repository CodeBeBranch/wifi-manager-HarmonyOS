import { BusinessError } from '@kit.BasicServicesKit'
import webSocket from '@ohos.net.webSocket'
import {
  AlertPushEvent,
  AlertSocketState,
  alertReconnectDelay,
  parseAlertSocketMessage
} from '../model/AlertModels'
import { buildAlertWebSocketUrl, defaultAlertWebSocketOrigin } from '../config/RuntimeConfig'
import { sessionStore } from '../session/SessionStore'
import { runtimeSettings } from '../storage/RuntimeSettings'
import { runtimeModeStore } from '../preview/RuntimeMode'
import { networkTransportFactory } from './TransportFactory'

export type AlertSocketStateListener = (state: AlertSocketState, attempt: number) => void
export type AlertPushListener = (alert: AlertPushEvent) => void

interface AlertSocketHeaders {
  Origin: string
}

class AlertSocketClient {
  private socket: webSocket.WebSocket | null = null
  private stateListener: AlertSocketStateListener | null = null
  private alertListener: AlertPushListener | null = null
  private reconnectTimer: number = -1
  private reconnectAttempt: number = 0
  private generation: number = 0
  private desired: boolean = false
  private paused: boolean = false

  constructor() {
    runtimeModeStore.addListener((): void => {
      this.stop()
    })
  }

  start(stateListener: AlertSocketStateListener, alertListener: AlertPushListener): void {
    this.stateListener = stateListener
    this.alertListener = alertListener
    this.desired = true
    this.paused = false
    this.reconnectAttempt = 0
    this.connect(false)
  }

  retry(): void {
    if (!this.desired || this.paused) return
    this.clearReconnect()
    this.closeCurrent()
    this.reconnectAttempt = 0
    this.connect(false)
  }

  pause(): void {
    if (!this.desired) return
    this.paused = true
    this.clearReconnect()
    this.closeCurrent()
    this.publishState('disconnected')
  }

  resume(): void {
    if (!this.desired || !this.paused) return
    this.paused = false
    this.reconnectAttempt = 0
    this.connect(false)
  }

  stop(): void {
    this.desired = false
    this.paused = false
    this.clearReconnect()
    this.closeCurrent()
    this.reconnectAttempt = 0
    this.publishState('idle')
    this.stateListener = null
    this.alertListener = null
  }

  private connect(reconnecting: boolean): void {
    if (!this.desired || this.paused || this.socket !== null) return
    try {
      runtimeModeStore.guardNetwork('WEBSOCKET')
    } catch (_) {
      this.publishState('idle')
      return
    }
    const credentials = sessionStore.getAlertSocketCredentials()
    if (credentials === null) {
      this.publishState('auth-required')
      return
    }

    const current = networkTransportFactory.createAlertSocket()
    const generation = ++this.generation
    this.socket = current
    this.publishState(reconnecting ? 'reconnecting' : 'connecting')

    current.on('open', (error: BusinessError) => {
      if (!this.isCurrent(current, generation)) return
      if (error) {
        this.handleFailure(current, generation, this.isAuthenticationFailure(error))
        return
      }
      this.reconnectAttempt = 0
      this.publishState('connected')
    })

    current.on('message', (error: BusinessError, value: string | ArrayBuffer) => {
      if (!this.isCurrent(current, generation) || error || typeof value !== 'string') return
      const parsed = parseAlertSocketMessage(value, credentials.tenantId)
      if (parsed === null) return
      if (parsed.type === 'PING') {
        this.sendPong(current, generation)
        return
      }
      if (parsed.alert !== null && this.alertListener !== null) {
        this.alertListener(parsed.alert)
      }
    })

    current.on('close', (error: BusinessError, result: webSocket.CloseResult) => {
      if (!this.isCurrent(current, generation)) return
      const authenticationFailure = result.code === 1008 || this.isAuthenticationFailure(error)
      this.handleFailure(current, generation, authenticationFailure)
    })

    current.on('error', (error: BusinessError) => {
      if (!this.isCurrent(current, generation)) return
      this.handleFailure(current, generation, this.isAuthenticationFailure(error))
    })

    const headers: AlertSocketHeaders = {
      Origin: defaultAlertWebSocketOrigin()
    }
    try {
      current.connect(
        buildAlertWebSocketUrl(runtimeSettings.getGatewayUrl()),
        {
          header: headers,
          protocol: `access_token, ${credentials.accessToken}`,
          pingInterval: 0
        }
      ).then((accepted: boolean) => {
        if (!accepted) {
          this.handleFailure(current, generation, false)
        }
      }).catch((error: BusinessError) => {
        this.handleFailure(current, generation, this.isAuthenticationFailure(error))
      })
    } catch (error) {
      this.handleFailure(
        current,
        generation,
        error instanceof Error && this.messageIsAuthenticationFailure(error.message)
      )
    }
  }

  private handleFailure(
    current: webSocket.WebSocket,
    generation: number,
    authenticationFailure: boolean
  ): void {
    if (!this.isCurrent(current, generation)) return
    this.socket = null
    this.generation += 1
    this.closeQuietly(current, 'client reset')
    if (authenticationFailure) {
      this.clearReconnect()
      this.publishState('auth-required')
      return
    }
    this.scheduleReconnect()
  }

  private scheduleReconnect(): void {
    if (!this.desired || this.paused || this.reconnectTimer >= 0) {
      this.publishState('disconnected')
      return
    }
    const delay = alertReconnectDelay(this.reconnectAttempt)
    this.reconnectAttempt += 1
    this.publishState('reconnecting')
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = -1
      this.connect(true)
    }, delay)
  }

  private closeCurrent(): void {
    const current = this.socket
    this.socket = null
    this.generation += 1
    if (current !== null) {
      this.closeQuietly(current, 'client lifecycle')
    }
  }

  private clearReconnect(): void {
    if (this.reconnectTimer >= 0) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = -1
    }
  }

  private publishState(state: AlertSocketState): void {
    if (this.stateListener !== null) {
      this.stateListener(state, this.reconnectAttempt)
    }
  }

  private isCurrent(current: webSocket.WebSocket, generation: number): boolean {
    return this.socket === current && this.generation === generation
  }

  private isAuthenticationFailure(error: BusinessError): boolean {
    if (!error) return false
    return this.messageIsAuthenticationFailure(String(error.message ?? ''))
  }

  private messageIsAuthenticationFailure(message: string): boolean {
    return message.includes('401') || message.includes('403') ||
      message.toLowerCase().includes('unauthorized') ||
      message.toLowerCase().includes('forbidden')
  }

  private sendPong(current: webSocket.WebSocket, generation: number): void {
    try {
      current.send('{"type":"PONG"}').catch(() => {
        this.handleFailure(current, generation, false)
      })
    } catch (_) {
      this.handleFailure(current, generation, false)
    }
  }

  private closeQuietly(current: webSocket.WebSocket, reason: string): void {
    try {
      current.close({ code: 1000, reason: reason }).catch(() => {})
    } catch (_) {
    }
  }
}

export const alertSocketClient = new AlertSocketClient()
