import router from '@ohos.router'
import { AlertEvent } from '../model/AlertModels'
import { ApiError } from '../model/ApiModels'
import { resetToLogin, resetToMain } from '../navigation/AppRouter'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface AlertDetailParams {
  id: string
}

@Entry
@Component
struct AlertDetailPage {
  @State alertId: number = 0
  @State alert: AlertEvent | null = null
  @State writable: boolean = false
  @State loading: boolean = true
  @State handling: boolean = false
  @State confirming: boolean = false
  @State errorMessage: string = ''
  @State successMessage: string = ''
  private requestVersion: number = 0

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const contextType = snapshot.context?.contextType ?? ''
    const admin = snapshot.role === 0 || snapshot.role === 1
    if (!snapshot.authenticated || !admin ||
      (contextType !== 'TENANT' && contextType !== 'PLATFORM_TENANT')) {
      resetToMain()
      return
    }
    this.writable = snapshot.context?.authorities.includes('ALERT_HANDLE') ?? false
    const params = router.getParams() as AlertDetailParams | null
    const id = Number(params?.id ?? '0')
    if (!Number.isInteger(id) || id <= 0) {
      this.loading = false
      this.errorMessage = '告警编号无效'
      return
    }
    this.alertId = id
    this.load()
  }

  private async load(): Promise<void> {
    const requestVersion = ++this.requestVersion
    this.loading = true
    this.errorMessage = ''
    try {
      const detail = await repositoryFactory.alert().detail(this.alertId)
      if (requestVersion !== this.requestVersion) return
      if (Number(detail.id) !== this.alertId) {
        throw new ApiError('告警详情响应无效', 502, 502, 'DEPENDENCY_PROTOCOL_INVALID')
      }
      this.alert = detail
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        resetToLogin()
        return
      }
      if (requestVersion !== this.requestVersion) return
      this.errorMessage = error instanceof ApiError ? error.message : '告警详情加载失败，请稍后重试'
    } finally {
      if (requestVersion === this.requestVersion) {
        this.loading = false
      }
    }
  }

  private async handleAlert(): Promise<void> {
    if (!this.writable || this.alert === null || this.alert.status === 1 || this.handling) return
    this.handling = true
    this.errorMessage = ''
    this.successMessage = ''
    try {
      await repositoryFactory.alert().handle(this.alertId, this.alert.version ?? 0)
      await this.load()
      this.confirming = false
      this.successMessage = '告警已标记为已处理'
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        resetToLogin()
        return
      }
      this.errorMessage = error instanceof ApiError ? error.message : '告警处理失败，请稍后重试'
    } finally {
      this.handling = false
    }
  }

  private levelLabel(level: number): string {
    if (level === 1) return '低级'
    if (level === 2) return '中级'
    if (level === 3) return '高级'
    return `未知(${level})`
  }

  private levelColor(level: number): Resource {
    if (level === 3) return AppTheme.dangerText
    if (level === 2) return AppTheme.warningText
    if (level === 1) return AppTheme.infoText
    return AppTheme.muted
  }

  private display(value: string | number | null | undefined): string {
    if (value === null || value === undefined || String(value).length === 0) return '-'
    return String(value)
  }

  private formatTime(value: string | null): string {
    return value === null || value.length === 0 ? '-' : value.replace('T', ' ')
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
          Text('安全工作区').fontSize(11).fontColor(AppTheme.primary)
          Text('告警详情').fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('刷新')
          .height(44)
          .fontSize(13)
          .fontColor(AppTheme.textSoft)
          .backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.borderStrong })
          .borderRadius(8)
          .onClick(() => this.load())
      }
      .width('100%')
      .margin({ bottom: 18 })

      if (this.loading && this.alert === null) {
        Column({ space: 12 }) {
          LoadingProgress().width(36).height(36).color(AppTheme.primary)
          Text('正在加载告警详情').fontSize(13).fontColor(AppTheme.muted)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.alert === null) {
        Column({ space: 12 }) {
          Text(this.errorMessage.length > 0 ? this.errorMessage : '告警详情不可用')
            .fontSize(14)
            .fontColor(AppTheme.dangerText)
            .textAlign(TextAlign.Center)
          Button('重试')
            .height(44)
            .fontSize(14)
            .fontColor(AppTheme.primaryText)
            .backgroundColor(AppTheme.primaryStrong)
            .borderRadius(8)
            .onClick(() => this.load())
        }
        .width('100%')
        .padding(18)
        .backgroundColor(AppTheme.dangerSurface)
        .borderRadius(8)
      } else {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 8 }) {
              Row() {
                Text(this.levelLabel(this.alert.level))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.levelColor(this.alert.level))
                  .layoutWeight(1)
                Text(this.alert.status === 1 ? '已处理' : '未处理')
                  .fontSize(12)
                  .fontColor(this.alert.status === 1 ? AppTheme.successText : AppTheme.warningText)
              }
              .width('100%')
              Text(this.alert.title || `告警 ${this.alert.id}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.text)
                .width('100%')
              Text(this.alert.detail || '未记录告警详情')
                .fontSize(14)
                .fontColor(AppTheme.textSoft)
                .lineHeight(21)
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)

            Column({ space: 13 }) {
              Text('告警信息')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.primary)
                .width('100%')
              this.detailRow('告警编号', this.display(this.alert.id))
              this.detailRow('规则编码', this.display(this.alert.ruleCode))
              this.detailRow('MAC 地址', this.display(this.alert.mac))
              this.detailRow('用户编号', this.display(this.alert.userId))
              this.detailRow('创建时间', this.formatTime(this.alert.createTime))
              this.detailRow('处理人', this.display(this.alert.handleUserId))
              this.detailRow('处理时间', this.formatTime(this.alert.handleTime))
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

            if (this.alert.status !== 1 && !this.writable) {
              Text('当前工作区为只读状态，告警操作不可用')
                .fontSize(13)
                .fontColor(AppTheme.warningText)
                .width('100%')
                .padding(12)
                .backgroundColor(AppTheme.warningSurface)
                .borderRadius(8)
            }

            if (this.alert.status !== 1 && this.writable && !this.confirming) {
              Button('标记为已处理')
                .width('100%')
                .height(48)
                .fontSize(14)
                .fontColor(AppTheme.primaryText)
                .backgroundColor(AppTheme.primaryStrong)
                .borderRadius(8)
                .onClick(() => this.confirming = true)
            }

            if (this.alert.status !== 1 && this.writable && this.confirming) {
              Column({ space: 12 }) {
                Text(`确定将告警 ${this.alert.id} 标记为已处理吗？`)
                  .fontSize(14)
                  .fontColor(AppTheme.textSoft)
                  .width('100%')
                Row({ space: 10 }) {
                  Button('取消')
                    .enabled(!this.handling)
                    .layoutWeight(1)
                    .height(46)
                    .fontSize(14)
                    .fontColor(AppTheme.textSoft)
                    .backgroundColor(AppTheme.surface)
                    .border({ width: 1, color: AppTheme.borderStrong })
                    .borderRadius(8)
                    .onClick(() => this.confirming = false)
                  Button(this.handling ? '正在处理' : '确认')
                    .enabled(!this.handling)
                    .layoutWeight(1)
                    .height(46)
                    .fontSize(14)
                    .fontColor(AppTheme.primaryText)
                    .backgroundColor(AppTheme.primaryStrong)
                    .borderRadius(8)
                    .onClick(() => this.handleAlert())
                }
                .width('100%')
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppTheme.backgroundSoft)
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
