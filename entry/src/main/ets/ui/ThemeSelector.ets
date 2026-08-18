import { themeStore, ThemeMode } from '../storage/ThemeStore'
import { AppTheme } from './AppTheme'

@Component
export struct ThemeSelector {
  @StorageLink('theme_mode') themeMode: string = 'light'

  private async changeMode(mode: ThemeMode): Promise<void> {
    if (this.themeMode === mode) {
      return
    }
    try {
      await themeStore.setMode(mode)
    } catch (_) {
      // 外观已经切换；偏好写入失败时下次启动回到默认浅色。
    }
  }

  build() {
    Button(this.themeMode === 'light' ? '夜间' : '日间')
      .width(64)
      .height(40)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppTheme.textSoft)
      .backgroundColor(AppTheme.surfaceRaised)
      .border({ width: 1, color: AppTheme.border })
      .borderRadius(8)
      .onClick(() => this.changeMode(this.themeMode === 'light' ? 'dark' : 'light'))
  }
}
