import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberRefund } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface TenantRefundParams { id: string }

@Entry
@Component
struct TenantRefundDetailPage {
  @State refund: MemberRefund | null = null
  @State note: string = ''
  @State loading: boolean = true
  @State saving: boolean = false
  @State error: string = ''

  aboutToAppear(): void { this.load() }

  private refundId(): number {
    const params = router.getParams() as TenantRefundParams | null
    return Number(params?.id ?? '0')
  }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.refund = await repositoryFactory.hm5Member().tenantRefundDetail(this.refundId())
      this.note = this.refund.reviewNote
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '退款详情加载失败'
    } finally {
      this.loading = false
    }
  }

  private async review(approved: boolean): Promise<void> {
    this.saving = true
    this.error = ''
    try {
      this.refund = await repositoryFactory.hm5Member()
        .reviewTenantRefund(this.refundId(), approved, this.note)
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '退款审核失败'
    } finally {
      this.saving = false
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
        Text('退款审核详情').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
      }.width('100%')
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.refund === null) {
        Text(this.error.length > 0 ? this.error : '退款申请不存在').width('100%').padding(14)
          .fontColor(AppTheme.dangerText).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      } else {
        Column({ space: 8 }) {
          Text(this.refund.productName).fontSize(19).fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.text).width('100%')
          Text(`¥${this.refund.amount.toFixed(2)} · ${this.statusLabel(this.refund.status)}`)
            .fontSize(14).fontColor(AppTheme.primary).width('100%')
          Text(this.refund.reason).fontSize(13).fontColor(AppTheme.textSoft).width('100%')
          Text(this.refund.refundRequestId).fontSize(12).fontColor(AppTheme.muted).width('100%')
        }.width('100%').padding(16).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
        if (this.refund.status === 'PENDING') {
          TextArea({ text: this.note, placeholder: '审核说明' }).width('100%').height(100)
            .backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.border })
            .borderRadius(8).onChange((value: string) => this.note = value)
          Row({ space: 10 }) {
            Button('拒绝').enabled(!this.saving).layoutWeight(1).height(46)
              .backgroundColor(AppTheme.dangerSurface).fontColor(AppTheme.dangerText)
              .borderRadius(8).onClick(() => this.review(false))
            Button('通过').enabled(!this.saving).layoutWeight(1).height(46)
              .backgroundColor(AppTheme.primaryStrong).fontColor(AppTheme.primaryText)
              .borderRadius(8).onClick(() => this.review(true))
          }.width('100%')
        } else if (this.refund.reviewNote.length > 0) {
          Text(`审核说明：${this.refund.reviewNote}`).width('100%').padding(12)
            .fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surfaceMuted).borderRadius(8)
        }
      }
      if (this.error.length > 0 && this.refund !== null) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
