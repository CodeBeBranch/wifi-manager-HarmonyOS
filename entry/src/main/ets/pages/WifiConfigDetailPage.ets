import router from '@ohos.router'
import { WifiConfigTask, wifiConfigStatusLabel } from '../model/WifiConfigModels'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface WifiDetailParams {
  deviceCode: string
  requestId: string
}

@Entry
@Component
struct WifiConfigDetailPage {
  @State deviceCode: string = ''
  @State requestId: string = ''
  @State task: WifiConfigTask | null = null
  @State loading: boolean = true
  @State errorMessage: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as WifiDetailParams | null
    this.deviceCode = params?.deviceCode ?? ''
    this.requestId = params?.requestId ?? ''
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.errorMessage = ''
    try {
      this.task = await repositoryFactory.wifiConfig().find(this.deviceCode, this.requestId)
    } catch (error) {
      this.errorMessage = error instanceof Error ? error.message : 'WiFi 任务详情加载失败'
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
        Text('WiFi 任务详情').fontSize(23).fontWeight(FontWeight.Bold)
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
      } else if (this.task !== null) {
        Column({ space: 14 }) {
          this.row('状态', wifiConfigStatusLabel(this.task.status))
          this.row('requestId', this.task.requestId)
          this.row('SSID', this.task.ssid)
          this.row('配置版本', String(this.task.configVersion))
          this.row('密码已配置', this.task.passwordConfigured ? '是' : '否')
          this.row('失败原因', this.task.failureMessage ?? '-')
          this.row('提交时间', this.task.stagedTime?.replace('T', ' ') ?? '-')
          this.row('生效时间', this.task.activatedTime?.replace('T', ' ') ?? '-')
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
    Column({ space: 4 }) {
      Text(label).fontSize(11).fontColor(AppTheme.muted).width('100%')
      Text(value).fontSize(13).fontColor(AppTheme.textSoft).width('100%')
    }
    .alignItems(HorizontalAlign.Start).width('100%')
  }
}
