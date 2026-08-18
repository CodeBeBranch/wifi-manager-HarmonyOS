import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { isEmailContact, isPhoneContact } from '../model/AuthModels'
import { UserProfile } from '../model/Hm1Models'
import { accountRepositoryFactory } from '../repository/AccountRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct ProfilePage {
  @State username: string = ''
  @State nickname: string = ''
  @State email: string = ''
  @State phone: string = ''
  @State department: string = ''
  @State loading: boolean = true
  @State saving: boolean = false
  @State message: string = ''
  @State error: string = ''

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    try {
      const snapshot = sessionStore.getSnapshot()
      const profile = await accountRepositoryFactory.current().getProfile(snapshot.username)
      this.username = profile.username
      this.nickname = profile.nickname
      this.email = profile.email
      this.phone = profile.phone
      this.department = profile.department
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '资料加载失败'
    } finally {
      this.loading = false
    }
  }

  private async save(): Promise<void> {
    this.error = ''
    this.message = ''
    if (this.nickname.trim().length < 2) {
      this.error = '昵称至少需要 2 个字符'
      return
    }
    if (this.email.length > 0 && !isEmailContact(this.email)) {
      this.error = '邮箱格式不正确'
      return
    }
    if (this.phone.length > 0 && !isPhoneContact(this.phone)) {
      this.error = '手机号格式不正确'
      return
    }
    this.saving = true
    try {
      const profile: UserProfile = {
        username: this.username,
        nickname: this.nickname.trim(),
        email: this.email.trim(),
        phone: this.phone.trim(),
        department: this.department.trim()
      }
      await accountRepositoryFactory.current().updateProfile(this.username, profile)
      await sessionStore.updateDemoNickname(profile.nickname)
      this.message = '资料已保存'
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '资料保存失败'
    } finally {
      this.saving = false
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
        Text('个人资料')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .layoutWeight(1)
        Button(this.saving ? '保存中' : '保存')
          .enabled(!this.saving && !this.loading)
          .height(44)
          .fontSize(14)
          .fontColor(AppTheme.primary)
          .backgroundColor(Color.Transparent)
          .onClick(() => this.save())
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12 })

      if (this.loading) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.primary)
          .layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 18 }) {
            this.field('用户名', this.username, 'username', false)
            this.field('昵称', this.nickname, 'nickname', true)
            this.field('邮箱', this.email, 'email', true)
            this.field('手机号', this.phone, 'phone', true)
            this.field('部门', this.department, 'department', true)

            if (this.message.length > 0) {
              Text(this.message)
                .fontSize(13)
                .fontColor(AppTheme.successText)
                .width('100%')
            }
            if (this.error.length > 0) {
              Text(this.error)
                .fontSize(13)
                .fontColor(AppTheme.dangerText)
                .width('100%')
            }
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 22, bottom: 32 })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private field(label: string, value: string, key: string, enabled: boolean) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontColor(AppTheme.textSoft)
        .width('100%')
      TextInput({ text: value })
        .enabled(enabled)
        .width('100%')
        .height(48)
        .fontSize(15)
        .fontColor(enabled ? AppTheme.text : AppTheme.muted)
        .backgroundColor(enabled ? AppTheme.surface : AppTheme.surfaceMuted)
        .border({ width: 1, color: AppTheme.borderStrong })
        .borderRadius(8)
        .onChange((next: string) => {
          if (key === 'nickname') this.nickname = next
          if (key === 'email') this.email = next
          if (key === 'phone') this.phone = next
          if (key === 'department') this.department = next
        })
    }
    .width('100%')
  }
}
