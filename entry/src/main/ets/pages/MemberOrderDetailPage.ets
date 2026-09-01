import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberOrder } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface OrderDetailParams { id: string }

@Entry
@Component
struct MemberOrderDetailPage {
  @State order: MemberOrder | null = null
  @State loading: boolean = true
  @State error: string = ''

  onPageShow(): void { this.load() }

  private orderId(): number {
    if (this.order !== null) return this.order.id
    const params = router.getParams() as OrderDetailParams | null
    return Number(params?.id ?? '0')
  }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.order = await repositoryFactory.hm5Member().orderDetail(this.orderId())
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '订单详情加载失败'
    } finally {
      this.loading = false
    }
  }

  private async cancel(): Promise<void> {
    try {
      this.order = await repositoryFactory.hm5Member().cancelOrder(this.orderId())
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '订单取消失败'
    }
  }

  private statusLabel(status: string): string {
    if (status === 'PENDING_PAYMENT') return '待支付'
    if (status === 'PAID') return '已支付'
    if (status === 'CANCELLED') return '已取消'
    if (status === 'REFUNDING') return '退款中'
    return '已退款'
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('订单详情').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
      }.width('100%')
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.order === null) {
        Text(this.error.length > 0 ? this.error : '订单不存在').width('100%').padding(14)
          .fontColor(AppTheme.dangerText).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      } else {
        Column({ space: 12 }) {
          Text(this.order.productName).fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.text).width('100%')
          this.row('状态', this.statusLabel(this.order.status))
          this.row('金额', `¥${this.order.amount.toFixed(2)}`)
          this.row('创建时间', this.order.createdAt)
          this.row('order requestId', this.order.orderRequestId)
        }.width('100%').padding(16).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
        if (this.order.status === 'PENDING_PAYMENT') {
          Button('本地演示支付').width('100%').height(48).backgroundColor(AppTheme.primaryStrong)
            .fontColor(AppTheme.primaryText).borderRadius(8)
            .onClick(() => router.pushUrl({
              url: 'pages/MemberPaymentPage', params: { orderId: String(this.order?.id ?? 0) }
            }))
          Button('取消订单').width('100%').height(44).backgroundColor(AppTheme.dangerSurface)
            .fontColor(AppTheme.dangerText).borderRadius(8).onClick(() => this.cancel())
        } else if (this.order.status === 'PAID') {
          Button('申请退款').width('100%').height(48).backgroundColor(AppTheme.primaryStrong)
            .fontColor(AppTheme.primaryText).borderRadius(8)
            .onClick(() => router.pushUrl({
              url: 'pages/MemberRefundApplyPage', params: { orderId: String(this.order?.id ?? 0) }
            }))
        }
      }
      if (this.error.length > 0 && this.order !== null) {
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
