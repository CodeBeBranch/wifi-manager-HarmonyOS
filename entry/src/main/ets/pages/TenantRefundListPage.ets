import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberRefund } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct TenantRefundListPage {
  @State refunds: MemberRefund[] = []
  @State loading: boolean = true
  @State error: string = ''

  onPageShow(): void { this.load() }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.refunds = await repositoryFactory.hm5Member().tenantRefunds()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '组织退款加载失败'
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
    Column() {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('退款审核').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
        Button('刷新').height(44).fontSize(13).backgroundColor(AppTheme.surfaceMuted)
          .fontColor(AppTheme.primary).borderRadius(6).onClick(() => this.load())
      }.width('100%')
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8).margin({ top: 12 })
      }
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.refunds.length === 0) {
        Text('当前组织没有退款申请').width('100%').padding(24)
          .textAlign(TextAlign.Center).fontColor(AppTheme.muted)
          .backgroundColor(AppTheme.surface).borderRadius(8).margin({ top: 14 })
      } else {
        List({ space: 8 }) {
          ForEach(this.refunds, (refund: MemberRefund) => {
            ListItem() {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Text(refund.productName).fontSize(16).fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.text)
                  Text(`${this.statusLabel(refund.status)} · ¥${refund.amount.toFixed(2)}`)
                    .fontSize(12).fontColor(AppTheme.primary)
                  Text(refund.refundRequestId).fontSize(12).fontColor(AppTheme.muted)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('›').fontSize(22).fontColor(AppTheme.muted)
              }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            }.onClick(() => router.pushUrl({
              url: 'pages/TenantRefundDetailPage', params: { id: String(refund.id) }
            }))
          }, (refund: MemberRefund): string => String(refund.id))
        }.width('100%').layoutWeight(1).margin({ top: 14 })
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
