import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import {
  TenantAnalyticsSnapshot,
  TenantSignalInsight,
  TenantTrafficInsight
} from '../model/Hm6Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct TenantAnalyticsPage {
  @State snapshot: TenantAnalyticsSnapshot | null = null
  @State mode: string = 'SIGNAL'
  @State loading: boolean = true
  @State error: string = ''

  aboutToAppear(): void { this.load() }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.snapshot = await repositoryFactory.hm6Location().analytics()
    } catch (error) {
      this.snapshot = null
      this.error = error instanceof ApiError ? error.message : '分析数据加载失败'
    } finally {
      this.loading = false
    }
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('网络分析').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
        Button('刷新').height(44).fontSize(13).backgroundColor(AppTheme.surfaceMuted)
          .fontColor(AppTheme.primary).borderRadius(6).onClick(() => this.load())
      }.width('100%')
      Row({ space: 8 }) {
        Button('信号').layoutWeight(1).height(44)
          .backgroundColor(this.mode === 'SIGNAL' ? AppTheme.primaryStrong : AppTheme.surfaceMuted)
          .fontColor(this.mode === 'SIGNAL' ? AppTheme.primaryText : AppTheme.textSoft)
          .borderRadius(6).onClick(() => this.mode = 'SIGNAL')
        Button('流量').layoutWeight(1).height(44)
          .backgroundColor(this.mode === 'TRAFFIC' ? AppTheme.primaryStrong : AppTheme.surfaceMuted)
          .fontColor(this.mode === 'TRAFFIC' ? AppTheme.primaryText : AppTheme.textSoft)
          .borderRadius(6).onClick(() => this.mode = 'TRAFFIC')
      }.width('100%').padding(4).backgroundColor(AppTheme.surfaceMuted).borderRadius(8)
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      }
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.snapshot === null) {
        Text('分析暂不可用').width('100%').padding(24).textAlign(TextAlign.Center)
          .fontColor(AppTheme.muted)
      } else if ((this.snapshot?.signals.length ?? 0) === 0 &&
        (this.snapshot?.traffic.length ?? 0) === 0) {
        Text('当前场景没有分析数据').width('100%').padding(24).textAlign(TextAlign.Center)
          .fontColor(AppTheme.muted).backgroundColor(AppTheme.surface).borderRadius(8)
      } else {
        Row({ space: 8 }) {
          this.metric('平均信号', `${this.snapshot?.averageRssi ?? 0} dBm`)
          this.metric('总流量', `${this.snapshot?.totalTrafficMb ?? 0} MB`)
          this.metric('峰值终端', String(this.snapshot?.peakClients ?? 0))
        }.width('100%')
        List({ space: 8 }) {
          if (this.mode === 'SIGNAL') {
            ForEach(this.snapshot?.signals ?? [], (item: TenantSignalInsight) => {
              ListItem() {
                Row({ space: 10 }) {
                  Column({ space: 4 }) {
                    Text(item.zoneName).fontSize(15).fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.text)
                    Text(`${item.clientCount} 个终端`).fontSize(12).fontColor(AppTheme.muted)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Column({ space: 3 }) {
                    Text(`${item.averageRssi} dBm`).fontSize(15).fontWeight(FontWeight.Bold)
                      .fontColor(AppTheme.primary)
                    Text(item.qualityLabel).fontSize(12).fontColor(AppTheme.textSoft)
                  }.alignItems(HorizontalAlign.End)
                }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                  .border({ width: 1, color: AppTheme.border }).borderRadius(8)
              }
            }, (item: TenantSignalInsight): string => String(item.id))
          } else {
            ForEach(this.snapshot?.traffic ?? [], (item: TenantTrafficInsight) => {
              ListItem() {
                Row({ space: 10 }) {
                  Text(item.period).fontSize(15).fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.text).width(64)
                  Column({ space: 3 }) {
                    Text(`下行 ${item.downloadMb} MB · 上行 ${item.uploadMb} MB`)
                      .fontSize(13).fontColor(AppTheme.text)
                    Text(`${item.activeClients} 个活跃终端`).fontSize(12)
                      .fontColor(AppTheme.muted)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                  .border({ width: 1, color: AppTheme.border }).borderRadius(8)
              }
            }, (item: TenantTrafficInsight): string => String(item.id))
          }
        }.width('100%').layoutWeight(1)
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }

  @Builder
  private metric(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(15).fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.text).maxLines(1)
      Text(label).fontSize(11).fontColor(AppTheme.muted)
    }.layoutWeight(1).height(72).justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.border })
      .borderRadius(8)
  }
}
