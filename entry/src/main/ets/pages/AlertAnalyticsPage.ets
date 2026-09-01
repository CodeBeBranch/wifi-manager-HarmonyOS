import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { AlertAnalytics } from '../model/Hm4Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct AlertAnalyticsPage {
  @State data: AlertAnalytics | null = null
  @State loading: boolean = true
  @State error: string = ''
  aboutToAppear(): void { this.load() }
  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.data = await repositoryFactory.hm4Security().analytics()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '告警分析加载失败'
    } finally {
      this.loading = false
    }
  }
  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('告警分析').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text).layoutWeight(1)
        Button('刷新').height(44).fontSize(13).backgroundColor(AppTheme.surfaceMuted).fontColor(AppTheme.primary)
          .borderRadius(6).onClick(() => this.load())
      }.width('100%')
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.data === null) {
        Text(this.error.length > 0 ? this.error : '告警分析不可用').width('100%').padding(16)
          .fontColor(AppTheme.dangerText).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      } else {
        Column({ space: 12 }) {
          this.metric('告警总数', String(this.data.total), AppTheme.primary)
          this.metric('待处理', String(this.data.pending), AppTheme.warningText)
          this.metric('已处理', String(this.data.handled), AppTheme.successText)
          this.metric('高等级告警', String(this.data.highLevel), AppTheme.dangerText)
          Text('重点规则').fontSize(12).fontColor(AppTheme.muted).width('100%').margin({ top: 8 })
          Text(this.data.topRule).fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.text).width('100%')
        }.width('100%').padding(16).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
  @Builder private metric(label: string, value: string, color: Resource) {
    Row() {
      Text(label).fontSize(14).fontColor(AppTheme.textSoft).layoutWeight(1)
      Text(value).fontSize(24).fontWeight(FontWeight.Bold).fontColor(color)
    }.width('100%').padding({ top: 6, bottom: 6 })
  }
}
