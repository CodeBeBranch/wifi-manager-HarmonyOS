import router from '@ohos.router'
import { resetToLogin } from '../navigation/AppRouter'
import { ApiError } from '../model/ApiModels'
import {
  RegisterRequest,
  isEmailContact,
  isPhoneContact,
  isValidVerifyCode,
  validateAccountPassword,
  validateUsername
} from '../model/AuthModels'
import { publicAuthRepositoryFactory } from '../repository/AuthRepository'
import { AppTheme } from '../ui/AppTheme'
import { ThemeSelector } from '../ui/ThemeSelector'

@Entry
@Component
struct RegisterPage {
  @State contactType: string = 'email'
  @State username: string = ''
  @State nickname: string = ''
  @State contact: string = ''
  @State verifyCode: string = ''
  @State password: string = ''
  @State confirmPassword: string = ''
  @State showPassword: boolean = false
  @State loading: boolean = false
  @State sendingCode: boolean = false
  @State codeCooldown: number = 0
  @State registered: boolean = false
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
    this.password = ''
    this.confirmPassword = ''
    this.showPassword = false
  }

  private clearMessages(): void {
    this.errorMessage = ''
    this.successMessage = ''
  }

  private switchContactType(type: string): void {
    if (this.contactType === type || this.loading || this.sendingCode) return
    this.contactType = type
    this.contact = ''
    this.verifyCode = ''
    this.cooldownTarget = ''
    this.stopCodeTimer()
    this.codeCooldown = 0
    this.clearMessages()
  }

  private updateContact(value: string): void {
    this.contact = value
    if (value.trim() !== this.cooldownTarget) {
      this.verifyCode = ''
      this.cooldownTarget = ''
      this.stopCodeTimer()
      this.codeCooldown = 0
    }
  }

  private validateContact(contact: string): string {
    if (contact.length === 0) {
      return this.contactType === 'email' ? '请输入邮箱' : '请输入手机号'
    }
    if (this.contactType === 'email' && !isEmailContact(contact)) {
      return '请输入正确的邮箱'
    }
    if (this.contactType === 'phone' && !isPhoneContact(contact)) {
      return '请输入正确的手机号'
    }
    return ''
  }

  private validateForm(): string {
    const usernameError = validateUsername(this.username)
    if (usernameError.length > 0) return usernameError
    if (this.nickname.trim().length === 0) return '请输入昵称'
    const contactError = this.validateContact(this.contact.trim())
    if (contactError.length > 0) return contactError
    if (!isValidVerifyCode(this.verifyCode)) return '请输入 6 位验证码'
    const passwordError = validateAccountPassword(this.password)
    if (passwordError.length > 0) return passwordError
    if (this.password !== this.confirmPassword) return '两次输入的密码不一致'
    return ''
  }

  private async sendCode(): Promise<void> {
    if (this.sendingCode || this.loading || this.codeCooldown > 0) return
    const target = this.contact.trim()
    this.clearMessages()
    const validation = this.validateContact(target)
    if (validation.length > 0) {
      this.errorMessage = validation
      return
    }

    const pageVersion = this.pageVersion
    this.sendingCode = true
    try {
      await publicAuthRepositoryFactory.current().sendVerifyCode({
        target: target,
        scene: 'register'
      })
      if (pageVersion !== this.pageVersion || this.contact.trim() !== target) return
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
    if (this.loading || this.sendingCode || this.registered) return
    this.clearMessages()
    const validation = this.validateForm()
    if (validation.length > 0) {
      this.errorMessage = validation
      return
    }

    const pageVersion = this.pageVersion
    const target = this.contact.trim()
    const request: RegisterRequest = {
      username: this.username.trim(),
      password: this.password,
      nickname: this.nickname.trim(),
      email: this.contactType === 'email' ? target : null,
      phone: this.contactType === 'phone' ? target : null,
      emailCode: this.contactType === 'email' ? this.verifyCode.trim() : null,
      phoneCode: this.contactType === 'phone' ? this.verifyCode.trim() : null
    }
    this.loading = true
    const pending = publicAuthRepositoryFactory.current().register(request)
    this.clearSecrets()

    try {
      const response = await pending
      if (pageVersion !== this.pageVersion) return
      if (response.data === null || typeof response.data !== 'object' ||
        response.data.status !== 'SUCCESS' ||
        typeof response.data.message !== 'string' ||
        (response.data.conflictFields !== null &&
          !Array.isArray(response.data.conflictFields))) {
        throw new ApiError('注册响应无效', 502, 502, 'DEPENDENCY_PROTOCOL_INVALID',
          response.requestId)
      }
      this.registered = true
      this.successMessage = response.data.message.trim().length > 0
        ? response.data.message
        : '注册成功，请返回登录'
      this.stopCodeTimer()
      this.codeCooldown = 0
    } catch (error) {
      if (pageVersion !== this.pageVersion) return
      this.errorMessage = error instanceof ApiError ? error.message : '注册失败，请稍后重试'
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
          Button('‹').accessibilityText('返回')
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

        Text(this.registered ? '账号已创建' : '创建账号')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .width('100%')
          .margin({ top: 32 })
        Text(this.registered ? '返回登录后即可进入对应工作区' : '使用一个已验证的联系方式完成注册')
          .fontSize(14)
          .fontColor(AppTheme.muted)
          .width('100%')
          .margin({ top: 8, bottom: 26 })

        if (this.registered) {
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
          Text('用户名')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .width('100%')
            .margin({ bottom: 8 })
          TextInput({ text: this.username, placeholder: '3 到 20 位' })
            .height(48)
            .maxLength(20)
            .fontSize(15)
            .fontColor(AppTheme.text)
            .placeholderColor(AppTheme.muted)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.borderStrong })
            .borderRadius(8)
            .enabled(!this.loading)
            .onChange((value: string) => this.username = value)

          Text('昵称')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .width('100%')
            .margin({ top: 18, bottom: 8 })
          TextInput({ text: this.nickname, placeholder: '工作区中显示的名称' })
            .height(48)
            .fontSize(15)
            .fontColor(AppTheme.text)
            .placeholderColor(AppTheme.muted)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.borderStrong })
            .borderRadius(8)
            .enabled(!this.loading)
            .onChange((value: string) => this.nickname = value)

          Text('验证方式')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .width('100%')
            .margin({ top: 18, bottom: 8 })
            Row({ space: 8 }) {
            Button('邮箱')
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .fontColor(this.contactType === 'email' ? AppTheme.primaryText : AppTheme.text)
              .backgroundColor(this.contactType === 'email'
                ? AppTheme.primaryStrong : AppTheme.surface)
              .borderRadius(6)
              .onClick(() => this.switchContactType('email'))
            Button('手机号')
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .fontColor(this.contactType === 'phone' ? AppTheme.primaryText : AppTheme.text)
              .backgroundColor(this.contactType === 'phone'
                ? AppTheme.primaryStrong : AppTheme.surface)
              .borderRadius(6)
              .onClick(() => this.switchContactType('phone'))
          }
          .width('100%')
          .padding(4)
          .backgroundColor(AppTheme.surfaceMuted)
          .borderRadius(8)

          Text(this.contactType === 'email' ? '邮箱' : '手机号')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .width('100%')
            .margin({ top: 18, bottom: 8 })
          TextInput({
            text: this.contact,
            placeholder: this.contactType === 'email' ? 'name@example.com' : '请输入手机号'
          })
            .height(48)
            .maxLength(this.contactType === 'email' ? 120 : 11)
            .fontSize(15)
            .fontColor(AppTheme.text)
            .placeholderColor(AppTheme.muted)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.borderStrong })
            .borderRadius(8)
            .enabled(!this.loading && !this.sendingCode)
            .onChange((value: string) => this.updateContact(value))

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

          Text('密码')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .width('100%')
            .margin({ top: 18, bottom: 8 })
          Row() {
            TextInput({ text: this.password, placeholder: '6 到 20 位' })
              .type(this.showPassword ? InputType.Normal : InputType.Password)
              .layoutWeight(1)
              .height(46)
              .maxLength(20)
              .fontSize(15)
              .fontColor(AppTheme.text)
              .placeholderColor(AppTheme.muted)
              .backgroundColor(Color.Transparent)
              .enabled(!this.loading)
              .onChange((value: string) => this.password = value)
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

          Text('确认密码')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .width('100%')
            .margin({ top: 18, bottom: 8 })
          TextInput({ text: this.confirmPassword, placeholder: '再次输入密码' })
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

          Button(this.loading ? '正在创建' : '创建账号')
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
