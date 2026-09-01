import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { SaasPlan, SaasPlanDetailParams } from '../model/Hm2Models'
import { resetToMain } from '../navigation/AppRouter'
import { platformAdminRepositoryFactory } from '../repository/PlatformAdminRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct PlatformSaasPlanDetailPage {
  @State plan: SaasPlan | null = null
  @State loading: boolean = false
  @State errorMessage: string = ''
  private planId: string = ''

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const params = router.getParams() as SaasPlanDetailParams
    this.planId = params?.planId ?? ''
    if (!snapshot.authenticated || snapshot.role !== 0 ||
      snapshot.context?.contextType !== 'PLATFORM' || this.planId.length === 0) {
      resetToMain()
      return
    }
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.errorMessage = ''
    try {
      this.plan = await platformAdminRepositoryFactory.current().saasPlanDetail(this.planId)
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '套餐详情加载失败'
    } finally {
      this.loading = false
    }
  }

  private cycleLabel(cycle: string): string {
    if (cycle === 'MONTHLY') return '按月'
    if (cycle === 'YEARLY') return '按年'
    return '定制'
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
          Text('只读').fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.primary)
          Text('套餐详情').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
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
            if (this.plan !== null) {
              Row() {
                Column({ space: 5 }) {
                  Text(`${this.plan?.name ?? ''} ${this.plan?.version ?? ''}`)
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.text)
                  Text(this.plan?.planCode ?? '')
                    .fontSize(12)
                    .fontColor(AppTheme.muted)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text(this.plan?.status === 'PUBLISHED' ? '已发布' : '草稿')
                  .fontSize(12)
                  .fontColor(this.plan?.status === 'PUBLISHED'
                    ? AppTheme.successText
                    : AppTheme.muted)
              }
              .width('100%')
              .padding(16)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)

              Text('套餐信息')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.muted)
                .width('100%')
                .margin({ top: 22, bottom: 8 })
              Column() {
                this.infoRow('价格', this.plan?.priceLabel ?? '')
                Divider().color(AppTheme.border)
                this.infoRow('计费周期', this.cycleLabel(this.plan?.billingCycle ?? ''))
                Divider().color(AppTheme.border)
                this.infoRow('设备上限', `${this.plan?.deviceLimit ?? 0} 台`)
                Divider().color(AppTheme.border)
                this.infoRow('成员上限', `${this.plan?.memberLimit ?? 0} 位`)
                Divider().color(AppTheme.border)
                this.infoRow('更新时间', this.plan?.updatedAt ?? '')
              }
              .width('100%')
              .padding({ left: 14, right: 14 })
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)

              Text('功能范围')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.muted)
                .width('100%')
                .margin({ top: 22, bottom: 8 })
              Column() {
                ForEach(this.plan?.features ?? [], (feature: string, index: number) => {
                  Row({ space: 10 }) {
                    Circle().width(7).height(7).fill(AppTheme.success)
                    Text(feature)
                      .fontSize(14)
                      .fontColor(AppTheme.text)
                      .layoutWeight(1)
                  }
                  .width('100%')
                  .height(48)
                  .padding({ left: 14, right: 14 })
                  .border({
                    width: { bottom: index < (this.plan?.features.length ?? 0) - 1 ? 1 : 0 },
                    color: AppTheme.border
                  })
                }, (feature: string) => feature)
              }
              .width('100%')
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)
            }

            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontSize(13)
                .fontColor(AppTheme.dangerText)
                .width('100%')
                .padding(12)
                .backgroundColor(AppTheme.dangerSurface)
                .borderRadius(8)
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
  private infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor(AppTheme.muted)
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.text)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(48)
  }
}
