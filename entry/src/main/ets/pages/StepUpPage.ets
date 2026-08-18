import router from '@ohos.router'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct StepUpPage {
  @State code: string = ''
  @State checking: boolean = false
  @State error: string = ''
  private closeTimer: number = -1
  private pageGeneration: number = 0

  aboutToAppear(): void {
    this.pageGeneration += 1
  }

  aboutToDisappear(): void {
    this.pageGeneration += 1
    this.clearCloseTimer()
  }

  private async verify(): Promise<void> {
    this.error = ''
    if (!sessionStore.isPreviewMode()) {
      this.error = '真实二次验证等待服务契约冻结后开放'
      return
    }
    if (this.code.trim() !== '123456') {
      this.error = '验证码不正确'
      return
    }
    this.checking = true
    const generation = this.pageGeneration
    this.clearCloseTimer()
    this.closeTimer = setTimeout(() => {
      this.closeTimer = -1
      if (generation !== this.pageGeneration || !this.checking) {
        return
      }
      this.checking = false
      router.back()
    }, 300)
  }

  private cancel(): void {
    this.checking = false
    this.clearCloseTimer()
    router.back()
  }

  private clearCloseTimer(): void {
    if (this.closeTimer >= 0) {
      clearTimeout(this.closeTimer)
      this.closeTimer = -1
    }
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([AppTheme.text])
        }
        .width(44)
        .height(44)
        .backgroundColor(AppTheme.surface)
        .onClick(() => this.cancel())
        Text('安全验证')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .layoutWeight(1)
      }
      .width('100%')

      Column({ space: 14 }) {
        SymbolGlyph($r('sys.symbol.lock'))
          .fontSize(36)
          .fontColor([AppTheme.primary])
        Text('确认是你本人')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
        Text('本地演示验证码为 123456')
          .fontSize(14)
          .fontColor(AppTheme.muted)
      }
      .width('100%')
      .margin({ top: 48, bottom: 30 })

      TextInput({ text: this.code, placeholder: '输入 6 位验证码' })
        .width('100%')
        .height(50)
        .maxLength(6)
        .fontSize(18)
        .textAlign(TextAlign.Center)
        .fontColor(AppTheme.text)
        .placeholderColor(AppTheme.muted)
        .backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.borderStrong })
        .borderRadius(8)
        .onChange((value: string) => this.code = value)

      if (this.error.length > 0) {
        Text(this.error)
          .fontSize(13)
          .fontColor(AppTheme.dangerText)
          .width('100%')
          .margin({ top: 14 })
      }

      Button(this.checking ? '正在验证' : '验证')
        .enabled(!this.checking)
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.primaryText)
        .backgroundColor(AppTheme.primaryStrong)
        .borderRadius(8)
        .margin({ top: 22 })
        .onClick(() => this.verify())
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: 480 })
    .padding({ left: 20, right: 20, top: 18, bottom: 32 })
    .backgroundColor(AppTheme.background)
  }
}
