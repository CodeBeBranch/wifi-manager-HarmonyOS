import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberEntitlement } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct MemberEntitlementPage {
  @State entitlement: MemberEntitlement | null = null
  @State loading: boolean = true
  @State error: string = ''

  aboutToAppear(): void { this.load() }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.entitlement = await repositoryFactory.hm5Member().entitlement()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '权益加载失败'
    } finally {
      this.loading = false
    }
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('当前权益').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
        Button('刷新').height(44).fontSize(13).backgroundColor(AppTheme.surfaceMuted)
          .fontColor(AppTheme.primary).borderRadius(6).onClick(() => this.load())
      }.width('100%')
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.entitlement === null) {
        Text(this.error.length > 0 ? this.error : '当前权益不可用').width('100%').padding(14)
          .fontColor(AppTheme.dangerText).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      } else {
        Column({ space: 12 }) {
          Text(this.entitlement.name).fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.text).width('100%')
          this.row('状态', this.entitlement.status)
          this.row('计费模式', this.entitlement.mode)
          this.row('剩余流量', `${this.entitlement.remainingGb.toFixed(1)} GB`)
          this.row('有效期至', this.entitlement.expiresAt)
        }.width('100%').padding(16).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
        Row({ space: 10 }) {
          Button('可购产品').layoutWeight(1).height(46).backgroundColor(AppTheme.primaryStrong)
            .fontColor(AppTheme.primaryText).borderRadius(8)
            .onClick(() => router.pushUrl({ url: 'pages/MemberProductListPage' }))
          Button('购买记录').layoutWeight(1).height(46).backgroundColor(AppTheme.surfaceMuted)
            .fontColor(AppTheme.primary).borderRadius(8)
            .onClick(() => router.pushUrl({ url: 'pages/MemberPurchaseListPage' }))
        }.width('100%')
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }

  @Builder
  private row(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor(AppTheme.muted).layoutWeight(1)
      Text(value).fontSize(14).fontColor(AppTheme.text).maxLines(1)
    }.width('100%')
  }
}
