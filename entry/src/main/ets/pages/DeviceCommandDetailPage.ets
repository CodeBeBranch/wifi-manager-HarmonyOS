import router from '@ohos.router'
import {
  DeviceCommandRecord,
  deviceCommandStatusLabel,
  deviceCommandTypeLabel
} from '../model/DeviceCommandModels'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface CommandDetailParams {
  deviceCode: string
  requestId: string
}

@Entry
@Component
struct DeviceCommandDetailPage {
  @State deviceCode: string = ''
  @State requestId: string = ''
  @State record: DeviceCommandRecord | null = null
  @State loading: boolean = true
  @State errorMessage: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as CommandDetailParams | null
    this.deviceCode = params?.deviceCode ?? ''
    this.requestId = params?.requestId ?? ''
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.errorMessage = ''
    try {
      this.record = await repositoryFactory.deviceCommand()
        .findByRequestId(this.deviceCode, this.requestId)
      if (this.record === null) this.errorMessage = '没有找到命令记录'
    } catch (error) {
      this.errorMessage = error instanceof Error ? error.message : '命令详情加载失败'
    } finally {
      this.loading = false
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button('‹').width(44).height(44).fontSize(24)
          .fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
          .onClick(() => router.back())
        Text('命令详情').fontSize(23).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
        Button('刷新').height(44).fontSize(13).fontColor(AppTheme.textSoft)
          .backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
          .onClick(() => this.load())
      }
      .width('100%').margin({ bottom: 18 })
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).layoutWeight(1)
      } else if (this.errorMessage.length > 0) {
        Text(this.errorMessage).fontSize(13).fontColor(AppTheme.dangerText)
          .width('100%').padding(16).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      } else if (this.record !== null) {
        Scroll() {
          Column({ space: 14 }) {
            this.row('命令', deviceCommandTypeLabel(this.record.commandType, this.record.purpose))
            this.row('状态', deviceCommandStatusLabel(this.record.status))
            this.row('requestId', this.record.requestId)
            this.row('设备', this.record.deviceCode)
            this.row('失败/结果', this.record.resultMessage ?? '-')
            this.row('创建时间', this.record.createTime?.replace('T', ' ') ?? '-')
            this.row('结果时间', this.record.resultTime?.replace('T', ' ') ?? '-')
          }
          .width('100%').padding(16).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
        }
        .layoutWeight(1)
      }
    }
    .width('100%').height('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 16 })
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private row(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label).fontSize(11).fontColor(AppTheme.muted).width('100%')
      Text(value).fontSize(13).fontColor(AppTheme.textSoft).width('100%')
    }
    .alignItems(HorizontalAlign.Start).width('100%')
  }
}
