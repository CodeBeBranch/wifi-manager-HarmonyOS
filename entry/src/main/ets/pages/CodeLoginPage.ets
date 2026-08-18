import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { isValidContact, isValidVerifyCode } from '../model/AuthModels'
import { resetToMain } from '../navigation/AppRouter'
import { previewPhone } from '../preview/PreviewMode'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct CodeLoginPage {
  @State target: string = ''
  @State code: string = ''
  @State sending: boolean = false
  @State submitting: boolean = false
  @State cooldown: number = 0
  @State message: string = ''
  @State error: string = ''
  private timer: number = -1

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
      this.timer = -1
    }
  }

  private useDemo(): void {
    this.target = previewPhone()
    this.code = '123456'
    this.message = '已填入本地演示凭据'
    this.error = ''
  }

  private async sendCode(): Promise<void> {
    const target = this.target.trim()
    this.message = ''
    this.error = ''
    if (!isValidContact(target)) {
      this.error = '请输入正确的手机号或邮箱'
      return
    }
    this.sending = true
    try {
      await sessionStore.sendLoginCode(target)
      this.message = sessionStore.isPreviewMode() ? '本地演示验证码已生成' : '验证码已发送'
      this.cooldown = 60
      this.timer = setInterval(() => {
        this.cooldown -= 1
        if (this.cooldown <= 0 && this.timer >= 0) {
          clearInterval(this.timer)
          this.timer = -1
        }
      }, 1000)
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '验证码发送失败'
    } finally {
      this.sending = false
    }
  }

  private async submit(): Promise<void> {
    const target = this.target.trim()
    this.message = ''
    this.error = ''
    if (!isValidContact(target) || !isValidVerifyCode(this.code)) {
      this.error = '请填写有效联系方式和 6 位验证码'
      return
    }
    this.submitting = true
    try {
      const snapshot = await sessionStore.loginByCode({
        target: target,
        code: this.code.trim()
      })
      if (!snapshot.authenticated) {
        this.error = '当前账号状态不能进入工作区'
        return
      }
      resetToMain()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '登录失败'
    } finally {
      this.submitting = false
    }
  }

  build() {
    Scroll() {
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
          Text('验证码登录')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.text)
            .layoutWeight(1)
        }
        .width('100%')

        Button('使用本地演示账号')
          .width('100%')
          .height(44)
          .fontSize(14)
          .fontColor(AppTheme.primary)
          .backgroundColor(AppTheme.surfaceMuted)
          .borderRadius(8)
          .margin({ top: 28, bottom: 24 })
          .onClick(() => this.useDemo())

        Text('手机号 / 邮箱')
          .fontSize(13)
          .fontColor(AppTheme.textSoft)
          .width('100%')
          .margin({ bottom: 8 })
        TextInput({ text: this.target, placeholder: '请输入手机号或邮箱' })
          .width('100%')
          .height(48)
          .fontSize(15)
          .fontColor(AppTheme.text)
          .placeholderColor(AppTheme.muted)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.borderStrong })
          .borderRadius(8)
          .onChange((value: string) => this.target = value)

        Text('验证码')
          .fontSize(13)
          .fontColor(AppTheme.textSoft)
          .width('100%')
          .margin({ top: 20, bottom: 8 })
        Row({ space: 10 }) {
          TextInput({ text: this.code, placeholder: '6 位验证码' })
            .layoutWeight(1)
            .height(48)
            .maxLength(6)
            .fontSize(15)
            .fontColor(AppTheme.text)
            .placeholderColor(AppTheme.muted)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.borderStrong })
            .borderRadius(8)
            .onChange((value: string) => this.code = value)
          Button(this.cooldown > 0 ? `${this.cooldown}s` : (this.sending ? '发送中' : '发送验证码'))
            .enabled(!this.sending && this.cooldown === 0)
            .width(112)
            .height(48)
            .fontSize(13)
            .fontColor(AppTheme.primary)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.borderStrong })
            .borderRadius(8)
            .onClick(() => this.sendCode())
        }
        .width('100%')

        if (this.message.length > 0) {
          Text(this.message)
            .fontSize(13)
            .fontColor(AppTheme.successText)
            .width('100%')
            .margin({ top: 16 })
        }
        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(13)
            .fontColor(AppTheme.dangerText)
            .width('100%')
            .margin({ top: 16 })
        }

        Button(this.submitting ? '正在登录' : '登录')
          .enabled(!this.submitting)
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.primaryText)
          .backgroundColor(AppTheme.primaryStrong)
          .borderRadius(8)
          .margin({ top: 24 })
          .onClick(() => this.submit())
      }
      .width('100%')
      .constraintSize({ maxWidth: 480 })
      .padding({ left: 20, right: 20, top: 18, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }
}
