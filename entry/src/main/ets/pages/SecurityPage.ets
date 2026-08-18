import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { SecuritySession } from '../model/Hm1Models'
import { accountRepositoryFactory } from '../repository/AccountRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct SecurityPage {
  @State sessions: SecuritySession[] = []
  @State currentPassword: string = ''
  @State newPassword: string = ''
  @State loading: boolean = true
  @State working: boolean = false
  @State message: string = ''
  @State error: string = ''

  aboutToAppear(): void {
    this.loadSessions()
  }

  private async loadSessions(): Promise<void> {
    this.loading = true
    try {
      const snapshot = sessionStore.getSnapshot()
      this.sessions = await accountRepositoryFactory.current().listSecuritySessions(snapshot.username)
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '会话加载失败'
    } finally {
      this.loading = false
    }
  }

  private async revokeOthers(): Promise<void> {
    this.working = true
    this.message = ''
    this.error = ''
    try {
      const snapshot = sessionStore.getSnapshot()
      this.sessions = await accountRepositoryFactory.current().revokeOtherSessions(snapshot.username)
      this.message = '其他设备会话已退出'
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '退出其他会话失败'
    } finally {
      this.working = false
    }
  }

  private async changePassword(): Promise<void> {
    this.working = true
    this.message = ''
    this.error = ''
    try {
      const snapshot = sessionStore.getSnapshot()
      await accountRepositoryFactory.current().changePassword(
        snapshot.username,
        this.currentPassword,
        this.newPassword
      )
      this.currentPassword = ''
      this.newPassword = ''
      this.message = '密码校验流程已完成，演示账号密码保持不变'
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '密码修改失败'
    } finally {
      this.working = false
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
        Text('账号安全')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 12 })

      Scroll() {
        Column() {
          Text('安全验证')
            .fontSize(13)
            .fontColor(AppTheme.muted)
            .width('100%')
            .margin({ bottom: 8 })
          Row() {
            SymbolGlyph($r('sys.symbol.lock'))
              .fontSize(22)
              .fontColor([AppTheme.primary])
              .width(40)
            Column({ space: 3 }) {
              Text('二次验证')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.text)
              Text('用于敏感账号操作')
                .fontSize(12)
                .fontColor(AppTheme.muted)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›').fontSize(21).fontColor(AppTheme.muted)
          }
          .width('100%')
          .height(68)
          .padding({ left: 12, right: 12 })
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border })
          .borderRadius(8)
          .onClick(() => router.pushUrl({ url: 'pages/StepUpPage' }))

          Text('修改密码')
            .fontSize(13)
            .fontColor(AppTheme.muted)
            .width('100%')
            .margin({ top: 24, bottom: 8 })
          Column({ space: 12 }) {
            TextInput({ text: this.currentPassword, placeholder: '当前密码' })
              .type(InputType.Password)
              .height(48)
              .fontColor(AppTheme.text)
              .placeholderColor(AppTheme.muted)
              .backgroundColor(AppTheme.backgroundSoft)
              .borderRadius(8)
              .onChange((value: string) => this.currentPassword = value)
            TextInput({ text: this.newPassword, placeholder: '新密码' })
              .type(InputType.Password)
              .height(48)
              .fontColor(AppTheme.text)
              .placeholderColor(AppTheme.muted)
              .backgroundColor(AppTheme.backgroundSoft)
              .borderRadius(8)
              .onChange((value: string) => this.newPassword = value)
            Button('确认修改')
              .enabled(!this.working)
              .width('100%')
              .height(46)
              .fontSize(14)
              .fontColor(AppTheme.primaryText)
              .backgroundColor(AppTheme.primaryStrong)
              .borderRadius(8)
              .onClick(() => this.changePassword())
          }
          .width('100%')
          .padding(14)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border })
          .borderRadius(8)

          Row() {
            Text('登录设备')
              .fontSize(13)
              .fontColor(AppTheme.muted)
              .layoutWeight(1)
            Button('退出其他设备')
              .enabled(!this.working && this.sessions.length > 1)
              .height(40)
              .fontSize(12)
              .fontColor(AppTheme.dangerText)
              .backgroundColor(Color.Transparent)
              .onClick(() => this.revokeOthers())
          }
          .width('100%')
          .margin({ top: 24, bottom: 8 })

          if (this.loading) {
            LoadingProgress().width(32).height(32).color(AppTheme.primary)
          } else {
            Column() {
              ForEach(this.sessions, (item: SecuritySession, index: number) => {
                Row({ space: 12 }) {
                  SymbolGlyph($r('sys.symbol.cloud'))
                    .fontSize(22)
                    .fontColor([item.current ? AppTheme.primary : AppTheme.textSoft])
                    .width(34)
                  Column({ space: 3 }) {
                    Text(item.deviceName)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.text)
                    Text(`${item.location} · ${item.lastActive}`)
                      .fontSize(12)
                      .fontColor(AppTheme.muted)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  if (item.current) {
                    Text('当前')
                      .fontSize(12)
                      .fontColor(AppTheme.successText)
                  }
                }
                .width('100%')
                .height(64)
                .border({
                  width: { bottom: index < this.sessions.length - 1 ? 1 : 0 },
                  color: AppTheme.border
                })
              }, (item: SecuritySession) => item.id)
            }
            .width('100%')
            .padding({ left: 14, right: 14 })
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)
          }

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
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 18, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }
}
