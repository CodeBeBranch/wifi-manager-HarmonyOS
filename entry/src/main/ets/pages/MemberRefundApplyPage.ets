import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberOrder } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface RefundApplyParams { orderId?: string }

@Entry
@Component
struct MemberRefundApplyPage {
  @State orders: MemberOrder[] = []
  @State selectedOrderId: number = 0
  @State reason: string = ''
  @State loading: boolean = true
  @State saving: boolean = false
  @State error: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as RefundApplyParams | null
    this.selectedOrderId = Number(params?.orderId ?? '0')
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      const orders = await repositoryFactory.hm5Member().orders()
      this.orders = orders.filter((order: MemberOrder): boolean => order.status === 'PAID')
      if (this.selectedOrderId === 0 && this.orders.length > 0) {
        this.selectedOrderId = this.orders[0].id
      }
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '可退款订单加载失败'
    } finally {
      this.loading = false
    }
  }

  private async submit(): Promise<void> {
    this.saving = true
    this.error = ''
    try {
      const refund = await repositoryFactory.hm5Member()
        .applyRefund(this.selectedOrderId, this.reason)
      await router.pushUrl({
        url: 'pages/MemberRefundDetailPage',
        params: { id: String(refund.id) }
      })
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '退款申请提交失败'
    } finally {
      this.saving = false
    }
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('申请退款').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
      }.width('100%')
      Text('选择已支付订单').fontSize(13).fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textSoft).width('100%')
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary)
      } else if (this.orders.length === 0) {
        Text('当前没有可退款的已支付订单').width('100%').padding(18)
          .textAlign(TextAlign.Center).fontColor(AppTheme.muted)
          .backgroundColor(AppTheme.surface).borderRadius(8)
      } else {
        ForEach(this.orders, (order: MemberOrder) => {
          Row() {
            Column({ space: 3 }) {
              Text(order.productName).fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
              Text(`¥${order.amount.toFixed(2)} · ${order.orderRequestId}`)
                .fontSize(12).fontColor(AppTheme.muted)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Button(this.selectedOrderId === order.id ? '已选择' : '选择')
              .height(44).fontSize(12).borderRadius(6)
              .backgroundColor(this.selectedOrderId === order.id
                ? AppTheme.primaryStrong : AppTheme.surfaceMuted)
              .fontColor(this.selectedOrderId === order.id
                ? AppTheme.primaryText : AppTheme.primary)
              .onClick(() => this.selectedOrderId = order.id)
          }.width('100%').padding(14).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(8)
        }, (order: MemberOrder): string => String(order.id))
      }
      TextArea({ text: this.reason, placeholder: '退款原因，4 到 120 个字符' })
        .width('100%').height(120).backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.border }).borderRadius(8)
        .onChange((value: string) => this.reason = value)
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      }
      Button(this.saving ? '提交中' : '提交退款申请')
        .enabled(!this.saving && this.orders.length > 0)
        .width('100%').height(48).backgroundColor(AppTheme.primaryStrong)
        .fontColor(AppTheme.primaryText).borderRadius(8).onClick(() => this.submit())
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
