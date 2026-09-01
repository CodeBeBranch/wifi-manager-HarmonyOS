import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { TenantGeofence } from '../model/Hm6Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface GeofenceEditorParams {
  id: string
  code: string
  name: string
  shape: string
  latitude: string
  longitude: string
  radius: string
  vertices: string
}

@Entry
@Component
struct TenantGeofenceListPage {
  @State geofences: TenantGeofence[] = []
  @State keyword: string = ''
  @State loading: boolean = false
  @State error: string = ''
  @State message: string = ''
  @State confirmAction: string = ''

  onPageShow(): void { this.load() }

  private canWrite(): boolean {
    return sessionStore.getSnapshot().context?.authorities.includes('GEOFENCE_WRITE') ?? false
  }

  private async load(): Promise<void> {
    if (this.loading) return
    this.loading = true
    this.error = ''
    try {
      this.geofences = await repositoryFactory.hm6Location().geofences(this.keyword)
    } catch (error) {
      this.geofences = []
      this.error = error instanceof ApiError ? error.message : '围栏列表加载失败'
    } finally {
      this.loading = false
    }
  }

  private edit(item: TenantGeofence | null): void {
    const params: GeofenceEditorParams = item === null
      ? {
        id: '', code: '', name: '', shape: 'CIRCLE', latitude: '31.2304',
        longitude: '121.4737', radius: '100', vertices: '4'
      }
      : {
        id: String(item.id), code: item.code, name: item.name, shape: item.shape,
        latitude: String(item.centerLatitude), longitude: String(item.centerLongitude),
        radius: String(item.radiusMeters || 100), vertices: String(item.vertexCount || 4)
      }
    router.pushUrl({ url: 'pages/TenantGeofenceEditorPage', params: params })
  }

  private async toggle(item: TenantGeofence): Promise<void> {
    const key = `TOGGLE:${item.id}`
    if (this.confirmAction !== key) {
      this.confirmAction = key
      this.message = `请再次确认${item.enabled ? '停用' : '启用'}“${item.name}”`
      return
    }
    try {
      await repositoryFactory.hm6Location().toggleGeofence(item.id)
      this.confirmAction = ''
      this.message = `围栏已${item.enabled ? '停用' : '启用'}`
      await this.load()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '围栏状态更新失败'
    }
  }

  private async remove(item: TenantGeofence): Promise<void> {
    const key = `DELETE:${item.id}`
    if (this.confirmAction !== key) {
      this.confirmAction = key
      this.message = `删除会同时移除本地事件，请再次确认删除“${item.name}”`
      return
    }
    try {
      await repositoryFactory.hm6Location().deleteGeofence(item.id)
      this.confirmAction = ''
      this.message = '围栏已删除'
      await this.load()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '围栏删除失败'
    }
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Button('‹').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('电子围栏').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
        if (this.canWrite()) {
          Button('+').width(44).height(44).fontSize(24).backgroundColor(AppTheme.primaryStrong)
            .fontColor(AppTheme.primaryText).borderRadius(8).onClick(() => this.edit(null))
        }
      }.width('100%')
      Row({ space: 8 }) {
        TextInput({ text: this.keyword, placeholder: '围栏名称或编码' }).layoutWeight(1).height(44)
          .backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.border })
          .borderRadius(8).onChange((value: string) => this.keyword = value)
          .onSubmit(() => this.load())
        Button('查询').height(44).backgroundColor(AppTheme.primaryStrong)
          .fontColor(AppTheme.primaryText).borderRadius(8).onClick(() => this.load())
      }.width('100%').margin({ top: 14 })
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8).margin({ top: 10 })
      }
      if (this.message.length > 0) {
        Text(this.message).width('100%').padding(10).fontColor(AppTheme.infoText)
          .backgroundColor(AppTheme.surfaceMuted).borderRadius(8).margin({ top: 10 })
      }
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.geofences.length === 0) {
        Text('当前条件下没有电子围栏').width('100%').padding(24).textAlign(TextAlign.Center)
          .fontColor(AppTheme.muted).backgroundColor(AppTheme.surface).borderRadius(8)
          .margin({ top: 14 })
      } else {
        List({ space: 8 }) {
          ForEach(this.geofences, (item: TenantGeofence) => {
            ListItem() {
              Column({ space: 9 }) {
                Row() {
                  Column({ space: 3 }) {
                    Text(item.name).fontSize(16).fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.text)
                    Text(`${item.code} · ${item.shape === 'CIRCLE' ? '圆形' : '多边形'}`)
                      .fontSize(12).fontColor(AppTheme.muted)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text(item.enabled ? '已启用' : '已停用').fontSize(12)
                    .fontColor(item.enabled ? AppTheme.successText : AppTheme.muted)
                }.width('100%').onClick(() => router.pushUrl({
                  url: 'pages/TenantGeofenceDetailPage', params: { id: String(item.id) }
                }))
                Text(`${item.eventCount} 条事件 · ${item.updatedAt}`).fontSize(12)
                  .fontColor(AppTheme.textSoft).width('100%')
                if (this.canWrite()) {
                  Row({ space: 6 }) {
                    Button('编辑').layoutWeight(1).height(38).fontSize(12)
                      .backgroundColor(AppTheme.surfaceMuted).fontColor(AppTheme.primary)
                      .borderRadius(6).onClick(() => this.edit(item))
                    Button(this.confirmAction === `TOGGLE:${item.id}`
                      ? `确认${item.enabled ? '停用' : '启用'}`
                      : (item.enabled ? '停用' : '启用')).layoutWeight(1).height(38).fontSize(12)
                      .backgroundColor(AppTheme.warningSurface).fontColor(AppTheme.warningText)
                      .borderRadius(6).onClick(() => this.toggle(item))
                    Button(this.confirmAction === `DELETE:${item.id}` ? '确认删除' : '删除')
                      .layoutWeight(1).height(38).fontSize(12)
                      .backgroundColor(AppTheme.dangerSurface).fontColor(AppTheme.dangerText)
                      .borderRadius(6).onClick(() => this.remove(item))
                  }.width('100%')
                }
              }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            }
          }, (item: TenantGeofence): string => String(item.id))
        }.width('100%').layoutWeight(1).margin({ top: 14 })
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
