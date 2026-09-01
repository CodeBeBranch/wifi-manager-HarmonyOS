import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import {
  Hm6GisMode,
  TenantCoverageNode,
  TenantGisSnapshot,
  TenantHeatPoint,
  TenantStayPoint,
  TenantTrackPoint
} from '../model/Hm6Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct TenantGisPage {
  @State snapshot: TenantGisSnapshot | null = null
  @State mode: Hm6GisMode = 'TRACK'
  @State loading: boolean = true
  @State error: string = ''

  aboutToAppear(): void { this.load() }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.snapshot = await repositoryFactory.hm6Location().gis()
    } catch (error) {
      this.snapshot = null
      this.error = error instanceof ApiError ? error.message : '地图数据加载失败'
    } finally {
      this.loading = false
    }
  }

  private modeLabel(): string {
    if (this.mode === 'TRACK') return '轨迹'
    if (this.mode === 'STAY') return '停留点'
    if (this.mode === 'HEAT') return '热力'
    return '节点覆盖'
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Button('‹').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('位置地图').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
        Button('刷新').height(40).fontSize(13).backgroundColor(AppTheme.surfaceMuted)
          .fontColor(AppTheme.primary).borderRadius(6).onClick(() => this.load())
      }.width('100%')
      Row({ space: 4 }) {
        this.modeButton('轨迹', 'TRACK')
        this.modeButton('停留', 'STAY')
        this.modeButton('热力', 'HEAT')
        this.modeButton('覆盖', 'COVERAGE')
      }.width('100%').padding(4).backgroundColor(AppTheme.surfaceMuted).borderRadius(8)
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      }
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.snapshot === null) {
        Text('地图暂不可用').width('100%').padding(24).textAlign(TextAlign.Center)
          .fontColor(AppTheme.muted)
      } else if (this.snapshot?.state === 'NO_DATA') {
        this.statePanel('暂无位置数据', '当前场景没有可绘制的轨迹、停留点、热力或节点覆盖。')
      } else if (this.snapshot?.state === 'PERMISSION_DENIED') {
        this.statePanel('位置权限被拒绝', '当前账号或场景没有读取组织位置的权限。')
      } else {
        if (this.snapshot?.state === 'LOW_ACCURACY') {
          Text(`定位精度不足 · 约 ${this.snapshot?.accuracyMeters ?? 0} m`)
            .width('100%').padding(10).fontSize(13).fontColor(AppTheme.warningText)
            .backgroundColor(AppTheme.warningSurface).borderRadius(8)
        }
        Column({ space: 10 }) {
          Row() {
            Text(`${this.modeLabel()}图层`).fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.text).layoutWeight(1)
            Text('本地演示地图').fontSize(12).fontColor(AppTheme.infoText)
          }.width('100%')
          Row({ space: 6 }) {
            ForEach([1, 2, 3, 4, 5], (line: number) => {
              Column().width(1).height(116).backgroundColor(AppTheme.border)
            }, (line: number): string => String(line))
          }.width('100%').height(130).justifyContent(FlexAlign.SpaceEvenly)
            .backgroundColor(AppTheme.surfaceMuted).borderRadius(8)
          if (this.mode === 'TRACK') {
            ForEach(this.snapshot?.track ?? [], (item: TenantTrackPoint) => {
              this.dataRow(`#${item.sequence} ${item.zoneName}`, item.capturedAt)
            }, (item: TenantTrackPoint): string => String(item.id))
          } else if (this.mode === 'STAY') {
            ForEach(this.snapshot?.stays ?? [], (item: TenantStayPoint) => {
              this.dataRow(item.zoneName, `停留 ${item.durationMinutes} 分钟 · ${item.startedAt}`)
            }, (item: TenantStayPoint): string => String(item.id))
          } else if (this.mode === 'HEAT') {
            ForEach(this.snapshot?.heat ?? [], (item: TenantHeatPoint) => {
              this.dataRow(item.zoneName, `热度 ${item.intensity}%`)
            }, (item: TenantHeatPoint): string => String(item.id))
          } else {
            ForEach(this.snapshot?.coverage ?? [], (item: TenantCoverageNode) => {
              this.dataRow(item.nodeName, `${item.zoneName} · ${item.clientCount} 终端 · ${item.averageRssi} dBm`)
            }, (item: TenantCoverageNode): string => String(item.id))
          }
        }.width('100%').padding(14).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }

  @Builder
  private modeButton(label: string, mode: Hm6GisMode) {
    Button(label).layoutWeight(1).height(38).fontSize(12)
      .backgroundColor(this.mode === mode ? AppTheme.primaryStrong : AppTheme.surfaceMuted)
      .fontColor(this.mode === mode ? AppTheme.primaryText : AppTheme.textSoft)
      .borderRadius(6).onClick(() => this.mode = mode)
  }

  @Builder
  private statePanel(title: string, detail: string) {
    Column({ space: 8 }) {
      Text(title).fontSize(18).fontWeight(FontWeight.Medium).fontColor(AppTheme.text).width('100%')
      Text(detail).fontSize(13).fontColor(AppTheme.muted).width('100%')
    }.width('100%').padding(18).backgroundColor(AppTheme.surface)
      .border({ width: 1, color: AppTheme.border }).borderRadius(8)
  }

  @Builder
  private dataRow(title: string, detail: string) {
    Row({ space: 8 }) {
      Text(title).fontSize(13).fontColor(AppTheme.text).layoutWeight(1)
      Text(detail).fontSize(12).fontColor(AppTheme.muted)
    }.width('100%').padding({ top: 5, bottom: 5 })
  }
}
