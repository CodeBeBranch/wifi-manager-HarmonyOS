import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberRefund } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface RefundDetailParams { id: string }

@Entry
@Component
struct MemberRefundDetailPage {
  @State refund: MemberRefund | null = null
  @State loading: boolean = true
  @State error: string = ''

  aboutToAppear(): void { this.load() }

  private async load(): Promise<void> {
    const params = router.getParams() as RefundDetailParams | null
    this.loading = true
    this.error = ''
    try {
      this.refund = await repositoryFactory.hm5Member().refundDetail(params?.id ?? '')
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '退款详情加载失败'
    } finally {
      this.loading = false
    }
  }

  private statusLabel(status: string): string {
    if (status === 'PENDING') return '待审核'
    if (status === 'APPROVED') return '已通过'
    return '已拒绝'
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('退款详情').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
      }.width('100%')
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.refund === null) {
        Text(this.error.length > 0 ? this.error : '退款申请不存在').width('100%').padding(14)
          .fontColor(AppTheme.dangerText).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      } else {
        Column({ space: 12 }) {
          Text(this.refund.productName).fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.text).width('100%')
          this.row('状态', this.statusLabel(this.refund.status))
          this.row('金额', `¥${this.refund.amount.toFixed(2)}`)
          this.row('申请原因', this.refund.reason)
          this.row('申请时间', this.refund.createdAt)
          this.row('refund requestId', this.refund.refundRequestId)
          if (this.refund.reviewNote.length > 0) {
            this.row('审核说明', this.refund.reviewNote)
          }
        }.width('100%').padding(16).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
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
