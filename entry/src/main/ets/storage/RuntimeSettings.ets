import util from '@ohos.util'
import { defaultGatewayUrl, normalizeGatewayUrl } from '../config/RuntimeConfig'
import { runtimeModeStore } from '../preview/RuntimeMode'
import { appPreferences } from './AppPreferences'

const CLIENT_INSTANCE_ID_KEY = 'client_instance_id'
const REAL_GATEWAY_URL_KEY = 'real_gateway_url'

class RuntimeSettings {
  private gatewayUrl: string = defaultGatewayUrl()
  private clientInstanceId: string = ''

  async initialize(): Promise<void> {
    if (runtimeModeStore.isDemo()) {
      this.gatewayUrl = defaultGatewayUrl()
      this.clientInstanceId = 'demo-client-instance'
      return
    }
    await this.activateReal()
  }

  async activateReal(): Promise<void> {
    const storedGateway = await appPreferences.getString(REAL_GATEWAY_URL_KEY)
    this.gatewayUrl = defaultGatewayUrl()
    if (storedGateway.length > 0) {
      try {
        this.gatewayUrl = normalizeGatewayUrl(storedGateway)
      } catch (_) {
        this.gatewayUrl = defaultGatewayUrl()
      }
    }
    const storedClientId = await appPreferences.getString(CLIENT_INSTANCE_ID_KEY)
    this.clientInstanceId = storedClientId.length > 0 ? storedClientId : util.generateRandomUUID()
    if (storedClientId.length === 0) {
      await appPreferences.putString(CLIENT_INSTANCE_ID_KEY, this.clientInstanceId)
    }
  }

  getGatewayUrl(): string {
    return this.gatewayUrl
  }

  getClientInstanceId(): string {
    return this.clientInstanceId
  }

  async setGatewayUrl(value: string): Promise<void> {
    const normalized = normalizeGatewayUrl(value)
    this.gatewayUrl = normalized
    await appPreferences.putString(REAL_GATEWAY_URL_KEY, normalized)
  }

  async resetGatewayUrl(): Promise<void> {
    this.gatewayUrl = defaultGatewayUrl()
    await appPreferences.remove(REAL_GATEWAY_URL_KEY)
  }
}

export const runtimeSettings = new RuntimeSettings()
