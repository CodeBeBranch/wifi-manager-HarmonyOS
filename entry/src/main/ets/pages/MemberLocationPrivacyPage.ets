import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberLocationPermission } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct MemberLocationPrivacyPage {
  @State permission: MemberLocationPermission | null = null
  @State loading: boolean = true
  @State saving: boolean = false
  @State error: string = ''
  @State message: string = ''

  onPageShow(): void { this.load() }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.permission = await repositoryFactory.hm5Member().locationPermission()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '位置授权状态加载失败'
    } finally {
      this.loading = false
    }
  }

  private async update(granted: boolean): Promise<void> {
    this.saving = true
    this.error = ''
    try {
      this.permission = await repositoryFactory.hm5Member().setLocationPermission(granted)
      this.message = granted ? '位置授权已开启' : '位置授权已撤销'
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '位置授权更新失败'
    } finally {
      this.saving = false
    }
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Button('‹').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('位置隐私').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
      }.width('100%')
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.permission === null) {
        Text(this.error.length > 0 ? this.error : '位置授权状态不可用')
          .width('100%').padding(14).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      } else {
        Column({ space: 12 }) {
          Row() {
            Column({ space: 4 }) {
              Text('本人位置授权').fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
              Text(this.permission.precision).fontSize(12).fontColor(AppTheme.muted)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.permission.granted })
              .enabled(!this.saving).onChange((value: boolean) => this.update(value))
          }.width('100%')
          Text(`更新时间：${this.permission.updatedAt}`)
            .fontSize(12).fontColor(AppTheme.textSoft).width('100%')
        }.width('100%').padding(16).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
        Button('查看位置历史').width('100%').height(46).backgroundColor(AppTheme.surfaceMuted)
          .fontColor(AppTheme.primary).borderRadius(8)
          .onClick(() => router.pushUrl({ url: 'pages/MemberLocationHistoryPage' }))
      }
      if (this.message.length > 0) {
        Text(this.message).width('100%').padding(10).fontColor(AppTheme.successText)
          .backgroundColor(AppTheme.successSurface).borderRadius(8)
      }
      if (this.error.length > 0 && this.permission !== null) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
