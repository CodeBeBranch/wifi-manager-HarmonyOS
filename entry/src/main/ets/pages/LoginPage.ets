import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import {
  isValidContact,
  isValidVerifyCode,
  LoginByCodeRequest,
  LoginRequest,
  SessionSnapshot
} from '../model/AuthModels'
import { sessionStore } from '../session/SessionStore'
import {
  loginPreferenceStore,
  LoginPreferenceSnapshot
} from '../storage/LoginPreferenceStore'
import { AppTheme } from '../ui/AppTheme'
import { ThemeSelector } from '../ui/ThemeSelector'

@Entry
@Component
struct LoginPage {
  @State loginType: string = 'username'
  @State contactLoginType: string = 'password'
  @State account: string = ''
  @State password: string = ''
  @State verifyCode: string = ''
  @State rememberAccount: boolean = true
  @State showPassword: boolean = false
  @State loading: boolean = false
  @State sendingCode: boolean = false
  @State codeCooldown: number = 0
  @State errorMessage: string = ''
  @State successMessage: string = ''
  @State accountStateMessage: string = ''
  private rememberedUsername: string = ''
  private rememberedContact: string = ''
  private codeTimer: number = -1

  aboutToAppear(): void {
    this.loadLoginPreference()
  }

  aboutToDisappear(): void {
    this.stopCodeTimer()
  }

  private async loadLoginPreference(): Promise<void> {
    try {
      const preference = await loginPreferenceStore.load()
      this.applyLoginPreference(preference)
    } catch (_) {
      this.rememberAccount = false
    }
  }

  private applyLoginPreference(preference: LoginPreferenceSnapshot): void {
    this.rememberAccount = preference.remember
    this.loginType = preference.loginMode
    this.rememberedUsername = preference.usernameAccount
    this.rememberedContact = preference.contactAccount
    this.account = this.loginType === 'contact'
      ? this.rememberedContact
      : this.rememberedUsername
  }

  private switchLoginType(type: string): void {
    if (this.loginType === type || this.loading) {
      return
    }
    if (this.loginType === 'contact') {
      this.rememberedContact = this.account
    } else {
      this.rememberedUsername = this.account
    }
    this.loginType = type
    this.account = type === 'contact' ? this.rememberedContact : this.rememberedUsername
    this.password = ''
    this.verifyCode = ''
    this.showPassword = false
    this.clearMessages()
  }

  private switchContactLoginType(type: string): void {
    if (this.contactLoginType === type || this.loading) {
      return
    }
    this.contactLoginType = type
    this.password = ''
    this.verifyCode = ''
    this.showPassword = false
    this.clearMessages()
  }

  private clearMessages(): void {
    this.errorMessage = ''
    this.successMessage = ''
    this.accountStateMessage = ''
  }

  private isCodeLogin(): boolean {
    return this.loginType === 'contact' && this.contactLoginType === 'code'
  }

  private validateLogin(account: string): boolean {
    if (account.length === 0) {
      this.errorMessage = this.loginType === 'contact' ? '请输入手机号或邮箱' : '请输入用户名'
      return false
    }
    if (this.loginType === 'contact' && !isValidContact(account)) {
      this.errorMessage = '请输入正确的手机号或邮箱'
      return false
    }
    if (this.isCodeLogin()) {
      if (!isValidVerifyCode(this.verifyCode)) {
        this.errorMessage = '请输入 6 位验证码'
        return false
      }
      return true
    }
    if (this.password.length === 0) {
      this.errorMessage = '请输入密码'
      return false
    }
    return true
  }

  private async submit(): Promise<void> {
    if (this.loading || this.sendingCode) {
      return
    }
    const account = this.account.trim()
    this.clearMessages()
    if (!this.validateLogin(account)) {
      return
    }

    this.loading = true
    try {
      let snapshot: SessionSnapshot
      if (this.isCodeLogin()) {
        const request: LoginByCodeRequest = {
          target: account,
          code: this.verifyCode.trim()
        }
        snapshot = await sessionStore.loginByCode(request)
      } else {
        const request: LoginRequest = {
          loginType: this.loginType,
          account: account,
          password: this.password
        }
        snapshot = await sessionStore.login(request)
      }

      this.password = ''
      this.verifyCode = ''
      if (!snapshot.authenticated) {
        this.showRestrictedAccount(snapshot)
        return
      }
      try {
        await loginPreferenceStore.save(this.loginType, account, this.rememberAccount)
      } catch (_) {
      }
      router.replaceUrl({ url: 'pages/WorkspacePage' })
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '登录失败，请稍后重试'
    } finally {
      this.loading = false
    }
  }

  private async sendCode(): Promise<void> {
    if (this.sendingCode || this.loading || this.codeCooldown > 0) {
      return
    }
    const account = this.account.trim()
    this.clearMessages()
    if (!isValidContact(account)) {
      this.errorMessage = account.length === 0 ? '请输入手机号或邮箱' : '请输入正确的手机号或邮箱'
      return
    }

    this.sendingCode = true
    try {
      await sessionStore.sendLoginCode(account)
      this.successMessage = '验证码已发送'
      this.startCodeTimer(60)
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '验证码发送失败，请稍后重试'
    } finally {
      this.sendingCode = false
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

  private showRestrictedAccount(snapshot: SessionSnapshot): void {
    this.accountStateMessage = snapshot.accountState === 'TENANT_MEMBERSHIP_PENDING'
      ? '账号正在等待加入工作区，暂时不能查看设备'
      : '当前账号状态不能进入工作区'
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Row({ space: 10 }) {
            Circle().width(9).height(9).fill(AppTheme.primary)
            Text('WiFi Manager')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.text)
          }
          .layoutWeight(1)
          ThemeSelector()
        }
        .width('100%')

        Text('登录')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .width('100%')
          .margin({ top: 42 })
        Text('进入网络工作区')
          .fontSize(15)
          .fontColor(AppTheme.muted)
          .width('100%')
          .margin({ top: 8, bottom: 30 })

        Row({ space: 4 }) {
          Button('用户名')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.loginType === 'username' ? AppTheme.primaryText : AppTheme.text)
            .backgroundColor(this.loginType === 'username' ? AppTheme.primaryStrong : AppTheme.surface)
            .borderRadius(6)
            .onClick(() => this.switchLoginType('username'))
          Button('手机 / 邮箱')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.loginType === 'contact' ? AppTheme.primaryText : AppTheme.text)
            .backgroundColor(this.loginType === 'contact' ? AppTheme.primaryStrong : AppTheme.surface)
            .borderRadius(6)
            .onClick(() => this.switchLoginType('contact'))
        }
        .width('100%')
        .padding(4)
        .backgroundColor(AppTheme.surfaceMuted)
        .borderRadius(8)
        .margin({ bottom: 26 })

        Text(this.loginType === 'contact' ? '手机号 / 邮箱' : '用户名')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textSoft)
          .width('100%')
          .margin({ bottom: 8 })
        TextInput({
          text: this.account,
          placeholder: this.loginType === 'contact' ? '请输入手机号或邮箱' : '请输入用户名'
        })
          .height(48)
          .fontSize(15)
          .fontColor(AppTheme.text)
          .placeholderColor(AppTheme.muted)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.borderStrong })
          .borderRadius(8)
          .onChange((value: string) => this.account = value)

        if (this.loginType === 'contact') {
          Row({ space: 4 }) {
            Button('密码登录')
              .layoutWeight(1)
              .height(40)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.contactLoginType === 'password' ? AppTheme.text : AppTheme.muted)
              .backgroundColor(this.contactLoginType === 'password' ? AppTheme.surface : Color.Transparent)
              .borderRadius(6)
              .onClick(() => this.switchContactLoginType('password'))
            Button('验证码登录')
              .layoutWeight(1)
              .height(40)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.contactLoginType === 'code' ? AppTheme.text : AppTheme.muted)
              .backgroundColor(this.contactLoginType === 'code' ? AppTheme.surface : Color.Transparent)
              .borderRadius(6)
              .onClick(() => this.switchContactLoginType('code'))
          }
          .width('100%')
          .padding(3)
          .backgroundColor(AppTheme.backgroundSoft)
          .borderRadius(8)
          .margin({ top: 12 })
        }

        if (!this.isCodeLogin()) {
          Text('密码')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .width('100%')
            .margin({ top: 20, bottom: 8 })
          Row() {
            TextInput({ text: this.password, placeholder: '请输入密码' })
              .type(this.showPassword ? InputType.Normal : InputType.Password)
              .layoutWeight(1)
              .height(46)
              .fontSize(15)
              .fontColor(AppTheme.text)
              .placeholderColor(AppTheme.muted)
              .backgroundColor(Color.Transparent)
              .onChange((value: string) => this.password = value)
              .onSubmit(() => this.submit())
            Button(this.showPassword ? '隐藏' : '显示')
              .width(64)
              .height(44)
              .fontSize(13)
              .fontColor(AppTheme.primary)
              .backgroundColor(Color.Transparent)
              .onClick(() => this.showPassword = !this.showPassword)
          }
          .width('100%')
          .height(48)
          .padding({ left: 4, right: 2 })
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.borderStrong })
          .borderRadius(8)
        } else {
          Text('验证码')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .width('100%')
            .margin({ top: 20, bottom: 8 })
          Row({ space: 10 }) {
            TextInput({ text: this.verifyCode, placeholder: '6 位验证码' })
              .layoutWeight(1)
              .height(48)
              .fontSize(15)
              .fontColor(AppTheme.text)
              .placeholderColor(AppTheme.muted)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong })
              .borderRadius(8)
              .maxLength(6)
              .onChange((value: string) => this.verifyCode = value)
              .onSubmit(() => this.submit())
            Button(this.codeCooldown > 0
              ? `${this.codeCooldown}s 后重发`
              : (this.sendingCode ? '发送中' : '发送验证码'))
              .enabled(!this.sendingCode && this.codeCooldown === 0)
              .width(116)
              .height(48)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.codeCooldown > 0 ? AppTheme.muted : AppTheme.primary)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong })
              .borderRadius(8)
              .onClick(() => this.sendCode())
          }
          .width('100%')
        }

        Row({ space: 8 }) {
          Checkbox({ name: 'rememberAccount', group: 'login' })
            .select(this.rememberAccount)
            .selectedColor(AppTheme.primaryStrong)
            .width(24)
            .height(24)
            .onChange((value: boolean) => this.rememberAccount = value)
          Text('记住账号')
            .fontSize(14)
            .fontColor(AppTheme.textSoft)
        }
        .width('100%')
        .height(44)
        .margin({ top: 12 })

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor(AppTheme.dangerText)
            .width('100%')
            .padding(11)
            .backgroundColor(AppTheme.dangerSurface)
            .border({ width: 1, color: AppTheme.danger })
            .borderRadius(6)
            .margin({ top: 12 })
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
            .margin({ top: 12 })
        }
        if (this.accountStateMessage.length > 0) {
          Text(this.accountStateMessage)
            .fontSize(13)
            .fontColor(AppTheme.warningText)
            .width('100%')
            .padding(11)
            .backgroundColor(AppTheme.warningSurface)
            .border({ width: 1, color: AppTheme.warning })
            .borderRadius(6)
            .margin({ top: 12 })
        }

        Button(this.loading ? '正在登录' : '登录')
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

        Row({ space: 8 }) {
          Button('忘记密码')
            .layoutWeight(1)
            .height(46)
            .fontSize(14)
            .fontColor(AppTheme.primary)
            .backgroundColor(Color.Transparent)
            .onClick(() => router.pushUrl({ url: 'pages/ForgotPasswordPage' }))
          Button('创建账号')
            .layoutWeight(1)
            .height(46)
            .fontSize(14)
            .fontColor(AppTheme.primary)
            .backgroundColor(Color.Transparent)
            .onClick(() => router.pushUrl({ url: 'pages/RegisterPage' }))
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .width('100%')
      .constraintSize({ maxWidth: 480 })
      .padding({ left: 22, right: 22, top: 24, bottom: 36 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
    .align(Alignment.Top)
  }
}
