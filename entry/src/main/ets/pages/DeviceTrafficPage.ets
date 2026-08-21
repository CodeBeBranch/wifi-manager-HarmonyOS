import router from '@ohos.router'
import { DeviceTrafficPoint } from '../model/Hm3Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface DeviceTrafficParams {
  nodeId: string
  deviceName: string
}

@Entry
@Component
struct DeviceTrafficPage {
  @State nodeId: string = ''
  @State deviceName: string = ''
  @State points: DeviceTrafficPoint[] = []
  @State loading: boolean = true
  @State errorMessage: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as DeviceTrafficParams | null
    this.nodeId = params?.nodeId ?? ''
    this.deviceName = params?.deviceName ?? ''
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.errorMessage = ''
    try {
      this.points = await repositoryFactory.deviceMetrics().listTraffic(this.nodeId)
    } catch (error) {
      this.errorMessage = error instanceof Error ? error.message : '流量趋势加载失败'
    } finally {
      this.loading = false
    }
  }

  private formatBytes(value: number): string {
    return `${(value / 1024 / 1024).toFixed(1)} MB`
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
          Text('流量趋势').fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
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
      } else {
        List({ space: 8 }) {
          ForEach(this.points, (point: DeviceTrafficPoint) => {
            ListItem() {
              Column({ space: 9 }) {
                Text(point.recordedAt.replace('T', ' ')).fontSize(12)
                  .fontColor(AppTheme.muted).width('100%')
                Row() {
                  Text('上行').fontSize(13).fontColor(AppTheme.textSoft)
                  Text(this.formatBytes(point.bytesUp)).fontSize(14).fontColor(AppTheme.infoText)
                    .layoutWeight(1).textAlign(TextAlign.End)
                }
                Row() {
                  Text('下行').fontSize(13).fontColor(AppTheme.textSoft)
                  Text(this.formatBytes(point.bytesDown)).fontSize(14).fontColor(AppTheme.successText)
                    .layoutWeight(1).textAlign(TextAlign.End)
                }
              }
              .width('100%').padding(14).backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            }
          }, (point: DeviceTrafficPoint) => String(point.pointId))
        }
        .width('100%').layoutWeight(1)
      }
    }
    .width('100%').height('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 16 })
    .backgroundColor(AppTheme.background)
  }
}
