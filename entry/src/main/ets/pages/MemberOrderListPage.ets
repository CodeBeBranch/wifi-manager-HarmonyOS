import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberOrder } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct MemberOrderListPage {
  @State orders: MemberOrder[] = []
  @State loading: boolean = false
  @State error: string = ''
  @State message: string = ''

  onPageShow(): void { this.load() }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.orders = await repositoryFactory.hm5Member().orders()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '订单加载失败'
    } finally {
      this.loading = false
    }
  }

  private statusLabel(order: MemberOrder): string {
    if (order.status === 'PENDING_PAYMENT') return '待支付'
    if (order.status === 'PAID') return '已支付'
    if (order.status === 'CANCELLED') return '已取消'
    if (order.status === 'REFUNDING') return '退款中'
    return '已退款'
  }

  private open(order: MemberOrder): void {
    router.pushUrl({ url: 'pages/MemberOrderDetailPage', params: { id: String(order.id) } })
  }

  private async cancel(order: MemberOrder): Promise<void> {
    this.error = ''
    try {
      await repositoryFactory.hm5Member().cancelOrder(order.id)
      this.message = '订单已取消'
      await this.load()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '订单取消失败'
    }
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Button('‹').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('我的订单').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
        Button('+').width(44).height(44).fontSize(24).backgroundColor(AppTheme.primaryStrong)
          .fontColor(AppTheme.primaryText).borderRadius(8)
          .onClick(() => router.pushUrl({ url: 'pages/MemberOrderCreatePage' }))
      }.width('100%')
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8).margin({ top: 10 })
      }
      if (this.message.length > 0) {
        Text(this.message).width('100%').padding(10).fontColor(AppTheme.successText)
          .backgroundColor(AppTheme.successSurface).borderRadius(8).margin({ top: 10 })
      }
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.orders.length === 0) {
        Text('当前没有订单').width('100%').padding(24).textAlign(TextAlign.Center)
          .fontColor(AppTheme.muted).backgroundColor(AppTheme.surface)
          .borderRadius(8).margin({ top: 14 })
      } else {
        List({ space: 8 }) {
          ForEach(this.orders, (order: MemberOrder) => {
            ListItem() {
              Column({ space: 8 }) {
                Row() {
                  Column({ space: 3 }) {
                    Text(order.productName).fontSize(16).fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.text)
                    Text(this.statusLabel(order)).fontSize(12).fontColor(AppTheme.primary)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text(`¥${order.amount.toFixed(2)}`).fontSize(16)
                    .fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
                }.width('100%')
                Text(order.orderRequestId).fontSize(12).fontColor(AppTheme.textSoft).width('100%')
                Row({ space: 8 }) {
                  Button('详情').layoutWeight(1).height(38).fontSize(12)
                    .backgroundColor(AppTheme.surfaceMuted).fontColor(AppTheme.primary)
                    .borderRadius(6).onClick(() => this.open(order))
                  if (order.status === 'PENDING_PAYMENT') {
                    Button('取消订单').layoutWeight(1).height(38).fontSize(12)
                      .backgroundColor(AppTheme.dangerSurface).fontColor(AppTheme.dangerText)
                      .borderRadius(6).onClick(() => this.cancel(order))
                  }
                }.width('100%')
              }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            }
          }, (order: MemberOrder): string => String(order.id))
        }.width('100%').layoutWeight(1).margin({ top: 14 })
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
