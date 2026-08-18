import common from '@ohos.app.ability.common'
import { ConfigurationConstant } from '@kit.AbilityKit'
import { appPreferences } from './AppPreferences'

export type ThemeMode = 'light' | 'dark'

const THEME_MODE_KEY = 'theme_mode'

export function normalizeThemeMode(value: string): ThemeMode {
  return value === 'dark' ? 'dark' : 'light'
}

class ThemeStore {
  private context: common.Context | null = null

  async initialize(context: common.Context): Promise<void> {
    this.context = context
    const stored = await appPreferences.getString(THEME_MODE_KEY, 'light')
    const mode = normalizeThemeMode(stored)
    this.apply(mode)
    AppStorage.setOrCreate<string>(THEME_MODE_KEY, mode)
  }

  async setMode(mode: ThemeMode): Promise<void> {
    this.apply(mode)
    AppStorage.setOrCreate<string>(THEME_MODE_KEY, mode)
    await appPreferences.putString(THEME_MODE_KEY, mode)
  }

  private apply(mode: ThemeMode): void {
    if (this.context === null) {
      return
    }
    this.context.getApplicationContext().setColorMode(
      mode === 'dark'
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    )
  }
}

export const themeStore = new ThemeStore()
