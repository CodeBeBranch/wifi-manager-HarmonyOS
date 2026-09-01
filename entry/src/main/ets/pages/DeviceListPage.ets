import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { resetToLogin } from '../navigation/AppRouter'
import { DeviceNode } from '../model/DeviceModels'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'
import { sessionStore } from '../session/SessionStore'

@Component
export struct DeviceListContent {
  @Prop embedded: boolean = false
  @State devices: DeviceNode[] = []
  @State keyword: string = ''
  @State appliedKeyword: string = ''
  @State current: number = 1
  @State pageSize: number = 10
  @State total: number = 0
  @State loading: boolean = false
  @State errorMessage: string = ''
  @State writable: boolean = false
  private requestVersion: number = 0
  private requestedPage: number = 1

  aboutToAppear(): void {
    this.writable = sessionStore.getSnapshot().context?.authorities.includes('DEVICE_WRITE') ?? false
    this.load(1)
  }

  private async load(page: number): Promise<void> {
    const requestVersion = ++this.requestVersion
    this.requestedPage = page
    this.loading = true
    this.errorMessage = ''
    try {
      const result = await repositoryFactory.device().list(page, this.pageSize, this.appliedKeyword)
      if (requestVersion !== this.requestVersion) return
      this.devices = result.records ?? []
      this.current = Number(result.current)
      this.pageSize = Number(result.size)
      this.total = Number(result.total)
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        resetToLogin()
        return
      }
      if (requestVersion !== this.requestVersion) return
      this.errorMessage = error instanceof Error ? error.message : '设备列表加载失败'
    } finally {
      if (requestVersion === this.requestVersion) {
        this.loading = false
      }
    }
  }

  private search(): void {
    this.appliedKeyword = this.keyword.trim()
    this.load(1)
  }

  private totalPages(): number {
    return Math.max(1, Math.ceil(this.total / Math.max(1, this.pageSize)))
  }

  private statusText(status: number): string {
    if (status === 1) return '在线'
    if (status === 0) return '离线'
    if (status === -1) return '已删除'
    return `未知(${status})`
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        if (!this.embedded) {
          Button('‹').accessibilityText('返回')
            .width(44).height(44).fontSize(24)
            .fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surfaceRaised)
            .border({ width: 1, color: AppTheme.border }).borderRadius(6)
            .onClick(() => router.back())
        }
        Column({ space: 2 }) {
          Text(this.embedded ? '网络资源' : '网络工作区').fontSize(11).fontColor(AppTheme.primary)
          Text('设备').fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('刷新')
          .height(44).fontSize(13).fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(6)
          .onClick(() => this.load(this.current))
        if (this.writable) {
          Button('+').accessibilityText('新建')
            .width(44).height(44).fontSize(24)
            .fontColor(AppTheme.primaryText).backgroundColor(AppTheme.primaryStrong)
            .borderRadius(8)
            .onClick(() => router.pushUrl({ url: 'pages/DeviceEditorPage' }))
        }
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.keyword, placeholder: '名称、编号或位置' })
          .height(44).fontSize(14).fontColor(AppTheme.text).placeholderColor(AppTheme.muted)
          .backgroundColor(AppTheme.backgroundSoft)
          .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(6).layoutWeight(1)
          .onChange((value: string) => this.keyword = value)
          .onSubmit(() => this.search())
        Button('查询')
          .height(44).fontSize(14).fontColor(AppTheme.primaryText)
          .backgroundColor(AppTheme.primaryStrong).borderRadius(6)
          .onClick(() => this.search())
      }
      .width('100%')
      .margin({ top: 18, bottom: 12 })

      if (this.errorMessage.length > 0) {
        Column({ space: 10 }) {
          Text(this.errorMessage).fontSize(13).fontColor(AppTheme.dangerText).textAlign(TextAlign.Center)
          Button('重试')
            .height(44).fontSize(13).fontColor(AppTheme.primaryText)
            .backgroundColor(AppTheme.primaryStrong).borderRadius(6)
            .onClick(() => this.load(this.requestedPage))
        }
        .width('100%').padding(18).backgroundColor(AppTheme.dangerSurface)
        .border({ width: 1, color: AppTheme.danger }).borderRadius(6)
      } else if (this.loading && this.devices.length === 0) {
        Column({ space: 12 }) {
          LoadingProgress().width(36).height(36).color(AppTheme.primary)
          Text('正在加载设备').fontSize(13).fontColor(AppTheme.muted)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.devices.length === 0) {
        Text('当前工作区没有设备')
          .fontSize(14).fontColor(AppTheme.muted).width('100%').padding(24)
          .textAlign(TextAlign.Center).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(6)
      } else {
        List({ space: 8 }) {
          ForEach(this.devices, (device: DeviceNode) => {
            ListItem() {
              Column({ space: 9 }) {
                Row() {
                  Circle()
                    .width(9).height(9).fill(device.status === 1 ? AppTheme.success : AppTheme.muted)
                    .margin({ right: 9 })
                  Text(device.name || device.deviceCode)
                    .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
                    .layoutWeight(1).maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.statusText(device.status))
                    .fontSize(12)
                    .fontColor(device.status === 1 ? AppTheme.successText : AppTheme.muted)
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .backgroundColor(device.status === 1 ? AppTheme.successSurface : AppTheme.surfaceMuted)
                    .borderRadius(5)
                }
                Row() {
                  Text(device.deviceCode || '-')
                    .fontSize(12).fontColor(AppTheme.muted).layoutWeight(1).maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${device.currentClients ?? 0}/${device.maxClients ?? 0} 台`)
                    .fontSize(12).fontColor(AppTheme.textSoft)
                }
                Text(device.location || '未设置位置')
                  .fontSize(12).fontColor(AppTheme.muted).width('100%').maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%').padding(14).backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border }).borderRadius(6)
            }
            .onClick(() => router.pushUrl({
              url: 'pages/DeviceDetail',
              params: { nodeId: String(device.nodeId) }
            }))
          }, (device: DeviceNode) => String(device.nodeId))
        }
        .width('100%')
        .layoutWeight(1)
      }

      Row() {
        Button('‹').accessibilityText('返回')
          .width(44).height(44).fontSize(22).enabled(this.current > 1 && !this.loading)
          .fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.border }).borderRadius(6)
          .onClick(() => this.load(this.current - 1))
        Text(`${this.current} / ${this.totalPages()}  共 ${this.total} 台`)
          .fontSize(12).fontColor(AppTheme.muted).layoutWeight(1).textAlign(TextAlign.Center)
        Button('›').accessibilityText('下一页')
          .width(44).height(44).fontSize(22)
          .enabled(this.current < this.totalPages() && !this.loading)
          .fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.border }).borderRadius(6)
          .onClick(() => this.load(this.current + 1))
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: this.embedded ? 14 : 20, bottom: 12 })
    .backgroundColor(AppTheme.background)
  }
}

@Entry
@Component
struct DeviceListPage {
  @State contentRevision: number = 0

  onPageShow(): void {
    this.contentRevision += 1
  }

  build() {
    Column() {
      ForEach([this.contentRevision], (_revision: number) => {
        DeviceListContent({ embedded: false })
      }, (revision: number): string => String(revision))
    }
    .width('100%')
    .height('100%')
  }
}
