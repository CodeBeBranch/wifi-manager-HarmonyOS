import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { Hm6GeofenceShape, TenantGeofenceInput } from '../model/Hm6Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
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
struct TenantGeofenceEditorPage {
  @State geofenceId: number = 0
  @State code: string = ''
  @State name: string = ''
  @State shape: Hm6GeofenceShape = 'CIRCLE'
  @State latitude: string = '31.2304'
  @State longitude: string = '121.4737'
  @State radius: string = '100'
  @State vertices: string = '4'
  @State saving: boolean = false
  @State error: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as GeofenceEditorParams | null
    this.geofenceId = Number(params?.id ?? '0')
    this.code = params?.code ?? ''
    this.name = params?.name ?? ''
    this.shape = params?.shape === 'POLYGON' ? 'POLYGON' : 'CIRCLE'
    this.latitude = params?.latitude ?? '31.2304'
    this.longitude = params?.longitude ?? '121.4737'
    this.radius = params?.radius ?? '100'
    this.vertices = params?.vertices ?? '4'
  }

  private async save(): Promise<void> {
    if (this.saving) return
    this.saving = true
    this.error = ''
    const input: TenantGeofenceInput = {
      code: this.code, name: this.name, shape: this.shape,
      centerLatitude: Number(this.latitude), centerLongitude: Number(this.longitude),
      radiusMeters: Number(this.radius), vertexCount: Number(this.vertices)
    }
    try {
      await repositoryFactory.hm6Location()
        .saveGeofence(input, this.geofenceId > 0 ? this.geofenceId : null)
      router.back()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '围栏保存失败'
    } finally {
      this.saving = false
    }
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row({ space: 10 }) {
          Button('‹').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
            .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
          Text(this.geofenceId > 0 ? '编辑围栏' : '创建围栏').fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.text).layoutWeight(1)
        }.width('100%')
        TextInput({ text: this.code, placeholder: '围栏编码，例如 GEOFENCE-LAB' })
          .width('100%').height(46).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
          .onChange((value: string) => this.code = value)
        TextInput({ text: this.name, placeholder: '围栏名称' }).width('100%').height(46)
          .backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.border })
          .borderRadius(8).onChange((value: string) => this.name = value)
        Row({ space: 6 }) {
          Button('圆形').layoutWeight(1).height(42)
            .backgroundColor(this.shape === 'CIRCLE' ? AppTheme.primaryStrong : AppTheme.surfaceMuted)
            .fontColor(this.shape === 'CIRCLE' ? AppTheme.primaryText : AppTheme.textSoft)
            .borderRadius(6).onClick(() => this.shape = 'CIRCLE')
          Button('多边形').layoutWeight(1).height(42)
            .backgroundColor(this.shape === 'POLYGON' ? AppTheme.primaryStrong : AppTheme.surfaceMuted)
            .fontColor(this.shape === 'POLYGON' ? AppTheme.primaryText : AppTheme.textSoft)
            .borderRadius(6).onClick(() => this.shape = 'POLYGON')
        }.width('100%')
        TextInput({ text: this.latitude, placeholder: '中心纬度 -90 到 90' })
          .width('100%').height(46).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
          .onChange((value: string) => this.latitude = value)
        TextInput({ text: this.longitude, placeholder: '中心经度 -180 到 180' })
          .width('100%').height(46).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
          .onChange((value: string) => this.longitude = value)
        if (this.shape === 'CIRCLE') {
          TextInput({ text: this.radius, placeholder: '半径 20 到 5000 米' })
            .width('100%').height(46).type(InputType.Number).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            .onChange((value: string) => this.radius = value)
        } else {
          TextInput({ text: this.vertices, placeholder: '顶点数量 3 到 20' })
            .width('100%').height(46).type(InputType.Number).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            .onChange((value: string) => this.vertices = value)
        }
        if (this.error.length > 0) {
          Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
            .backgroundColor(AppTheme.dangerSurface).borderRadius(8)
        }
        Row({ space: 8 }) {
          Button('取消').layoutWeight(1).height(48).backgroundColor(AppTheme.surfaceMuted)
            .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
          Button(this.saving ? '保存中' : '保存围栏').enabled(!this.saving)
            .layoutWeight(1).height(48).backgroundColor(AppTheme.primaryStrong)
            .fontColor(AppTheme.primaryText).borderRadius(8).onClick(() => this.save())
        }.width('100%')
      }.width('100%').padding(16)
    }.width('100%').height('100%').backgroundColor(AppTheme.background)
  }
}
