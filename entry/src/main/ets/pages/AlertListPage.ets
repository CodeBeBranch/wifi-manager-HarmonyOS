import router from '@ohos.router'
import {
  AlertEvent,
  AlertPushEvent,
  AlertQuery,
  AlertSocketState
} from '../model/AlertModels'
import { ApiError } from '../model/ApiModels'
import { alertSocketClient } from '../network/AlertSocketClient'
import { alertRepository } from '../repository/AlertRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface AlertDetailParams {
  id: string
}

@Entry
@Component
struct AlertListPage {
  @State alerts: AlertEvent[] = []
  @State level: string = ''
  @State status: string = ''
  @State mac: string = ''
  @State current: number = 1
  @State pageSize: number = 10
  @State total: number = 0
  @State loading: boolean = false
  @State errorMessage: string = ''
  @State socketState: AlertSocketState = 'idle'
  @State socketAttempt: number = 0
  @State liveAlertMessage: string = ''
  private appliedLevel: string = ''
  private appliedStatus: string = ''
  private appliedMac: string = ''
  private requestVersion: number = 0

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const contextType = snapshot.context?.contextType ?? ''
    const admin = snapshot.role === 0 || snapshot.role === 1
    if (!snapshot.authenticated || !admin ||
      (contextType !== 'TENANT' && contextType !== 'PLATFORM_TENANT')) {
      router.replaceUrl({ url: 'pages/WorkspacePage' })
      return
    }
    this.load(1)
    alertSocketClient.start(
      (state: AlertSocketState, attempt: number): void => {
        this.socketState = state
        this.socketAttempt = attempt
      },
      (alert: AlertPushEvent): void => {
        this.liveAlertMessage = alert.title || alert.ruleCode || `收到告警 ${alert.alertId}`
      }
    )
  }

  aboutToDisappear(): void {
    alertSocketClient.stop()
  }

  private async load(page: number): Promise<void> {
    const requestVersion = ++this.requestVersion
    this.loading = true
    this.errorMessage = ''
    const query: AlertQuery = {
      current: page,
      size: this.pageSize,
      level: this.appliedLevel,
      status: this.appliedStatus,
      mac: this.appliedMac
    }
    try {
      const result = await alertRepository.list(query)
      if (requestVersion !== this.requestVersion) return
      this.alerts = result.records ?? []
      this.current = Number(result.current)
      this.pageSize = Number(result.size)
      this.total = Number(result.total)
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        router.replaceUrl({ url: 'pages/LoginPage' })
        return
      }
      if (requestVersion !== this.requestVersion) return
      this.errorMessage = error instanceof ApiError ? error.message : '告警加载失败，请稍后重试'
    } finally {
      if (requestVersion === this.requestVersion) {
        this.loading = false
      }
    }
  }

  private changeStatus(status: string): void {
    if (this.status === status || this.loading) return
    this.status = status
    this.appliedStatus = status
    this.load(1)
  }

  private changeLevel(level: string): void {
    if (this.level === level || this.loading) return
    this.level = level
    this.appliedLevel = level
    this.load(1)
  }

  private search(): void {
    this.appliedMac = this.mac.trim()
    this.appliedLevel = this.level
    this.appliedStatus = this.status
    this.load(1)
  }

  private totalPages(): number {
    return Math.max(1, Math.ceil(this.total / Math.max(1, this.pageSize)))
  }

  private levelLabel(level: number): string {
    if (level === 1) return '低'
    if (level === 2) return '中'
    if (level === 3) return '高'
    return `未知(${level})`
  }

  private levelColor(level: number): Resource {
    if (level === 3) return AppTheme.dangerText
    if (level === 2) return AppTheme.warningText
    if (level === 1) return AppTheme.infoText
    return AppTheme.muted
  }

  private levelSurface(level: number): Resource {
    if (level === 3) return AppTheme.dangerSurface
    if (level === 2) return AppTheme.warningSurface
    return AppTheme.surfaceMuted
  }

  private openDetail(id: number): void {
    const params: AlertDetailParams = { id: String(id) }
    router.pushUrl({
      url: 'pages/AlertDetailPage',
      params: params
    })
  }

  private socketLabel(): string {
    if (this.socketState === 'connected') return '实时告警已连接'
    if (this.socketState === 'connecting') return '正在连接实时告警'
    if (this.socketState === 'reconnecting') {
      return `实时告警重连中 (${this.socketAttempt})`
    }
    if (this.socketState === 'auth-required') return '实时告警连接被拒绝'
    if (this.socketState === 'disconnected') return '实时告警已断开'
    return '实时告警未连接'
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
          Text('告警').fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
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
          .onClick(() => this.load(this.current))
      }
      .width('100%')

      Row({ space: 8 }) {
        Circle()
          .width(8)
          .height(8)
          .fill(this.socketState === 'connected' ? AppTheme.successText : AppTheme.warningText)
        Text(this.socketLabel())
          .fontSize(12)
          .fontColor(AppTheme.muted)
          .layoutWeight(1)
          .maxLines(1)
        if (this.socketState === 'disconnected' || this.socketState === 'auth-required') {
          Button('重连')
            .height(36)
            .fontSize(12)
            .fontColor(AppTheme.primary)
            .backgroundColor(Color.Transparent)
            .onClick(() => alertSocketClient.retry())
        }
      }
      .width('100%')
      .height(40)
      .margin({ top: 8 })

      if (this.liveAlertMessage.length > 0) {
        Row({ space: 10 }) {
          Text(this.liveAlertMessage)
            .fontSize(13)
            .fontColor(AppTheme.textSoft)
            .layoutWeight(1)
            .maxLines(2)
          Button('刷新')
            .height(38)
            .fontSize(12)
            .fontColor(AppTheme.primaryText)
            .backgroundColor(AppTheme.primaryStrong)
            .borderRadius(6)
            .onClick(() => {
              this.liveAlertMessage = ''
              this.load(1)
            })
        }
        .width('100%')
        .padding({ left: 12, right: 8, top: 8, bottom: 8 })
        .backgroundColor(AppTheme.surfaceMuted)
        .borderRadius(8)
        .margin({ top: 4 })
      }

      Row({ space: 4 }) {
        this.statusButton('全部', '')
        this.statusButton('未处理', '0')
        this.statusButton('已处理', '1')
      }
      .width('100%')
      .padding(4)
      .backgroundColor(AppTheme.surfaceMuted)
      .borderRadius(8)
      .margin({ top: 16 })

      Row({ space: 4 }) {
        this.levelButton('全部级别', '')
        this.levelButton('低', '1')
        this.levelButton('中', '2')
        this.levelButton('高', '3')
      }
      .width('100%')
      .padding(4)
      .backgroundColor(AppTheme.backgroundSoft)
      .borderRadius(8)
      .margin({ top: 8 })

      Row({ space: 8 }) {
        TextInput({ text: this.mac, placeholder: 'MAC 地址' })
          .layoutWeight(1)
          .height(44)
          .fontSize(13)
          .fontColor(AppTheme.text)
          .placeholderColor(AppTheme.muted)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.borderStrong })
          .borderRadius(8)
          .maxLength(17)
          .onChange((value: string) => this.mac = value)
          .onSubmit(() => this.search())
        Button('查询')
          .height(44)
          .fontSize(14)
          .fontColor(AppTheme.primaryText)
          .backgroundColor(AppTheme.primaryStrong)
          .borderRadius(8)
          .onClick(() => this.search())
      }
      .width('100%')
      .margin({ top: 10, bottom: 12 })

      if (this.errorMessage.length > 0) {
        Column({ space: 10 }) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor(AppTheme.dangerText)
            .textAlign(TextAlign.Center)
          Button('重试')
            .height(44)
            .fontSize(13)
            .fontColor(AppTheme.primaryText)
            .backgroundColor(AppTheme.primaryStrong)
            .borderRadius(8)
            .onClick(() => this.load(this.current))
        }
        .width('100%')
        .padding(18)
        .backgroundColor(AppTheme.dangerSurface)
        .borderRadius(8)
      } else if (this.loading && this.alerts.length === 0) {
        Column({ space: 12 }) {
          LoadingProgress().width(36).height(36).color(AppTheme.primary)
          Text('正在加载告警').fontSize(13).fontColor(AppTheme.muted)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.alerts.length === 0) {
        Text('当前条件下没有告警')
          .fontSize(14)
          .fontColor(AppTheme.muted)
          .width('100%')
          .padding(24)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border })
          .borderRadius(8)
      } else {
        List({ space: 8 }) {
          ForEach(this.alerts, (alert: AlertEvent) => {
            ListItem() {
              Column({ space: 9 }) {
                Row({ space: 8 }) {
                  Text(this.levelLabel(alert.level))
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.levelColor(alert.level))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .backgroundColor(this.levelSurface(alert.level))
                    .borderRadius(5)
                  Text(alert.title || `告警 ${alert.id}`)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.text)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(alert.status === 1 ? '已处理' : '未处理')
                    .fontSize(12)
                    .fontColor(alert.status === 1 ? AppTheme.successText : AppTheme.warningText)
                }
                Text(alert.ruleCode || '未记录规则编码')
                  .fontSize(12)
                  .fontColor(AppTheme.muted)
                  .width('100%')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Row() {
                  Text(alert.mac || '未记录 MAC')
                    .fontSize(12)
                    .fontColor(AppTheme.textSoft)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text('›').fontSize(20).fontColor(AppTheme.muted)
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)
            }
            .onClick(() => this.openDetail(alert.id))
          }, (alert: AlertEvent) => String(alert.id))
        }
        .width('100%')
        .layoutWeight(1)
      }

      Row() {
        Button('‹')
          .width(44)
          .height(44)
          .fontSize(22)
          .enabled(this.current > 1 && !this.loading)
          .fontColor(AppTheme.textSoft)
          .backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.border })
          .borderRadius(8)
          .onClick(() => this.load(this.current - 1))
        Text(`${this.current} / ${this.totalPages()}  共 ${this.total} 条`)
          .fontSize(12)
          .fontColor(AppTheme.muted)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button('›')
          .width(44)
          .height(44)
          .fontSize(22)
          .enabled(this.current < this.totalPages() && !this.loading)
          .fontColor(AppTheme.textSoft)
          .backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.border })
          .borderRadius(8)
          .onClick(() => this.load(this.current + 1))
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 16 })
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private statusButton(label: string, status: string) {
    Button(label)
      .layoutWeight(1)
      .height(38)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.status === status ? AppTheme.primaryText : AppTheme.textSoft)
      .backgroundColor(this.status === status ? AppTheme.primaryStrong : Color.Transparent)
      .borderRadius(6)
      .onClick(() => this.changeStatus(status))
  }

  @Builder
  private levelButton(label: string, level: string) {
    Button(label)
      .layoutWeight(1)
      .height(38)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.level === level ? AppTheme.text : AppTheme.muted)
      .backgroundColor(this.level === level ? AppTheme.surface : Color.Transparent)
      .borderRadius(6)
      .onClick(() => this.changeLevel(level))
  }
}
