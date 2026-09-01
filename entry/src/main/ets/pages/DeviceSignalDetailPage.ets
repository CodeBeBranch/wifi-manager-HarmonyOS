import router from '@ohos.router'
import { DeviceSignalRecord } from '../model/Hm3Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface SignalDetailParams {
  signalId: string
}

@Entry
@Component
struct DeviceSignalDetailPage {
  @State signalId: number = 0
  @State record: DeviceSignalRecord | null = null
  @State loading: boolean = true
  @State errorMessage: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as SignalDetailParams | null
    this.signalId = Number(params?.signalId ?? '0')
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.errorMessage = ''
    try {
      this.record = await repositoryFactory.deviceMetrics().signalDetail(this.signalId)
    } catch (error) {
      this.errorMessage = error instanceof Error ? error.message : '信号详情加载失败'
    } finally {
      this.loading = false
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24)
          .fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
          .onClick(() => router.back())
        Text('信号详情').fontSize(23).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
      }
      .width('100%').margin({ bottom: 18 })

      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).layoutWeight(1)
      } else if (this.errorMessage.length > 0) {
        Text(this.errorMessage).fontSize(13).fontColor(AppTheme.dangerText)
          .width('100%').padding(16).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      } else if (this.record !== null) {
        Column({ space: 14 }) {
          this.row('MAC', this.record.mac)
          this.row('设备编号', String(this.record.nodeId))
          this.row('连接编号', this.record.sessionId === null ? '-' : String(this.record.sessionId))
          this.row('RSSI', `${this.record.rssi} dBm`)
          this.row('估算距离', `${this.record.distanceMeters.toFixed(1)} m`)
          this.row('采集时间', this.record.recordedAt.replace('T', ' '))
        }
        .width('100%').padding(16).backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.border }).borderRadius(8)
      }
    }
    .width('100%').height('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 16 })
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private row(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor(AppTheme.muted)
      Text(value).fontSize(13).fontColor(AppTheme.textSoft)
        .layoutWeight(1).textAlign(TextAlign.End)
    }
    .width('100%')
  }
}
