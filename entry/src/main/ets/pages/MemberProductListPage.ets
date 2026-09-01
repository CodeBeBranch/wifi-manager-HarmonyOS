import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberProduct } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct MemberProductListPage {
  @State products: MemberProduct[] = []
  @State keyword: string = ''
  @State loading: boolean = false
  @State error: string = ''

  aboutToAppear(): void { this.load() }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.products = await repositoryFactory.hm5Member().products(this.keyword)
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '产品加载失败'
    } finally {
      this.loading = false
    }
  }

  private buy(product: MemberProduct): void {
    router.pushUrl({
      url: 'pages/MemberOrderCreatePage',
      params: { productId: String(product.id) }
    })
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('可购产品').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
        Button('购买记录').height(44).fontSize(12).backgroundColor(AppTheme.surfaceMuted)
          .fontColor(AppTheme.primary).borderRadius(6)
          .onClick(() => router.pushUrl({ url: 'pages/MemberPurchaseListPage' }))
      }.width('100%')
      Row({ space: 8 }) {
        TextInput({ text: this.keyword, placeholder: '产品名称或模式' }).layoutWeight(1).height(44)
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
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.products.length === 0) {
        Text('当前条件下没有可购产品').width('100%').padding(24)
          .textAlign(TextAlign.Center).fontColor(AppTheme.muted)
          .backgroundColor(AppTheme.surface).borderRadius(8).margin({ top: 14 })
      } else {
        List({ space: 8 }) {
          ForEach(this.products, (product: MemberProduct) => {
            ListItem() {
              Column({ space: 8 }) {
                Row() {
                  Column({ space: 3 }) {
                    Text(product.name).fontSize(16).fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.text)
                    Text(`${product.mode} · ${product.validityDays} 天`)
                      .fontSize(12).fontColor(AppTheme.muted)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text(`¥${product.price.toFixed(2)}`).fontSize(18)
                    .fontWeight(FontWeight.Bold).fontColor(AppTheme.primary)
                }.width('100%')
                Text(product.description).fontSize(13).fontColor(AppTheme.textSoft)
                  .width('100%').maxLines(2)
                Row() {
                  Text(product.quotaGb > 0 ? `${product.quotaGb} GB` : '不限量')
                    .fontSize(12).fontColor(AppTheme.muted).layoutWeight(1)
                  Button('购买').height(44).fontSize(13).backgroundColor(AppTheme.primaryStrong)
                    .fontColor(AppTheme.primaryText).borderRadius(6).onClick(() => this.buy(product))
                }.width('100%')
              }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            }
          }, (product: MemberProduct): string => String(product.id))
        }.width('100%').layoutWeight(1).margin({ top: 14 })
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
