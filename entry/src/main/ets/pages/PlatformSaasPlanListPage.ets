import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { SaasPlan, SaasPlanDetailParams } from '../model/Hm2Models'
import { resetToMain } from '../navigation/AppRouter'
import { platformAdminRepositoryFactory } from '../repository/PlatformAdminRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct PlatformSaasPlanListPage {
  @State plans: SaasPlan[] = []
  @State keyword: string = ''
  @State appliedKeyword: string = ''
  @State statusFilter: string = ''
  @State loading: boolean = false
  @State errorMessage: string = ''
  private requestVersion: number = 0

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    if (!snapshot.authenticated || snapshot.role !== 0 ||
      snapshot.context?.contextType !== 'PLATFORM') {
      resetToMain()
      return
    }
    this.load()
  }

  private async load(): Promise<void> {
    const version = ++this.requestVersion
    this.loading = true
    this.errorMessage = ''
    try {
      const result = await platformAdminRepositoryFactory.current().listSaasPlans(
        1,
        50,
        this.appliedKeyword,
        this.statusFilter
      )
      if (version !== this.requestVersion) return
      this.plans = result.records
    } catch (error) {
      if (version !== this.requestVersion) return
      this.errorMessage = error instanceof ApiError ? error.message : '套餐列表加载失败'
    } finally {
      if (version === this.requestVersion) this.loading = false
    }
  }

  private search(): void {
    this.appliedKeyword = this.keyword.trim()
    this.load()
  }

  private applyStatus(status: string): void {
    if (this.statusFilter === status) return
    this.statusFilter = status
    this.load()
  }

  private openDetail(plan: SaasPlan): void {
    const params: SaasPlanDetailParams = {
      planId: plan.planId
    }
    router.pushUrl({
      url: 'pages/PlatformSaasPlanDetailPage',
      params: params
    })
  }

  private statusLabel(status: string): string {
    return status === 'PUBLISHED' ? '已发布' : '草稿'
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
          Text('平台服务').fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.primary)
          Text('SaaS 套餐').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('+')
          .width(42)
          .height(42)
          .fontSize(22)
          .fontColor(AppTheme.primaryText)
          .backgroundColor(AppTheme.primaryStrong)
          .borderRadius(8)
          .onClick(() => router.pushUrl({ url: 'pages/PlatformSaasPlanEditorPage' }))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 12 })

      Scroll() {
        Column() {
          Row({ space: 10 }) {
            TextInput({ text: this.keyword, placeholder: '套餐名称、编码或版本' })
              .layoutWeight(1)
              .height(46)
              .fontSize(14)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong })
              .borderRadius(8)
              .onChange((value: string) => this.keyword = value)
              .onSubmit(() => this.search())
            Button('搜索')
              .width(72)
              .height(46)
              .fontSize(14)
              .fontColor(AppTheme.primaryText)
              .backgroundColor(AppTheme.primaryStrong)
              .borderRadius(8)
              .onClick(() => this.search())
          }
          .width('100%')

          Row() {
            this.filterButton('全部', '')
            this.filterButton('已发布', 'PUBLISHED')
            this.filterButton('草稿', 'DRAFT')
          }
          .width('100%')
          .height(42)
          .padding(3)
          .backgroundColor(AppTheme.surfaceMuted)
          .borderRadius(8)
          .margin({ top: 12, bottom: 14 })

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
          } else if (this.plans.length === 0) {
            Text('没有符合条件的套餐')
              .fontSize(14)
              .fontColor(AppTheme.muted)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 56, bottom: 56 })
          } else {
            Column({ space: 10 }) {
              ForEach(this.plans, (plan: SaasPlan) => {
                Column({ space: 10 }) {
                  Row() {
                    Column({ space: 4 }) {
                      Text(`${plan.name} ${plan.version}`)
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(AppTheme.text)
                      Text(plan.planCode).fontSize(12).fontColor(AppTheme.muted)
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    Text(this.statusLabel(plan.status))
                      .fontSize(12)
                      .fontColor(plan.status === 'PUBLISHED'
                        ? AppTheme.successText
                        : AppTheme.muted)
                  }
                  .width('100%')
                  Row() {
                    Text(plan.priceLabel)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.primary)
                      .layoutWeight(1)
                    Text(`${plan.deviceLimit} 台设备 · ${plan.memberLimit} 位成员`)
                      .fontSize(12)
                      .fontColor(AppTheme.textSoft)
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(15)
                .backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border })
                .borderRadius(8)
                .onClick(() => this.openDetail(plan))
              }, (plan: SaasPlan) => plan.planId)
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
      .height(36)
      .fontSize(13)
      .fontColor(this.statusFilter === value ? AppTheme.text : AppTheme.muted)
      .backgroundColor(this.statusFilter === value ? AppTheme.surface : Color.Transparent)
      .borderRadius(6)
      .onClick(() => this.applyStatus(value))
  }
}
