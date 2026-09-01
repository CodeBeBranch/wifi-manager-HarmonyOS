import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { TenantGeofenceEvent } from '../model/Hm6Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface GeofenceEventsParams { id: string }

@Entry
@Component
struct TenantGeofenceEventsPage {
  @State events: TenantGeofenceEvent[] = []
  @State geofenceId: number = 0
  @State keyword: string = ''
  @State loading: boolean = true
  @State error: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as GeofenceEventsParams | null
    this.geofenceId = Number(params?.id ?? '0')
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.events = await repositoryFactory.hm6Location()
        .geofenceEvents(this.geofenceId, this.keyword)
    } catch (error) {
      this.events = []
      this.error = error instanceof ApiError ? error.message : '围栏事件加载失败'
    } finally {
      this.loading = false
    }
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Column({ space: 2 }) {
          Text('围栏事件').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
          Text('只读事件记录').fontSize(12).fontColor(AppTheme.muted)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.width('100%')
      Row({ space: 8 }) {
        TextInput({ text: this.keyword, placeholder: '成员、区域或 ENTER/EXIT' })
          .layoutWeight(1).height(44).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
          .onChange((value: string) => this.keyword = value).onSubmit(() => this.load())
        Button('查询').height(44).backgroundColor(AppTheme.primaryStrong)
          .fontColor(AppTheme.primaryText).borderRadius(8).onClick(() => this.load())
      }.width('100%').margin({ top: 14 })
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8).margin({ top: 10 })
      }
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.events.length === 0) {
        Text('当前条件下没有围栏事件').width('100%').padding(24).textAlign(TextAlign.Center)
          .fontColor(AppTheme.muted).backgroundColor(AppTheme.surface).borderRadius(8)
          .margin({ top: 14 })
      } else {
        List({ space: 8 }) {
          ForEach(this.events, (item: TenantGeofenceEvent) => {
            ListItem() {
              Column({ space: 6 }) {
                Row() {
                  Text(item.eventType === 'ENTER' ? '进入围栏' : '离开围栏')
                    .fontSize(15).fontWeight(FontWeight.Medium)
                    .fontColor(item.eventType === 'ENTER'
                      ? AppTheme.successText : AppTheme.warningText).layoutWeight(1)
                  Text(`精度 ${item.accuracyMeters} m`).fontSize(12).fontColor(AppTheme.muted)
                }.width('100%')
                Text(`${item.subjectName} · ${item.zoneName}`).fontSize(13)
                  .fontColor(AppTheme.text).width('100%')
                Text(`${item.geofenceName} · ${item.occurredAt}`).fontSize(12)
                  .fontColor(AppTheme.textSoft).width('100%')
              }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            }
          }, (item: TenantGeofenceEvent): string => String(item.id))
        }.width('100%').layoutWeight(1).margin({ top: 14 })
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
