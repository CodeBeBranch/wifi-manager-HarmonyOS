import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberOrder, MemberPayment } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface PaymentParams { orderId: string }

@Entry
@Component
struct MemberPaymentPage {
  @State order: MemberOrder | null = null
  @State payment: MemberPayment | null = null
  @State loading: boolean = true
  @State paying: boolean = false
  @State error: string = ''

  aboutToAppear(): void { this.load() }

  private orderId(): string {
    const params = router.getParams() as PaymentParams | null
    return params?.orderId ?? ''
  }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.order = await repositoryFactory.hm5Member().orderDetail(this.orderId())
      this.payment = await repositoryFactory.hm5Member().paymentForOrder(this.orderId())
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '支付信息加载失败'
    } finally {
      this.loading = false
    }
  }

  private async pay(): Promise<void> {
    this.paying = true
    this.error = ''
    try {
      this.payment = await repositoryFactory.hm5Member().createPayment(this.orderId())
      this.order = await repositoryFactory.hm5Member().orderDetail(this.orderId())
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '支付提交失败'
    } finally {
      this.paying = false
    }
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('订单支付').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
      }.width('100%')
      Text('本地演示').width('100%').padding(10).textAlign(TextAlign.Center)
        .fontSize(13).fontColor(AppTheme.infoText)
        .backgroundColor(AppTheme.surfaceMuted).borderRadius(8)
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.order === null) {
        Text(this.error.length > 0 ? this.error : '订单不可用').width('100%').padding(14)
          .fontColor(AppTheme.dangerText).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      } else {
        Column({ space: 10 }) {
          Text(this.order.productName).fontSize(18).fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.text).width('100%')
          Text(`¥${this.order.amount.toFixed(2)}`).fontSize(28).fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.primary).width('100%')
          Text(this.order.orderRequestId).fontSize(12).fontColor(AppTheme.muted).width('100%')
        }.width('100%').padding(16).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
        if (this.payment === null) {
          Button(this.paying ? '处理中' : '确认本地演示支付').enabled(!this.paying)
            .width('100%').height(48).backgroundColor(AppTheme.primaryStrong)
            .fontColor(AppTheme.primaryText).borderRadius(8).onClick(() => this.pay())
        } else {
          Column({ space: 8 }) {
            Text('支付成功').fontSize(18).fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.successText).width('100%')
            Text(`payment requestId：${this.payment.paymentRequestId}`)
              .fontSize(13).fontColor(AppTheme.textSoft).width('100%')
            Text(this.payment.createdAt).fontSize(12).fontColor(AppTheme.muted).width('100%')
          }.width('100%').padding(14).backgroundColor(AppTheme.successSurface).borderRadius(8)
        }
      }
      if (this.error.length > 0 && this.order !== null) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
