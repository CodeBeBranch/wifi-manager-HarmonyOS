import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { DeviceSignalRecord } from '../model/Hm3Models'
import { resetToLogin } from '../navigation/AppRouter'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface DeviceSignalParams {
  nodeId: string
  deviceName: string
}

@Entry
@Component
struct DeviceSignalPage {
  @State nodeId: string = ''
  @State deviceName: string = ''
  @State records: DeviceSignalRecord[] = []
  @State loading: boolean = true
  @State errorMessage: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as DeviceSignalParams | null
    this.nodeId = params?.nodeId ?? ''
    this.deviceName = params?.deviceName ?? ''
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.errorMessage = ''
    try {
      this.records = await repositoryFactory.deviceMetrics().listSignals(this.nodeId)
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        resetToLogin()
        return
      }
      this.errorMessage = error instanceof Error ? error.message : '信号记录加载失败'
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
        Column({ space: 2 }) {
          Text(this.deviceName || `设备 ${this.nodeId}`).fontSize(11).fontColor(AppTheme.primary)
          Text('信号记录').fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button('刷新').height(44).fontSize(13).fontColor(AppTheme.textSoft)
          .backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
          .onClick(() => this.load())
      }
      .width('100%').margin({ bottom: 16 })

      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).layoutWeight(1)
      } else if (this.errorMessage.length > 0) {
        Text(this.errorMessage).fontSize(13).fontColor(AppTheme.dangerText)
          .width('100%').padding(16).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      } else if (this.records.length === 0) {
        Text('暂无信号记录').fontSize(13).fontColor(AppTheme.muted)
          .width('100%').padding(24).textAlign(TextAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.records, (record: DeviceSignalRecord) => {
            ListItem() {
              Column({ space: 8 }) {
                Row() {
                  Text(record.mac).fontSize(15).fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.text).layoutWeight(1)
                  Text(`${record.rssi} dBm`).fontSize(13)
                    .fontColor(record.rssi >= -65 ? AppTheme.successText : AppTheme.warningText)
                }
                Text(`估算距离 ${record.distanceMeters.toFixed(1)} m`)
                  .fontSize(12).fontColor(AppTheme.textSoft).width('100%')
                Text(record.recordedAt.replace('T', ' '))
                  .fontSize(11).fontColor(AppTheme.muted).width('100%')
              }
              .width('100%').padding(14).backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            }
            .onClick(() => router.pushUrl({
              url: 'pages/DeviceSignalDetailPage',
              params: { signalId: String(record.signalId) }
            }))
          }, (record: DeviceSignalRecord) => String(record.signalId))
        }
        .width('100%').layoutWeight(1)
      }
    }
    .width('100%').height('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 16 })
    .backgroundColor(AppTheme.background)
  }
}
