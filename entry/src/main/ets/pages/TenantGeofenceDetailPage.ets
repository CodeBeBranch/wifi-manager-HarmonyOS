import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { TenantGeofence } from '../model/Hm6Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface GeofenceDetailParams { id: string }

@Entry
@Component
struct TenantGeofenceDetailPage {
  @State geofence: TenantGeofence | null = null
  @State loading: boolean = true
  @State error: string = ''

  onPageShow(): void { this.load() }

  private geofenceId(): number {
    if (this.geofence !== null) return this.geofence.id
    const params = router.getParams() as GeofenceDetailParams | null
    return Number(params?.id ?? '0')
  }

  private canWrite(): boolean {
    return sessionStore.getSnapshot().context?.authorities.includes('GEOFENCE_WRITE') ?? false
  }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.geofence = await repositoryFactory.hm6Location().geofenceDetail(this.geofenceId())
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '围栏详情加载失败'
    } finally {
      this.loading = false
    }
  }

  private edit(): void {
    if (this.geofence === null) return
    router.pushUrl({
      url: 'pages/TenantGeofenceEditorPage',
      params: {
        id: String(this.geofence.id), code: this.geofence.code, name: this.geofence.name,
        shape: this.geofence.shape, latitude: String(this.geofence.centerLatitude),
        longitude: String(this.geofence.centerLongitude),
        radius: String(this.geofence.radiusMeters || 100),
        vertices: String(this.geofence.vertexCount || 4)
      }
    })
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Button('‹').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('围栏详情').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
        if (this.canWrite() && this.geofence !== null) {
          Button('编辑').height(40).fontSize(13).backgroundColor(AppTheme.surfaceMuted)
            .fontColor(AppTheme.primary).borderRadius(6).onClick(() => this.edit())
        }
      }.width('100%')
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.geofence === null) {
        Text(this.error.length > 0 ? this.error : '围栏不存在').width('100%').padding(14)
          .fontColor(AppTheme.dangerText).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      } else {
        Column({ space: 11 }) {
          Text(this.geofence.name).fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.text).width('100%')
          this.row('编码', this.geofence.code)
          this.row('状态', this.geofence.enabled ? '已启用' : '已停用')
          this.row('边界类型', this.geofence.shape === 'CIRCLE'
            ? `圆形 · ${this.geofence.radiusMeters} 米`
            : `多边形 · ${this.geofence.vertexCount} 个顶点`)
          this.row('中心点',
            `${this.geofence.centerLatitude.toFixed(4)}, ${this.geofence.centerLongitude.toFixed(4)}`)
          this.row('更新时间', this.geofence.updatedAt)
        }.width('100%').padding(16).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
        Button(`查看围栏事件（${this.geofence.eventCount}）`).width('100%').height(48)
          .backgroundColor(AppTheme.primaryStrong).fontColor(AppTheme.primaryText).borderRadius(8)
          .onClick(() => router.pushUrl({
            url: 'pages/TenantGeofenceEventsPage',
            params: { id: String(this.geofence?.id ?? 0) }
          }))
      }
      if (this.error.length > 0 && this.geofence !== null) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }

  @Builder
  private row(label: string, value: string) {
    Column({ space: 3 }) {
      Text(label).fontSize(12).fontColor(AppTheme.muted).width('100%')
      Text(value).fontSize(14).fontColor(AppTheme.text).width('100%')
    }.width('100%')
  }
}
