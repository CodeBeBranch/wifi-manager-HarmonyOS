import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { AccountDeleteReview, PlatformReviewDetailParams } from '../model/Hm2Models'
import { resetToMain } from '../navigation/AppRouter'
import { platformAdminRepositoryFactory } from '../repository/PlatformAdminRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct PlatformAccountReviewsPage {
  @State reviews: AccountDeleteReview[] = []
  @State statusFilter: string = 'PENDING'
  @State loading: boolean = false
  @State errorMessage: string = ''
  private requestVersion: number = 0
  private authorized: boolean = false

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    if (!snapshot.authenticated || snapshot.role !== 0 ||
      snapshot.context?.contextType !== 'PLATFORM') {
      resetToMain()
      return
    }
    this.authorized = true
  }

  onPageShow(): void {
    if (!this.authorized) return
    this.load()
  }

  private async load(): Promise<void> {
    const version = ++this.requestVersion
    this.loading = true
    this.errorMessage = ''
    try {
      const result = await platformAdminRepositoryFactory.current().listAccountReviews(
        1,
        50,
        this.statusFilter
      )
      if (version !== this.requestVersion) return
      this.reviews = result.records
    } catch (error) {
      if (version !== this.requestVersion) return
      this.errorMessage = error instanceof ApiError ? error.message : '审核列表加载失败'
    } finally {
      if (version === this.requestVersion) this.loading = false
    }
  }

  private applyStatus(status: string): void {
    if (this.statusFilter === status) return
    this.statusFilter = status
    this.load()
  }

  private openReview(review: AccountDeleteReview): void {
    const params: PlatformReviewDetailParams = {
      reviewId: review.reviewId
    }
    router.pushUrl({
      url: 'pages/PlatformAccountReviewDetailPage',
      params: params
    })
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
        .height(44)
        .backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.border })
        .onClick(() => router.back())
        Column({ space: 3 }) {
          Text('账号治理').fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.primary)
          Text('删除审核').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 12 })

      Row() {
        this.filterButton('待审核', 'PENDING')
        this.filterButton('已通过', 'APPROVED')
        this.filterButton('已驳回', 'REJECTED')
      }
      .width('calc(100% - 32vp)')
      .height(50)
      .padding(3)
      .backgroundColor(AppTheme.surfaceMuted)
      .borderRadius(8)
      .margin({ left: 16, right: 16, bottom: 12 })

      Scroll() {
        Column() {
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(13)
              .fontColor(AppTheme.dangerText)
              .width('100%')
              .padding(12)
              .backgroundColor(AppTheme.dangerSurface)
              .borderRadius(8)
              .onClick(() => this.load())
          } else if (this.loading) {
            LoadingProgress().width(34).height(34).color(AppTheme.primary).margin({ top: 48 })
          } else if (this.reviews.length === 0) {
            Text('当前没有审核记录')
              .fontSize(14)
              .fontColor(AppTheme.muted)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 60, bottom: 60 })
          } else {
            Column({ space: 10 }) {
              ForEach(this.reviews, (review: AccountDeleteReview) => {
                Row({ space: 12 }) {
                  Column({ space: 4 }) {
                    Text(review.nickname || review.username)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.text)
                    Text(`${review.username} · ${review.requestedAt}`)
                      .fontSize(12)
                      .fontColor(AppTheme.muted)
                    Text(review.reason)
                      .fontSize(12)
                      .fontColor(AppTheme.textSoft)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Text(this.statusLabel(review.status))
                    .fontSize(12)
                    .fontColor(review.status === 'PENDING'
                      ? AppTheme.warningText
                      : AppTheme.muted)
                  Text('›').fontSize(21).fontColor(AppTheme.muted)
                }
                .width('100%')
                .height(82)
                .padding({ left: 14, right: 12, top: 12, bottom: 12 })
                .backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border })
                .borderRadius(8)
                .onClick(() => this.openReview(review))
              }, (review: AccountDeleteReview) => review.reviewId)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 28 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private filterButton(label: string, value: string) {
    Button(label)
      .layoutWeight(1)
      .height(44)
      .fontSize(13)
      .fontColor(this.statusFilter === value ? AppTheme.text : AppTheme.muted)
      .backgroundColor(this.statusFilter === value ? AppTheme.surface : Color.Transparent)
      .borderRadius(6)
      .onClick(() => this.applyStatus(value))
  }
}
