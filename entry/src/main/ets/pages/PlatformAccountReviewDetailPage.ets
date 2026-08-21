import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { AccountDeleteReview, PlatformReviewDetailParams } from '../model/Hm2Models'
import { resetToMain } from '../navigation/AppRouter'
import { platformAdminRepositoryFactory } from '../repository/PlatformAdminRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct PlatformAccountReviewDetailPage {
  @State review: AccountDeleteReview | null = null
  @State comment: string = ''
  @State loading: boolean = false
  @State submitting: boolean = false
  @State errorMessage: string = ''
  @State reviewStatus: string = ''
  private reviewId: string = ''

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const params = router.getParams() as PlatformReviewDetailParams
    this.reviewId = params?.reviewId ?? ''
    if (!snapshot.authenticated || snapshot.role !== 0 ||
      snapshot.context?.contextType !== 'PLATFORM' || this.reviewId.length === 0) {
      resetToMain()
      return
    }
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.errorMessage = ''
    try {
      const review = await platformAdminRepositoryFactory.current()
        .accountReviewDetail(this.reviewId)
      this.review = review
      this.reviewStatus = review.status
      this.comment = review.comment
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '审核详情加载失败'
    } finally {
      this.loading = false
    }
  }

  private confirmDecision(approved: boolean): void {
    if (this.review === null || this.review.status !== 'PENDING' || this.submitting) return
    AlertDialog.show({
      title: approved ? '通过删除申请' : '驳回删除申请',
      message: approved
        ? '通过后账号将进入已删除状态，此操作在本地演示中不可重复。'
        : '驳回后账号保留，后续可以重新提交申请。',
      primaryButton: {
        value: '取消',
        action: (): void => {}
      },
      secondaryButton: {
        value: approved ? '确认通过' : '确认驳回',
        fontColor: approved ? AppTheme.dangerText : AppTheme.primary,
        action: (): void => {
          this.decide(approved)
        }
      }
    })
  }

  private async decide(approved: boolean): Promise<void> {
    if (this.submitting) return
    this.submitting = true
    this.errorMessage = ''
    try {
      const review = await platformAdminRepositoryFactory.current().decideAccountReview(
        this.reviewId,
        approved,
        this.comment
      )
      this.review = review
      this.reviewStatus = review.status
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '审核提交失败'
    } finally {
      this.submitting = false
    }
  }

  private statusLabel(status: string): string {
    if (status === 'PENDING') return '待审核'
    if (status === 'APPROVED') return '已通过'
    return '已驳回'
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_backward'))
            .fontSize(20)
            .fontColor([AppTheme.textSoft])
        }
        .width(42)
        .height(42)
        .backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.border })
        .onClick(() => router.back())
        Column({ space: 3 }) {
          Text('删除审核').fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.primary)
          Text('审核详情').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 14 })

      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).layoutWeight(1)
      } else {
        Scroll() {
          Column() {
            if (this.review !== null) {
              Column() {
                this.infoRow('账号', this.review?.username ?? '')
                Divider().color(AppTheme.border)
                this.infoRow('昵称', this.review?.nickname ?? '')
                Divider().color(AppTheme.border)
                this.infoRow('申请时间', this.review?.requestedAt ?? '')
                Divider().color(AppTheme.border)
                this.statusRow()
              }
              .width('100%')
              .padding({ left: 14, right: 14 })
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)

              Text('删除原因')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.muted)
                .width('100%')
                .margin({ top: 22, bottom: 8 })
              Text(this.review?.reason ?? '')
                .fontSize(14)
                .fontColor(AppTheme.text)
                .width('100%')
                .padding(14)
                .backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border })
                .borderRadius(8)

              if (this.review?.status === 'PENDING') {
                Text('审核备注')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.muted)
                  .width('100%')
                  .margin({ top: 22, bottom: 8 })
                TextArea({ text: this.comment, placeholder: '可选，记录审核说明' })
                  .width('100%')
                  .height(96)
                  .fontSize(14)
                  .backgroundColor(AppTheme.surface)
                  .border({ width: 1, color: AppTheme.borderStrong })
                  .borderRadius(8)
                  .maxLength(255)
                  .onChange((value: string) => this.comment = value)

                Row({ space: 10 }) {
                  Button('驳回')
                    .enabled(!this.submitting)
                    .layoutWeight(1)
                    .height(48)
                    .fontSize(14)
                    .fontColor(AppTheme.textSoft)
                    .backgroundColor(AppTheme.surface)
                    .border({ width: 1, color: AppTheme.borderStrong })
                    .borderRadius(8)
                    .onClick(() => this.confirmDecision(false))
                  Button('通过')
                    .enabled(!this.submitting)
                    .layoutWeight(1)
                    .height(48)
                    .fontSize(14)
                    .fontColor(AppTheme.primaryText)
                    .backgroundColor(AppTheme.danger)
                    .borderRadius(8)
                    .onClick(() => this.confirmDecision(true))
                }
                .width('100%')
                .margin({ top: 14 })
              } else {
                Column() {
                  this.infoRow('审核人', this.review?.reviewer ?? '')
                  Divider().color(AppTheme.border)
                  this.infoRow('处理时间', this.review?.reviewedAt ?? '')
                  if ((this.review?.comment ?? '').length > 0) {
                    Divider().color(AppTheme.border)
                    this.infoRow('备注', this.review?.comment ?? '')
                  }
                }
                .width('100%')
                .padding({ left: 14, right: 14 })
                .backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border })
                .borderRadius(8)
                .margin({ top: 18 })
              }
            }

            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontSize(13)
                .fontColor(AppTheme.dangerText)
                .width('100%')
                .padding(12)
                .backgroundColor(AppTheme.dangerSurface)
                .borderRadius(8)
                .margin({ top: 14 })
                .onClick(() => this.load())
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 28 })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private statusRow() {
    Row() {
      Text('状态').fontSize(13).fontColor(AppTheme.muted)
      Text(this.statusLabel(this.reviewStatus))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.text)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(1)
    }
    .width('100%')
    .height(48)
  }

  @Builder
  private infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor(AppTheme.muted)
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.text)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(48)
  }
}
