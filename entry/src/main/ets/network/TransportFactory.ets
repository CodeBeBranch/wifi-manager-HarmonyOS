import http from '@ohos.net.http'
import webSocket from '@ohos.net.webSocket'
import { runtimeModeStore } from '../preview/RuntimeMode'

export interface TransportCreationSnapshot {
  http: number
  webSocket: number
  mqtt: number
}

export type MqttTransportCreator<T> = () => T

class NetworkTransportFactory {
  private httpCreated: number = 0
  private webSocketCreated: number = 0
  private mqttCreated: number = 0

  createHttp(): http.HttpRequest {
    runtimeModeStore.guardNetwork('HTTP')
    this.httpCreated += 1
    return http.createHttp()
  }

  createAlertSocket(): webSocket.WebSocket {
    runtimeModeStore.guardNetwork('WEBSOCKET')
    this.webSocketCreated += 1
    return webSocket.createWebSocket()
  }

  createMqtt<T>(creator: MqttTransportCreator<T>): T {
    runtimeModeStore.guardNetwork('MQTT')
    this.mqttCreated += 1
    return creator()
  }

  snapshot(): TransportCreationSnapshot {
    return {
      http: this.httpCreated,
      webSocket: this.webSocketCreated,
      mqtt: this.mqttCreated
    }
  }

  resetCounters(): void {
    this.httpCreated = 0
    this.webSocketCreated = 0
    this.mqttCreated = 0
  }
}

export const networkTransportFactory = new NetworkTransportFactory()
