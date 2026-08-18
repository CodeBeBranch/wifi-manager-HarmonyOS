import { resetToLogin, resetToMain } from '../navigation/AppRouter'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct LaunchGatePage {
  @State statusText: string = '正在恢复登录状态'
  @State unavailable: boolean = false

  aboutToAppear(): void {
    this.restoreSession()
  }

  private async restoreSession(): Promise<void> {
    const state = await sessionStore.restore()
    if (state === 'active') {
      resetToMain()
      return
    }
    if (state === 'step-up') {
      this.statusText = '当前登录环境需要重新验证，请重新登录'
      this.unavailable = true
      return
    }
    if (state === 'unavailable') {
      this.statusText = '暂时无法连接服务'
      this.unavailable = true
      return
    }
    resetToLogin()
  }

  build() {
    Column({ space: 20 }) {
      Row({ space: 10 }) {
        Circle()
          .width(10)
          .height(10)
          .fill(AppTheme.primary)
        Text('WIFI MANAGER')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
      }
      Text('正在准备工作区')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.text)
      LoadingProgress()
        .width(40)
        .height(40)
        .color(AppTheme.primary)
        .visibility(this.unavailable ? Visibility.Hidden : Visibility.Visible)
      Text(this.statusText)
        .fontSize(14)
        .fontColor(AppTheme.muted)
        .textAlign(TextAlign.Center)
      if (this.unavailable) {
        Button('重新登录')
          .height(44)
          .fontSize(15)
          .fontColor(AppTheme.primaryText)
          .backgroundColor(AppTheme.primaryStrong)
          .borderRadius(6)
          .onClick(() => resetToLogin())
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 28, right: 28 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.background)
  }
}
