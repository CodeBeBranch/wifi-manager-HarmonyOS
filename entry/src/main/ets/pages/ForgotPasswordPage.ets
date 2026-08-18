import router from '@ohos.router'
import { resetToLogin } from '../navigation/AppRouter'
import { ApiError } from '../model/ApiModels'
import {
  ResetPasswordRequest,
  isValidContact,
  isValidVerifyCode,
  validateAccountPassword
} from '../model/AuthModels'
import { publicAuthRepositoryFactory } from '../repository/AuthRepository'
import { AppTheme } from '../ui/AppTheme'
import { ThemeSelector } from '../ui/ThemeSelector'

@Entry
@Component
struct ForgotPasswordPage {
  @State target: string = ''
  @State verifyCode: string = ''
  @State newPassword: string = ''
  @State confirmPassword: string = ''
  @State showPassword: boolean = false
  @State loading: boolean = false
  @State sendingCode: boolean = false
  @State codeCooldown: number = 0
  @State resetSucceeded: boolean = false
  @State errorMessage: string = ''
  @State successMessage: string = ''
  private codeTimer: number = -1
  private cooldownTarget: string = ''
  private pageVersion: number = 0

  aboutToDisappear(): void {
    this.pageVersion += 1
    this.stopCodeTimer()
    this.clearSecrets()
  }

  onPageHide(): void {
    this.clearSecrets()
  }

  private clearSecrets(): void {
    this.verifyCode = ''
    this.newPassword = ''
    this.confirmPassword = ''
    this.showPassword = false
  }

  private clearMessages(): void {
    this.errorMessage = ''
    this.successMessage = ''
  }

  private updateTarget(value: string): void {
    this.target = value
    if (value.trim() !== this.cooldownTarget) {
      this.verifyCode = ''
      this.cooldownTarget = ''
      this.stopCodeTimer()
      this.codeCooldown = 0
    }
  }

  private validateTarget(target: string): string {
    if (target.length === 0) return '请输入已绑定的手机号或邮箱'
    if (!isValidContact(target)) return '请输入正确的手机号或邮箱'
    return ''
  }

  private validateForm(): string {
    const targetError = this.validateTarget(this.target.trim())
    if (targetError.length > 0) return targetError
    if (!isValidVerifyCode(this.verifyCode)) return '请输入 6 位验证码'
    const passwordError = validateAccountPassword(this.newPassword)
    if (passwordError.length > 0) return `新${passwordError}`
    if (this.newPassword !== this.confirmPassword) return '两次输入的新密码不一致'
    return ''
  }

  private async sendCode(): Promise<void> {
    if (this.sendingCode || this.loading || this.codeCooldown > 0) return
    const target = this.target.trim()
    this.clearMessages()
    const validation = this.validateTarget(target)
    if (validation.length > 0) {
      this.errorMessage = validation
      return
    }

    const pageVersion = this.pageVersion
    this.sendingCode = true
    try {
      await publicAuthRepositoryFactory.current().sendVerifyCode({
        target: target,
        scene: 'reset_password'
      })
      if (pageVersion !== this.pageVersion || this.target.trim() !== target) return
      this.successMessage = '验证码已发送'
      this.cooldownTarget = target
      this.startCodeTimer(60)
    } catch (error) {
      if (pageVersion !== this.pageVersion) return
      this.errorMessage = error instanceof ApiError
        ? error.message
        : '验证码发送失败，请稍后重试'
    } finally {
      if (pageVersion === this.pageVersion) {
        this.sendingCode = false
      }
    }
  }

  private async submit(): Promise<void> {
    if (this.loading || this.sendingCode || this.resetSucceeded) return
    this.clearMessages()
    const validation = this.validateForm()
    if (validation.length > 0) {
      this.errorMessage = validation
      return
    }

    const pageVersion = this.pageVersion
    const request: ResetPasswordRequest = {
      target: this.target.trim(),
      code: this.verifyCode.trim(),
      newPassword: this.newPassword
    }
    this.loading = true
    const pending = publicAuthRepositoryFactory.current().resetPassword(request)
    this.clearSecrets()

    try {
      const response = await pending
      if (pageVersion !== this.pageVersion) return
      if (response.data !== null) {
        throw new ApiError('密码重置响应无效', 502, 502,
          'DEPENDENCY_PROTOCOL_INVALID', response.requestId)
      }
      this.resetSucceeded = true
      this.successMessage = '密码已重置，请使用新密码登录'
      this.stopCodeTimer()
      this.codeCooldown = 0
    } catch (error) {
      if (pageVersion !== this.pageVersion) return
      this.errorMessage = error instanceof ApiError
        ? error.message
        : '密码重置失败，请稍后重试'
    } finally {
      if (pageVersion === this.pageVersion) {
        this.loading = false
      }
    }
  }

  private startCodeTimer(seconds: number): void {
    this.stopCodeTimer()
    this.codeCooldown = seconds
    this.codeTimer = setInterval(() => {
      this.codeCooldown -= 1
      if (this.codeCooldown <= 0) {
        this.stopCodeTimer()
      }
    }, 1000)
  }

  private stopCodeTimer(): void {
    if (this.codeTimer >= 0) {
      clearInterval(this.codeTimer)
      this.codeTimer = -1
    }
    if (this.codeCooldown < 0) {
      this.codeCooldown = 0
    }
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Button('‹')
            .width(44)
            .height(44)
            .fontSize(24)
            .fontColor(AppTheme.textSoft)
            .backgroundColor(AppTheme.surfaceRaised)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)
            .onClick(() => router.back())
          Row({ space: 10 }) {
            Circle().width(9).height(9).fill(AppTheme.primary)
            Text('WiFi Manager')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.text)
          }
          .layoutWeight(1)
          .margin({ left: 12 })
          ThemeSelector()
        }
        .width('100%')

        Text(this.resetSucceeded ? '密码已重置' : '找回密码')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .width('100%')
          .margin({ top: 32 })
        Text(this.resetSucceeded
          ? '返回登录并使用新密码'
          : '验证已绑定的手机号或邮箱后设置新密码')
          .fontSize(14)
          .fontColor(AppTheme.muted)
          .width('100%')
          .margin({ top: 8, bottom: 26 })

        if (this.resetSucceeded) {
          Text(this.successMessage)
            .fontSize(14)
            .fontColor(AppTheme.successText)
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.successSurface)
            .border({ width: 1, color: AppTheme.success })
            .borderRadius(8)
          Button('返回登录')
            .width('100%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.primaryText)
            .backgroundColor(AppTheme.primaryStrong)
            .borderRadius(8)
            .margin({ top: 20 })
            .onClick(() => resetToLogin())
        } else {
          Text('手机号 / 邮箱')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .width('100%')
            .margin({ bottom: 8 })
          TextInput({ text: this.target, placeholder: '请输入已绑定的手机号或邮箱' })
            .height(48)
            .maxLength(120)
            .fontSize(15)
            .fontColor(AppTheme.text)
            .placeholderColor(AppTheme.muted)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.borderStrong })
            .borderRadius(8)
            .enabled(!this.loading && !this.sendingCode)
            .onChange((value: string) => this.updateTarget(value))

          Text('验证码')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .width('100%')
            .margin({ top: 18, bottom: 8 })
          Row({ space: 10 }) {
            TextInput({ text: this.verifyCode, placeholder: '6 位验证码' })
              .layoutWeight(1)
              .height(48)
              .maxLength(6)
              .fontSize(15)
              .fontColor(AppTheme.text)
              .placeholderColor(AppTheme.muted)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong })
              .borderRadius(8)
              .enabled(!this.loading)
              .onChange((value: string) => this.verifyCode = value)
            Button(this.codeCooldown > 0
              ? `${this.codeCooldown}s 后重发`
              : (this.sendingCode ? '发送中' : '发送验证码'))
              .enabled(!this.loading && !this.sendingCode && this.codeCooldown === 0)
              .width(116)
              .height(48)
              .fontSize(13)
              .fontColor(this.codeCooldown > 0 ? AppTheme.muted : AppTheme.primary)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong })
              .borderRadius(8)
              .onClick(() => this.sendCode())
          }
          .width('100%')

          Text('新密码')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .width('100%')
            .margin({ top: 18, bottom: 8 })
          Row() {
            TextInput({ text: this.newPassword, placeholder: '6 到 20 位' })
              .type(this.showPassword ? InputType.Normal : InputType.Password)
              .layoutWeight(1)
              .height(46)
              .maxLength(20)
              .fontSize(15)
              .fontColor(AppTheme.text)
              .placeholderColor(AppTheme.muted)
              .backgroundColor(Color.Transparent)
              .enabled(!this.loading)
              .onChange((value: string) => this.newPassword = value)
            Button(this.showPassword ? '隐藏' : '显示')
              .width(64)
              .height(44)
              .fontSize(13)
              .fontColor(AppTheme.primary)
              .backgroundColor(Color.Transparent)
              .enabled(!this.loading)
              .onClick(() => this.showPassword = !this.showPassword)
          }
          .width('100%')
          .height(48)
          .padding({ left: 4, right: 2 })
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.borderStrong })
          .borderRadius(8)

          Text('确认新密码')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .width('100%')
            .margin({ top: 18, bottom: 8 })
          TextInput({ text: this.confirmPassword, placeholder: '再次输入新密码' })
            .type(InputType.Password)
            .height(48)
            .maxLength(20)
            .fontSize(15)
            .fontColor(AppTheme.text)
            .placeholderColor(AppTheme.muted)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.borderStrong })
            .borderRadius(8)
            .enabled(!this.loading)
            .onChange((value: string) => this.confirmPassword = value)
            .onSubmit(() => this.submit())

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(13)
              .fontColor(AppTheme.dangerText)
              .width('100%')
              .padding(11)
              .backgroundColor(AppTheme.dangerSurface)
              .border({ width: 1, color: AppTheme.danger })
              .borderRadius(6)
              .margin({ top: 14 })
          }
          if (this.successMessage.length > 0) {
            Text(this.successMessage)
              .fontSize(13)
              .fontColor(AppTheme.successText)
              .width('100%')
              .padding(11)
              .backgroundColor(AppTheme.successSurface)
              .border({ width: 1, color: AppTheme.success })
              .borderRadius(6)
              .margin({ top: 14 })
          }

          Button(this.loading ? '正在重置' : '重置密码')
            .enabled(!this.loading && !this.sendingCode)
            .width('100%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.primaryText)
            .backgroundColor(AppTheme.primaryStrong)
            .borderRadius(8)
            .margin({ top: 20 })
            .onClick(() => this.submit())
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 480 })
      .padding({ left: 22, right: 22, top: 24, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
    .align(Alignment.Top)
  }
}
