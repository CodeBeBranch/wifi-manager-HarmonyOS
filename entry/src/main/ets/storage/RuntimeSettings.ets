import util from '@ohos.util'
import { defaultGatewayUrl } from '../config/RuntimeConfig'
import { appPreferences } from './AppPreferences'

const CLIENT_INSTANCE_ID_KEY = 'client_instance_id'

class RuntimeSettings {
  private readonly gatewayUrl: string = defaultGatewayUrl()
  private clientInstanceId: string = ''

  async initialize(): Promise<void> {
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

}

export const runtimeSettings = new RuntimeSettings()
