import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { resetToLogin, resetToMain } from '../navigation/AppRouter'
import {
  NetworkSession,
  SessionQuery
} from '../model/SessionModels'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface SessionDetailParams {
  session: string
}

@Component
export struct SessionListContent {
  @Prop embedded: boolean = false
  @State sessions: NetworkSession[] = []
  @State mac: string = ''
  @State nodeId: string = ''
  @State userId: string = ''
  @State status: string = ''
  @State current: number = 1
  @State pageSize: number = 10
  @State total: number = 0
  @State loading: boolean = false
  @State errorMessage: string = ''
  @State admin: boolean = false
  private requestVersion: number = 0
  private appliedMac: string = ''
  private appliedNodeId: string = ''
  private appliedUserId: string = ''
  private appliedStatus: string = ''

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const contextType = snapshot.context?.contextType ?? ''
    if (!snapshot.authenticated || (contextType !== 'TENANT' && contextType !== 'PLATFORM_TENANT')) {
      resetToMain()
      return
    }
    this.admin = snapshot.role === 0 || snapshot.role === 1
    this.load(1)
  }

  private async load(page: number): Promise<void> {
    const requestVersion = ++this.requestVersion
    this.loading = true
    this.errorMessage = ''
    const query: SessionQuery = {
      current: page,
      size: this.pageSize,
      mac: this.appliedMac,
      nodeId: this.appliedNodeId,
      userId: this.appliedUserId,
      status: this.appliedStatus
    }
    try {
      const result = await repositoryFactory.session().list(query, this.admin)
      if (requestVersion !== this.requestVersion) return
      this.sessions = result.records ?? []
      this.current = Number(result.current)
      this.pageSize = Number(result.size)
      this.total = Number(result.total)
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        resetToLogin()
        return
      }
      if (requestVersion !== this.requestVersion) return
      this.errorMessage = error instanceof ApiError ? error.message : '连接记录加载失败，请稍后重试'
    } finally {
      if (requestVersion === this.requestVersion) {
        this.loading = false
      }
    }
  }

  private search(): void {
    const nodeId = this.nodeId.trim()
    const userId = this.userId.trim()
    if ((nodeId.length > 0 && !/^[1-9]\d*$/.test(nodeId)) ||
      (this.admin && userId.length > 0 && !/^[1-9]\d*$/.test(userId))) {
      this.errorMessage = '设备编号和用户编号必须是正整数'
      return
    }
    this.appliedMac = this.mac.trim()
    this.appliedNodeId = nodeId
    this.appliedUserId = userId
    this.appliedStatus = this.status
    this.load(1)
  }

  private changeStatus(status: string): void {
    if (this.status === status || this.loading) return
    this.status = status
    this.appliedStatus = status
    this.load(1)
  }

  private totalPages(): number {
    return Math.max(1, Math.ceil(this.total / Math.max(1, this.pageSize)))
  }

  private statusLabel(status: number): string {
    if (status === 0) return '已结束'
    if (status === 1) return '连接中'
    if (status === 2) return '待确认'
    if (status === 3) return '替换中'
    return `未知(${status})`
  }

  private statusColor(status: number): Resource {
    if (status === 1) return AppTheme.successText
    if (status === 2) return AppTheme.warningText
    if (status === 3) return AppTheme.infoText
    return AppTheme.muted
  }

  private statusSurface(status: number): Resource {
    if (status === 1) return AppTheme.successSurface
    if (status === 2) return AppTheme.warningSurface
    return AppTheme.surfaceMuted
  }

  private formatBytes(value: number): string {
    const bytes = Number(value)
    if (!Number.isFinite(bytes)) return '-'
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
    return `${(bytes / 1024 / 1024 / 1024).toFixed(1)} GB`
  }

  private openDetail(session: NetworkSession): void {
    const params: SessionDetailParams = {
      session: JSON.stringify(session)
    }
    router.pushUrl({
      url: 'pages/SessionDetailPage',
      params: params
    })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        if (!this.embedded) {
          Button('‹')
            .width(44)
            .height(44)
            .fontSize(24)
            .fontColor(AppTheme.textSoft)
            .backgroundColor(AppTheme.surfaceRaised)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)
            .onClick(() => router.back())
        }
        Column({ space: 2 }) {
          Text(this.embedded && !this.admin ? '我的网络' : '网络工作区')
            .fontSize(11)
            .fontColor(AppTheme.primary)
          Text('连接记录').fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
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

      Row({ space: 4 }) {
        this.statusButton('全部', '')
        this.statusButton('连接中', '1')
        this.statusButton('待确认', '2')
        this.statusButton('替换中', '3')
        this.statusButton('已结束', '0')
      }
      .width('100%')
      .padding(4)
      .backgroundColor(AppTheme.surfaceMuted)
      .borderRadius(8)
      .margin({ top: 16 })

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
      .margin({ top: 10 })

      Row({ space: 8 }) {
        TextInput({ text: this.nodeId, placeholder: '设备编号' })
          .layoutWeight(1)
          .height(42)
          .fontSize(13)
          .fontColor(AppTheme.text)
          .placeholderColor(AppTheme.muted)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border })
          .borderRadius(8)
          .onChange((value: string) => this.nodeId = value)
        if (this.admin) {
          TextInput({ text: this.userId, placeholder: '用户编号' })
            .layoutWeight(1)
            .height(42)
            .fontSize(13)
            .fontColor(AppTheme.text)
            .placeholderColor(AppTheme.muted)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)
            .onChange((value: string) => this.userId = value)
        }
      }
      .width('100%')
      .margin({ top: 8, bottom: 12 })

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
      } else if (this.loading && this.sessions.length === 0) {
        Column({ space: 12 }) {
          LoadingProgress().width(36).height(36).color(AppTheme.primary)
          Text('正在加载连接记录').fontSize(13).fontColor(AppTheme.muted)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.sessions.length === 0) {
        Text('当前条件下没有连接记录')
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
          ForEach(this.sessions, (session: NetworkSession) => {
            ListItem() {
              Column({ space: 9 }) {
                Row() {
                  Text(session.mac || `连接 ${session.sessionId}`)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.text)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.statusLabel(session.status))
                    .fontSize(12)
                    .fontColor(this.statusColor(session.status))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .backgroundColor(this.statusSurface(session.status))
                    .borderRadius(5)
                }
                Row() {
                  Text(`设备 ${session.nodeId ?? '-'}`)
                    .fontSize(12)
                    .fontColor(AppTheme.muted)
                    .layoutWeight(1)
                  if (this.admin) {
                    Text(`用户 ${session.userId ?? '-'}`)
                      .fontSize(12)
                      .fontColor(AppTheme.muted)
                  }
                }
                Row() {
                  Text(`↑ ${this.formatBytes(session.bytesUp)}`)
                    .fontSize(12)
                    .fontColor(AppTheme.textSoft)
                    .layoutWeight(1)
                  Text(`↓ ${this.formatBytes(session.bytesDown)}`)
                    .fontSize(12)
                    .fontColor(AppTheme.textSoft)
                  Text('›').fontSize(20).fontColor(AppTheme.muted).margin({ left: 10 })
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)
            }
            .onClick(() => this.openDetail(session))
          }, (session: NetworkSession) => String(session.sessionId))
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
    .padding({ left: 16, right: 16, top: this.embedded ? 14 : 20, bottom: 16 })
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private statusButton(label: string, status: string) {
    Button(label)
      .layoutWeight(1)
      .height(38)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.status === status ? AppTheme.primaryText : AppTheme.textSoft)
      .backgroundColor(this.status === status ? AppTheme.primaryStrong : Color.Transparent)
      .borderRadius(6)
      .onClick(() => this.changeStatus(status))
  }
}

@Entry
@Component
struct SessionListPage {
  build() {
    Column() {
      SessionListContent({ embedded: false })
    }
    .width('100%')
    .height('100%')
  }
}
