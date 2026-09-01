import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberLocationRecord } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct MemberLocationHistoryPage {
  @State records: MemberLocationRecord[] = []
  @State loading: boolean = true
  @State error: string = ''
  @State confirmingClear: boolean = false

  aboutToAppear(): void { this.load() }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.records = await repositoryFactory.hm5Member().locationHistory()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '位置历史加载失败'
    } finally {
      this.loading = false
    }
  }

  private async clear(): Promise<void> {
    this.error = ''
    try {
      await repositoryFactory.hm5Member().clearLocationHistory()
      this.confirmingClear = false
      await this.load()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '位置历史清除失败'
    }
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Button('‹').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('位置历史').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
        if (this.records.length > 0) {
          Button(this.confirmingClear ? '确认清除' : '清除').height(40).fontSize(12)
            .backgroundColor(AppTheme.dangerSurface).fontColor(AppTheme.dangerText)
            .borderRadius(6).onClick(() => this.confirmingClear ? this.clear() : this.confirmingClear = true)
        }
      }.width('100%')
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8).margin({ top: 12 })
      }
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.records.length === 0) {
        Text('当前没有本人位置历史').width('100%').padding(24)
          .textAlign(TextAlign.Center).fontColor(AppTheme.muted)
          .backgroundColor(AppTheme.surface).borderRadius(8).margin({ top: 14 })
      } else {
        List({ space: 8 }) {
          ForEach(this.records, (record: MemberLocationRecord) => {
            ListItem() {
              Column({ space: 5 }) {
                Text(record.place).fontSize(16).fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.text).width('100%')
                Text(`精度约 ${record.accuracyMeters} 米`).fontSize(12)
                  .fontColor(AppTheme.textSoft).width('100%')
                Text(record.recordedAt).fontSize(12).fontColor(AppTheme.muted).width('100%')
              }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            }
          }, (record: MemberLocationRecord): string => String(record.id))
        }.width('100%').layoutWeight(1).margin({ top: 14 })
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
