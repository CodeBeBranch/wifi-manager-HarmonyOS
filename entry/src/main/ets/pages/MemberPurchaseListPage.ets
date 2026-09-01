import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberPurchase } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct MemberPurchaseListPage {
  @State records: MemberPurchase[] = []
  @State loading: boolean = true
  @State error: string = ''

  aboutToAppear(): void { this.load() }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.records = await repositoryFactory.hm5Member().purchases()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '购买记录加载失败'
    } finally {
      this.loading = false
    }
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('购买记录').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
        Button('使用流水').height(44).fontSize(12).backgroundColor(AppTheme.surfaceMuted)
          .fontColor(AppTheme.primary).borderRadius(6)
          .onClick(() => router.pushUrl({ url: 'pages/MemberUsageHistoryPage' }))
      }.width('100%')
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8).margin({ top: 12 })
      }
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.records.length === 0) {
        Text('当前没有购买记录').width('100%').padding(24).textAlign(TextAlign.Center)
          .fontColor(AppTheme.muted).backgroundColor(AppTheme.surface)
          .borderRadius(8).margin({ top: 14 })
      } else {
        List({ space: 8 }) {
          ForEach(this.records, (record: MemberPurchase) => {
            ListItem() {
              Column({ space: 5 }) {
                Row() {
                  Text(record.productName).fontSize(16).fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.text).layoutWeight(1)
                  Text(`¥${record.amount.toFixed(2)}`).fontSize(15).fontColor(AppTheme.primary)
                }.width('100%')
                Text(record.purchasedAt).fontSize(12).fontColor(AppTheme.muted).width('100%')
                Text(record.requestId).fontSize(12).fontColor(AppTheme.textSoft).width('100%')
              }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            }
          }, (record: MemberPurchase): string => String(record.id))
        }.width('100%').layoutWeight(1).margin({ top: 14 })
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
