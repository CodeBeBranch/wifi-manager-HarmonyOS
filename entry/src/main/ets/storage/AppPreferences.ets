import common from '@ohos.app.ability.common'
import preferences from '@ohos.data.preferences'

const PREFERENCES_NAME = 'wifi_manager_runtime'

class AppPreferences {
  private store: preferences.Preferences | null = null

  async initialize(context: common.Context): Promise<void> {
    if (this.store !== null) {
      return
    }
    this.store = await preferences.getPreferences(context, { name: PREFERENCES_NAME })
  }

  private requireStore(): preferences.Preferences {
    if (this.store === null) {
      throw new Error('本地存储尚未初始化')
    }
    return this.store
  }

  async getString(key: string, fallback: string = ''): Promise<string> {
    const value = await this.requireStore().get(key, fallback)
    return typeof value === 'string' ? value : fallback
  }

  async putString(key: string, value: string): Promise<void> {
    const store = this.requireStore()
    await store.put(key, value)
    await store.flush()
  }

  async remove(key: string): Promise<void> {
    const store = this.requireStore()
    await store.delete(key)
    await store.flush()
  }
}

export const appPreferences = new AppPreferences()
