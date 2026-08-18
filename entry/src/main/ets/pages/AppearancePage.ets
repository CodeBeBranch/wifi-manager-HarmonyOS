import router from '@ohos.router'
import { ThemeMode, themeStore } from '../storage/ThemeStore'
import { AppTheme } from '../ui/AppTheme'

interface ThemeOption {
  mode: ThemeMode
  title: string
  description: string
}

const THEME_OPTIONS: ThemeOption[] = [
  { mode: 'system', title: '跟随系统', description: '随系统外观自动切换' },
  { mode: 'light', title: '浅色', description: '适合明亮环境' },
  { mode: 'dark', title: '深色', description: '适合弱光环境' }
]

@Entry
@Component
struct AppearancePage {
  @StorageLink('theme_mode') themeMode: string = 'light'
  @State error: string = ''

  private async select(mode: ThemeMode): Promise<void> {
    this.error = ''
    try {
      await themeStore.setMode(mode)
    } catch (_) {
      this.error = '外观偏好保存失败'
    }
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_backward'))
            .fontSize(22)
            .fontColor([AppTheme.text])
        }
        .width(44)
        .height(44)
        .backgroundColor(AppTheme.surface)
        .onClick(() => router.back())
        Text('外观')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 12 })

      Column() {
        ForEach(THEME_OPTIONS, (item: ThemeOption, index: number) => {
          Row({ space: 12 }) {
            SymbolGlyph(item.mode === 'dark'
              ? $r('sys.symbol.moon')
              : item.mode === 'light'
                ? $r('sys.symbol.home_button')
                : $r('sys.symbol.grid'))
              .fontSize(24)
              .fontColor([this.themeMode === item.mode ? AppTheme.primary : AppTheme.textSoft])
              .width(38)
            Column({ space: 4 }) {
              Text(item.title)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.text)
              Text(item.description)
                .fontSize(12)
                .fontColor(AppTheme.muted)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            if (this.themeMode === item.mode) {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(20)
                .fontColor([AppTheme.primary])
            }
          }
          .width('100%')
          .height(76)
          .padding({ left: 12, right: 12 })
          .border({
            width: { bottom: index < THEME_OPTIONS.length - 1 ? 1 : 0 },
            color: AppTheme.border
          })
          .onClick(() => this.select(item.mode))
        }, (item: ThemeOption) => item.mode)
      }
      .width('100%')
      .padding({ left: 4, right: 4 })
      .backgroundColor(AppTheme.surface)
      .border({ width: 1, color: AppTheme.border })
      .borderRadius(8)
      .margin({ left: 16, right: 16, top: 20 })

      if (this.error.length > 0) {
        Text(this.error)
          .fontSize(13)
          .fontColor(AppTheme.dangerText)
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ top: 16 })
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }
}
