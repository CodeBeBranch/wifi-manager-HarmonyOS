import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { TenantLocation } from '../model/Hm6Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct TenantLocationListPage {
  @State locations: TenantLocation[] = []
  @State keyword: string = ''
  @State loading: boolean = false
  @State error: string = ''

  onPageShow(): void { this.load() }

  private async load(): Promise<void> {
    if (this.loading) return
    this.loading = true
    this.error = ''
    try {
      this.locations = await repositoryFactory.hm6Location().locations(this.keyword)
    } catch (error) {
      this.locations = []
      this.error = error instanceof ApiError ? error.message : '位置列表加载失败'
    } finally {
      this.loading = false
    }
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Button('‹').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('位置列表').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
        Button('地图').height(40).fontSize(13).backgroundColor(AppTheme.surfaceMuted)
          .fontColor(AppTheme.primary).borderRadius(6)
          .onClick(() => router.pushUrl({ url: 'pages/TenantGisPage' }))
      }.width('100%')
      Row({ space: 8 }) {
        TextInput({ text: this.keyword, placeholder: '成员、设备或区域' }).layoutWeight(1).height(44)
          .backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.border })
          .borderRadius(8).onChange((value: string) => this.keyword = value)
          .onSubmit(() => this.load())
        Button('查询').height(44).backgroundColor(AppTheme.primaryStrong)
          .fontColor(AppTheme.primaryText).borderRadius(8).onClick(() => this.load())
      }.width('100%').margin({ top: 14 })
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8).margin({ top: 12 })
      }
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.locations.length === 0) {
        Text('当前条件下没有位置数据').width('100%').padding(24).textAlign(TextAlign.Center)
          .fontColor(AppTheme.muted).backgroundColor(AppTheme.surface).borderRadius(8)
          .margin({ top: 14 })
      } else {
        List({ space: 8 }) {
          ForEach(this.locations, (item: TenantLocation) => {
            ListItem() {
              Column({ space: 7 }) {
                Row() {
                  Column({ space: 3 }) {
                    Text(item.subjectName).fontSize(16).fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.text)
                    Text(`${item.subjectType === 'MEMBER' ? '成员' : '设备'} · ${item.subjectId}`)
                      .fontSize(12).fontColor(AppTheme.muted)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text(`精度 ${item.accuracyMeters} m`).fontSize(12)
                    .fontColor(item.accuracyMeters <= 20 ? AppTheme.successText : AppTheme.warningText)
                }.width('100%')
                Text(item.zoneName).fontSize(14).fontColor(AppTheme.primary).width('100%')
                Text(`${item.latitude.toFixed(4)}, ${item.longitude.toFixed(4)} · ${item.capturedAt}`)
                  .fontSize(12).fontColor(AppTheme.textSoft).width('100%')
              }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            }
          }, (item: TenantLocation): string => String(item.id))
        }.width('100%').layoutWeight(1).margin({ top: 14 })
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
