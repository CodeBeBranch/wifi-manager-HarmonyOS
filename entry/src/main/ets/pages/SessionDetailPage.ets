import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { resetToLogin, resetToMain } from '../navigation/AppRouter'
import { NetworkSession } from '../model/SessionModels'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface SessionDetailParams {
  session: string
}

@Entry
@Component
struct SessionDetailPage {
  @State session: NetworkSession | null = null
  @State admin: boolean = false
  @State writable: boolean = false
  @State confirming: boolean = false
  @State closing: boolean = false
  @State errorMessage: string = ''
  @State successMessage: string = ''

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const contextType = snapshot.context?.contextType ?? ''
    if (!snapshot.authenticated || (contextType !== 'TENANT' && contextType !== 'PLATFORM_TENANT')) {
      resetToMain()
      return
    }
    const params = router.getParams() as SessionDetailParams | null
    this.admin = snapshot.role === 0 || snapshot.role === 1
    this.writable = snapshot.context?.authorities.includes(
      this.admin ? 'SESSION_REVOKE' : 'SESSION_SELF_READ'
    ) ?? false
    try {
      this.session = JSON.parse(params?.session ?? '') as NetworkSession
    } catch (_) {
      this.errorMessage = '连接详情参数无效'
    }
  }

  private statusLabel(status: number): string {
    if (status === 0) return '已结束'
    if (status === 1) return '连接中'
    if (status === 2) return '等待设备确认'
    if (status === 3) return '正在替换旧连接'
    return `未知(${status})`
  }

  private statusColor(status: number): Resource {
    if (status === 1) return AppTheme.successText
    if (status === 2) return AppTheme.warningText
    if (status === 3) return AppTheme.infoText
    return AppTheme.muted
  }

  private display(value: string | number | null | undefined): string {
    if (value === null || value === undefined || String(value).length === 0) return '-'
    return String(value)
  }

  private formatTime(value: string | null): string {
    return value === null || value.length === 0 ? '-' : value.replace('T', ' ')
  }

  private formatBytes(value: number): string {
    const bytes = Number(value)
    if (!Number.isFinite(bytes)) return '-'
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
    return `${(bytes / 1024 / 1024 / 1024).toFixed(1)} GB`
  }

  private async closeSession(): Promise<void> {
    if (!this.writable || this.session === null || this.session.status === 0 || this.closing) return
    const sessionId = this.session.sessionId
    this.closing = true
    this.errorMessage = ''
    this.successMessage = ''
    try {
      const updated = await repositoryFactory.session().close(sessionId, this.admin)
      if (Number(updated.sessionId) !== sessionId) {
        throw new ApiError(
          '连接操作响应无效',
          502,
          502,
          'DEPENDENCY_PROTOCOL_INVALID'
        )
      }
      this.session = updated
      this.confirming = false
      this.successMessage = this.admin
        ? '断开请求已提交，最终执行状态以后端和设备结果为准'
        : '注销请求已提交，最终执行状态以后端和设备结果为准'
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        resetToLogin()
        return
      }
      this.errorMessage = error instanceof ApiError ? error.message : '连接操作失败，请稍后重试'
    } finally {
      this.closing = false
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button('‹')
          .width(44)
          .height(44)
          .fontSize(24)
          .fontColor(AppTheme.textSoft)
          .backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.border })
          .borderRadius(8)
          .onClick(() => router.back())
        Column({ space: 2 }) {
          Text('连接记录').fontSize(11).fontColor(AppTheme.primary)
          Text('连接详情').fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: 18 })

      if (this.session === null) {
        Text(this.errorMessage.length > 0 ? this.errorMessage : '连接详情不可用')
          .fontSize(14)
          .fontColor(AppTheme.dangerText)
          .width('100%')
          .padding(18)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppTheme.dangerSurface)
          .borderRadius(8)
      } else {
        Scroll() {
          Column({ space: 14 }) {
            Row() {
              Column({ space: 5 }) {
                Text(`连接 ${this.session.sessionId}`)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.text)
                Text(this.session.mac || '未记录 MAC')
                  .fontSize(13)
                  .fontColor(AppTheme.muted)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text(this.statusLabel(this.session.status))
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.statusColor(this.session.status))
            }
            .width('100%')
            .padding(16)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)

            Column({ space: 13 }) {
              Text('连接信息')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.primary)
                .width('100%')
              this.detailRow('用户编号', this.display(this.session.userId))
              this.detailRow('设备编号', this.display(this.session.nodeId))
              this.detailRow('IP 地址', this.display(this.session.ip))
              this.detailRow('设备信息', this.display(this.session.deviceInfo))
              this.detailRow('替换连接', this.display(this.session.replacedSessionId))
            }
            .width('100%')
            .padding(16)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)

            Column({ space: 13 }) {
              Text('用量与时间')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.primary)
                .width('100%')
              this.detailRow('上行流量', this.formatBytes(this.session.bytesUp))
              this.detailRow('下行流量', this.formatBytes(this.session.bytesDown))
              this.detailRow('登录时间', this.formatTime(this.session.loginTime))
              this.detailRow('过期时间', this.formatTime(this.session.expireTime))
              this.detailRow('注销时间', this.formatTime(this.session.logoutTime))
            }
            .width('100%')
            .padding(16)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)

            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontSize(13)
                .fontColor(AppTheme.dangerText)
                .width('100%')
                .padding(12)
                .backgroundColor(AppTheme.dangerSurface)
                .borderRadius(8)
            }
            if (this.successMessage.length > 0) {
              Text(this.successMessage)
                .fontSize(13)
                .fontColor(AppTheme.successText)
                .width('100%')
                .padding(12)
                .backgroundColor(AppTheme.successSurface)
                .borderRadius(8)
            }

            if (this.session.status !== 0 && !this.writable) {
              Text('当前工作区为只读状态，连接操作不可用')
                .fontSize(13)
                .fontColor(AppTheme.warningText)
                .width('100%')
                .padding(12)
                .backgroundColor(AppTheme.warningSurface)
                .borderRadius(8)
            }

            if (this.session.status !== 0 && this.writable && !this.confirming) {
              Button(this.admin ? '断开连接' : '注销连接')
                .width('100%')
                .height(48)
                .fontSize(14)
                .fontColor(AppTheme.dangerText)
                .backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.danger })
                .borderRadius(8)
                .onClick(() => this.confirming = true)
            }

            if (this.session.status !== 0 && this.writable && this.confirming) {
              Column({ space: 12 }) {
                Text(this.admin
                  ? '确定要断开这条连接吗？提交后仍需等待设备执行结果。'
                  : '确定要注销这条连接吗？')
                  .fontSize(14)
                  .fontColor(AppTheme.dangerText)
                  .width('100%')
                Row({ space: 10 }) {
                  Button('取消')
                    .enabled(!this.closing)
                    .layoutWeight(1)
                    .height(46)
                    .fontSize(14)
                    .fontColor(AppTheme.textSoft)
                    .backgroundColor(AppTheme.surface)
                    .border({ width: 1, color: AppTheme.borderStrong })
                    .borderRadius(8)
                    .onClick(() => this.confirming = false)
                  Button(this.closing ? '正在提交' : '确认')
                    .enabled(!this.closing)
                    .layoutWeight(1)
                    .height(46)
                    .fontSize(14)
                    .fontColor(AppTheme.primaryText)
                    .backgroundColor(AppTheme.danger)
                    .borderRadius(8)
                    .onClick(() => this.closeSession())
                }
                .width('100%')
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppTheme.dangerSurface)
              .borderRadius(8)
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 16 })
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private detailRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor(AppTheme.muted)
      Text(value)
        .fontSize(13)
        .fontColor(AppTheme.textSoft)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(2)
    }
    .width('100%')
  }
}
