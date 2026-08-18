import router from '@ohos.router'
import { SessionSnapshot, anonymousSnapshot } from '../model/AuthModels'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'
import { ThemeSelector } from '../ui/ThemeSelector'

@Entry
@Component
struct WorkspacePage {
  @State snapshot: SessionSnapshot = anonymousSnapshot()
  @State loggingOut: boolean = false
  @State contextSwitching: boolean = false
  @State errorMessage: string = ''

  aboutToAppear(): void {
    this.snapshot = sessionStore.getSnapshot()
    if (!this.snapshot.authenticated) {
      router.replaceUrl({ url: 'pages/LoginPage' })
    }
  }

  private hasTenantContext(): boolean {
    const type = this.snapshot.context?.contextType ?? ''
    return type === 'TENANT' || type === 'PLATFORM_TENANT'
  }

  private canReadAdminDevices(): boolean {
    return this.hasTenantContext() && (this.snapshot.role === 0 || this.snapshot.role === 1)
  }

  private isPlatformContext(): boolean {
    return this.snapshot.role === 0 && this.snapshot.context?.contextType === 'PLATFORM'
  }

  private isManagedTenantContext(): boolean {
    return this.snapshot.role === 0 && this.snapshot.context?.contextType === 'PLATFORM_TENANT'
  }

  private roleLabel(): string {
    if (this.snapshot.role === 0) return '平台管理员'
    if (this.snapshot.role === 1) return '租户管理员'
    if (this.snapshot.role === 2) return '成员'
    return '未知角色'
  }

  private workspaceTitle(): string {
    if (this.isPlatformContext()) return '系统管理'
    return this.snapshot.context?.tenantName || '工作区'
  }

  private async logout(): Promise<void> {
    if (this.loggingOut) return
    this.loggingOut = true
    this.errorMessage = ''
    try {
      await sessionStore.logout()
    } catch (_) {
      this.errorMessage = ''
    } finally {
      this.loggingOut = false
      router.replaceUrl({ url: 'pages/LoginPage' })
    }
  }

  private async returnToPlatform(): Promise<void> {
    if (this.contextSwitching) return
    this.contextSwitching = true
    this.errorMessage = ''
    try {
      this.snapshot = await sessionStore.returnPlatformContext()
    } catch (error) {
      this.errorMessage = error instanceof Error ? error.message : '工作区切换失败，请稍后重试'
    } finally {
      this.contextSwitching = false
    }
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Row({ space: 9 }) {
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

        Text(this.workspaceTitle())
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .width('100%')
          .margin({ top: 32 })
        Text(`${this.snapshot.nickname || this.snapshot.username} · ${this.roleLabel()}`)
          .fontSize(14)
          .fontColor(AppTheme.muted)
          .width('100%')
          .margin({ top: 6 })

        Text('常用功能')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textSoft)
          .width('100%')
          .margin({ top: 30, bottom: 10 })

        if (this.isPlatformContext()) {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text('组织管理')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.text)
              Text('选择一个组织进入管理工作区')
                .fontSize(13)
                .fontColor(AppTheme.muted)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›').fontSize(24).fontColor(AppTheme.muted)
          }
            .width('100%')
            .height(76)
            .padding({ left: 16, right: 14 })
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)
            .onClick(() => router.pushUrl({ url: 'pages/PlatformTenantListPage' }))
        } else if (this.hasTenantContext()) {
          if (this.canReadAdminDevices()) {
            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text('设备')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.text)
                Text('查看设备状态、位置和运行信息')
                  .fontSize(13)
                  .fontColor(AppTheme.muted)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('›').fontSize(24).fontColor(AppTheme.muted)
            }
              .width('100%')
              .height(76)
              .padding({ left: 16, right: 14 })
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)
              .onClick(() => router.pushUrl({ url: 'pages/DeviceListPage' }))
          }

          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text('连接记录')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.text)
              Text(this.canReadAdminDevices() ? '查看和管理当前组织的网络连接' : '查看和注销我的网络连接')
                .fontSize(13)
                .fontColor(AppTheme.muted)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›').fontSize(24).fontColor(AppTheme.muted)
          }
            .width('100%')
            .height(76)
            .padding({ left: 16, right: 14 })
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)
            .margin({ top: this.canReadAdminDevices() ? 10 : 0 })
            .onClick(() => router.pushUrl({ url: 'pages/SessionListPage' }))

          if (this.canReadAdminDevices()) {
            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text('告警')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.text)
                Text('查看并处理当前组织的安全告警')
                  .fontSize(13)
                  .fontColor(AppTheme.muted)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('›').fontSize(24).fontColor(AppTheme.muted)
            }
              .width('100%')
              .height(76)
              .padding({ left: 16, right: 14 })
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)
              .margin({ top: 10 })
              .onClick(() => router.pushUrl({ url: 'pages/AlertListPage' }))
          }
        } else {
          Text('当前账号没有可用的组织工作区')
            .fontSize(14)
            .fontColor(AppTheme.warningText)
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.warningSurface)
            .borderRadius(8)
        }

        Text('账号与工作区')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textSoft)
          .width('100%')
          .margin({ top: 28, bottom: 10 })

        Column({ space: 14 }) {
          this.infoRow('账号角色', this.roleLabel())
          this.infoRow('当前组织', this.snapshot.context?.tenantName || '未进入组织')
          this.infoRow('组织角色', this.snapshot.context?.tenantRole || '-')
          this.infoRow('组织状态', this.snapshot.context?.tenantStatus || '-')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.border })
        .borderRadius(8)

        if (this.isManagedTenantContext()) {
          Button(this.contextSwitching ? '正在返回' : '返回系统管理')
            .enabled(!this.contextSwitching)
            .width('100%')
            .height(48)
            .fontSize(14)
            .fontColor(AppTheme.primary)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.primary })
            .borderRadius(8)
            .margin({ top: 14 })
            .onClick(() => this.returnToPlatform())
        }

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor(AppTheme.dangerText)
            .width('100%')
            .margin({ top: 14 })
        }

        Button(this.loggingOut ? '正在退出' : '退出登录')
          .enabled(!this.loggingOut)
          .width('100%')
          .height(48)
          .fontSize(14)
          .fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border })
          .borderRadius(8)
          .margin({ top: 28 })
          .onClick(() => this.logout())
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 24, bottom: 36 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor(AppTheme.muted)
      Text(value)
        .fontSize(14)
        .fontColor(AppTheme.text)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }
}
