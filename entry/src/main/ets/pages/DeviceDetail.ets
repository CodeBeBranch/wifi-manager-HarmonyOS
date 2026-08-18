import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { resetToLogin } from '../navigation/AppRouter'
import { DeviceNode } from '../model/DeviceModels'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface DeviceDetailParams {
  nodeId: string
}

interface DeviceCommandParams {
  deviceCode: string
  deviceName: string
}

interface WifiConfigParams {
  nodeId: string
}

@Entry
@Component
struct DeviceDetailPage {
  @State nodeId: string = ''
  @State device: DeviceNode | null = null
  @State loading: boolean = true
  @State errorMessage: string = ''
  private requestVersion: number = 0

  aboutToAppear(): void {
    const params = router.getParams() as DeviceDetailParams | null
    this.nodeId = params?.nodeId ?? ''
    this.load()
  }

  private async load(): Promise<void> {
    if (this.nodeId.length === 0) {
      this.errorMessage = '设备编号无效'
      this.loading = false
      return
    }
    const requestVersion = ++this.requestVersion
    this.loading = true
    this.errorMessage = ''
    try {
      const device = await repositoryFactory.device().detail(this.nodeId)
      if (requestVersion !== this.requestVersion) return
      this.device = device
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        resetToLogin()
        return
      }
      if (requestVersion !== this.requestVersion) return
      this.errorMessage = error instanceof Error ? error.message : '设备详情加载失败'
    } finally {
      if (requestVersion === this.requestVersion) {
        this.loading = false
      }
    }
  }

  private display(value: string | number | null | undefined): string {
    if (value === null || value === undefined || String(value).length === 0) return '-'
    return String(value)
  }

  private formatTime(value: string | null | undefined): string {
    return value === null || value === undefined || value.length === 0 ? '-' : value.replace('T', ' ')
  }

  private openCommands(): void {
    if (this.device === null) return
    const params: DeviceCommandParams = {
      deviceCode: this.device.deviceCode,
      deviceName: this.device.name
    }
    router.pushUrl({
      url: 'pages/DeviceCommandPage',
      params: params
    })
  }

  private openWifiConfig(): void {
    if (this.device === null) return
    const params: WifiConfigParams = {
      nodeId: String(this.device.nodeId)
    }
    router.pushUrl({
      url: 'pages/WifiConfigPage',
      params: params
    })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button('‹')
          .width(44).height(44).fontSize(24)
          .fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.border }).borderRadius(6)
          .onClick(() => router.back())
        Column({ space: 2 }) {
          Text('网络工作区 / 设备详情').fontSize(11).fontColor(AppTheme.primary)
          Text('设备详情').fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('刷新')
          .height(44).fontSize(13).fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(6)
          .onClick(() => this.load())
      }
      .width('100%')
      .margin({ bottom: 18 })

      if (this.loading) {
        Column({ space: 12 }) {
          LoadingProgress().width(36).height(36).color(AppTheme.primary)
          Text('正在加载设备详情').fontSize(13).fontColor(AppTheme.muted)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMessage.length > 0) {
        Column({ space: 12 }) {
          Text(this.errorMessage).fontSize(14).fontColor(AppTheme.dangerText).textAlign(TextAlign.Center)
          Button('重试')
            .height(44).fontSize(14).fontColor(AppTheme.primaryText)
            .backgroundColor(AppTheme.primaryStrong).borderRadius(6)
            .onClick(() => this.load())
        }
        .width('100%').padding(22).backgroundColor(AppTheme.dangerSurface)
        .border({ width: 1, color: AppTheme.danger }).borderRadius(6)
      } else if (this.device !== null) {
        Scroll() {
          Column({ space: 14 }) {
            Row() {
              Circle()
                .width(12).height(12).fill(this.device.status === 1 ? AppTheme.success : AppTheme.muted)
                .margin({ right: 10 })
              Column({ space: 3 }) {
                Text(this.device.name || this.device.deviceCode)
                  .fontSize(20).fontWeight(FontWeight.Bold).fontColor(AppTheme.text).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.device.status === 1 ? '在线' : '离线')
                  .fontSize(12)
                  .fontColor(this.device.status === 1 ? AppTheme.successText : AppTheme.muted)
              }
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%').padding(16).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(6)

            Button('设备控制与执行记录')
              .width('100%')
              .height(48)
              .fontSize(14)
              .fontColor(AppTheme.primary)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.primary })
              .borderRadius(8)
              .onClick(() => this.openCommands())

            Button('上游 WiFi 配置')
              .width('100%')
              .height(48)
              .fontSize(14)
              .fontColor(AppTheme.primary)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.primary })
              .borderRadius(8)
              .onClick(() => this.openWifiConfig())

            Column({ space: 13 }) {
              Text('设备信息')
                .fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.primary).width('100%')
              this.detailRow('节点 ID', this.display(this.device.nodeId))
              this.detailRow('设备编号', this.display(this.device.deviceCode))
              this.detailRow('IP 地址', this.display(this.device.ip))
              this.detailRow('位置', this.display(this.device.location))
              this.detailRow('固件版本', this.display(this.device.firmwareVersion))
              this.detailRow('WiFi 状态', this.display(this.device.wifiStatus))
              this.detailRow('联网设备',
                `${this.display(this.device.currentClients)} / ${this.display(this.device.maxClients)}`)
              this.detailRow('最后心跳', this.formatTime(this.device.lastHeartbeat))
            }
            .width('100%').padding(16).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(6)

            Column({ space: 13 }) {
              Text('运行数据')
                .fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.primary).width('100%')
              this.detailRow('纬度', this.display(this.device.latitude))
              this.detailRow('经度', this.display(this.device.longitude))
              this.detailRow('1 米 RSSI', this.display(this.device.rssiAtOneMeter))
              this.detailRow('路径损耗指数', this.display(this.device.pathLossExponent))
              this.detailRow('创建时间', this.formatTime(this.device.createTime))
              this.detailRow('更新时间', this.formatTime(this.device.updateTime))
            }
            .width('100%').padding(16).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(6)
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
        .fontSize(13).fontColor(AppTheme.textSoft).layoutWeight(1).textAlign(TextAlign.End).maxLines(2)
    }
    .width('100%')
  }
}
