import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberProduct } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface OrderCreateParams { productId?: string }

@Entry
@Component
struct MemberOrderCreatePage {
  @State products: MemberProduct[] = []
  @State selectedProductId: number = 0
  @State loading: boolean = true
  @State saving: boolean = false
  @State error: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as OrderCreateParams | null
    this.selectedProductId = Number(params?.productId ?? '0')
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.products = await repositoryFactory.hm5Member().products('')
      if (this.selectedProductId === 0 && this.products.length > 0) {
        this.selectedProductId = this.products[0].id
      }
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '产品加载失败'
    } finally {
      this.loading = false
    }
  }

  private async create(): Promise<void> {
    if (this.selectedProductId === 0) {
      this.error = '请选择产品'
      return
    }
    this.saving = true
    this.error = ''
    try {
      const order = await repositoryFactory.hm5Member().createOrder(this.selectedProductId)
      await router.pushUrl({
        url: 'pages/MemberOrderDetailPage',
        params: { id: String(order.id) }
      })
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '订单创建失败'
    } finally {
      this.saving = false
    }
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('创建订单').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
      }.width('100%')
      Text('选择产品').fontSize(13).fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textSoft).width('100%')
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 24 })
      } else {
        List({ space: 8 }) {
          ForEach(this.products, (product: MemberProduct) => {
            ListItem() {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Text(product.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
                  Text(`${product.mode} · ¥${product.price.toFixed(2)}`)
                    .fontSize(12).fontColor(AppTheme.muted)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Button(this.selectedProductId === product.id ? '已选择' : '选择')
                  .height(44).fontSize(12).borderRadius(6)
                  .backgroundColor(this.selectedProductId === product.id
                    ? AppTheme.primaryStrong : AppTheme.surfaceMuted)
                  .fontColor(this.selectedProductId === product.id
                    ? AppTheme.primaryText : AppTheme.primary)
                  .onClick(() => this.selectedProductId = product.id)
              }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            }
          }, (product: MemberProduct): string => String(product.id))
        }.width('100%').layoutWeight(1)
      }
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      }
      Button(this.saving ? '创建中' : '确认创建').enabled(!this.saving && !this.loading)
        .width('100%').height(48).backgroundColor(AppTheme.primaryStrong)
        .fontColor(AppTheme.primaryText).borderRadius(8).onClick(() => this.create())
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
