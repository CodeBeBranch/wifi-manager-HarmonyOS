import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { SaasPlan, SaasPlanDetailParams, SaasPlanInput } from '../model/Hm2Models'
import { resetToMain } from '../navigation/AppRouter'
import { platformAdminRepositoryFactory } from '../repository/PlatformAdminRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct PlatformSaasPlanEditorPage {
  @State planCode: string = ''
  @State name: string = ''
  @State version: string = ''
  @State status: string = 'DRAFT'
  @State priceLabel: string = ''
  @State billingCycle: string = 'MONTHLY'
  @State deviceLimit: string = '10'
  @State memberLimit: string = '20'
  @State features: string = ''
  @State loading: boolean = false
  @State saving: boolean = false
  @State errorMessage: string = ''
  private planId: string = ''

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const params = router.getParams() as SaasPlanDetailParams
    this.planId = params?.planId ?? ''
    if (!snapshot.authenticated || snapshot.role !== 0 ||
      snapshot.context?.contextType !== 'PLATFORM') {
      resetToMain()
      return
    }
    if (this.planId.length > 0) this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.errorMessage = ''
    try {
      const plan = await platformAdminRepositoryFactory.current().saasPlanDetail(this.planId)
      this.applyPlan(plan)
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '套餐加载失败'
    } finally {
      this.loading = false
    }
  }

  private applyPlan(plan: SaasPlan): void {
    this.planCode = plan.planCode
    this.name = plan.name
    this.version = plan.version
    this.status = plan.status
    this.priceLabel = plan.priceLabel
    this.billingCycle = plan.billingCycle
    this.deviceLimit = String(plan.deviceLimit)
    this.memberLimit = String(plan.memberLimit)
    this.features = plan.features.join('，')
  }

  private async save(): Promise<void> {
    if (this.saving) return
    this.saving = true
    this.errorMessage = ''
    const input: SaasPlanInput = {
      planCode: this.planCode,
      name: this.name,
      version: this.version,
      status: this.status,
      priceLabel: this.priceLabel,
      billingCycle: this.billingCycle,
      deviceLimit: Number(this.deviceLimit),
      memberLimit: Number(this.memberLimit),
      features: this.features.split(/[，,]/)
    }
    try {
      const editingExisting = this.planId.length > 0
      const saved = await platformAdminRepositoryFactory.current().saveSaasPlan(this.planId, input)
      if (editingExisting) {
        router.back()
        return
      }
      router.replaceUrl({
        url: 'pages/PlatformSaasPlanDetailPage',
        params: { planId: saved.planId }
      })
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '套餐保存失败'
    } finally {
      this.saving = false
    }
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
          Text('平台服务').fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.primary)
          Text(this.planId.length > 0 ? '编辑 SaaS 套餐' : '新建 SaaS 套餐')
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
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
          Column({ space: 12 }) {
            this.textField('套餐编码', '例如 PRO', this.planCode,
              (value: string): void => { this.planCode = value })
            this.textField('套餐名称', '例如 专业版', this.name,
              (value: string): void => { this.name = value })
            this.textField('版本', '例如 v3.1', this.version,
              (value: string): void => { this.version = value })
            this.textField('价格说明', '例如 ¥699 / 月', this.priceLabel,
              (value: string): void => { this.priceLabel = value })

            Text('发布状态').fontSize(12).fontColor(AppTheme.muted).width('100%')
            Row({ space: 8 }) {
              this.optionButton('草稿', 'DRAFT', this.status,
                (value: string): void => { this.status = value })
              this.optionButton('已发布', 'PUBLISHED', this.status,
                (value: string): void => { this.status = value })
            }.width('100%')

            Text('计费周期').fontSize(12).fontColor(AppTheme.muted).width('100%')
            Row({ space: 8 }) {
              this.optionButton('按月', 'MONTHLY', this.billingCycle,
                (value: string): void => { this.billingCycle = value })
              this.optionButton('按年', 'YEARLY', this.billingCycle,
                (value: string): void => { this.billingCycle = value })
              this.optionButton('定制', 'CUSTOM', this.billingCycle,
                (value: string): void => { this.billingCycle = value })
            }.width('100%')

            Row({ space: 10 }) {
              Column({ space: 6 }) {
                Text('设备上限').fontSize(12).fontColor(AppTheme.muted).width('100%')
                TextInput({ text: this.deviceLimit, placeholder: '10' })
                  .height(46).backgroundColor(AppTheme.surface)
                  .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
                  .onChange((value: string) => this.deviceLimit = value)
              }.layoutWeight(1)
              Column({ space: 6 }) {
                Text('成员上限').fontSize(12).fontColor(AppTheme.muted).width('100%')
                TextInput({ text: this.memberLimit, placeholder: '20' })
                  .height(46).backgroundColor(AppTheme.surface)
                  .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
                  .onChange((value: string) => this.memberLimit = value)
              }.layoutWeight(1)
            }.width('100%')

            Text('功能范围').fontSize(12).fontColor(AppTheme.muted).width('100%')
            TextArea({ text: this.features, placeholder: '使用逗号分隔功能项' })
              .width('100%').height(108).backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
              .onChange((value: string) => this.features = value)

            if (this.errorMessage.length > 0) {
              Text(this.errorMessage).width('100%').padding(12).fontSize(13)
                .fontColor(AppTheme.dangerText).backgroundColor(AppTheme.dangerSurface)
                .borderRadius(8)
            }

            Row({ space: 10 }) {
              Button('取消').layoutWeight(1).height(48)
                .backgroundColor(AppTheme.surface).fontColor(AppTheme.textSoft)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
                .onClick(() => router.back())
              Button(this.saving ? '保存中' : '保存').layoutWeight(1).height(48)
                .enabled(!this.saving).backgroundColor(AppTheme.primaryStrong)
                .fontColor(AppTheme.primaryText).borderRadius(8)
                .onClick(() => this.save())
            }.width('100%')
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
  private textField(label: string, placeholder: string, value: string,
    change: (value: string) => void) {
    Column({ space: 6 }) {
      Text(label).fontSize(12).fontColor(AppTheme.muted).width('100%')
      TextInput({ text: value, placeholder: placeholder })
        .width('100%').height(46).backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
        .onChange(change)
    }.width('100%')
  }

  @Builder
  private optionButton(label: string, value: string, selected: string,
    change: (value: string) => void) {
    Button(label).layoutWeight(1).height(44)
      .fontColor(selected === value ? AppTheme.primaryText : AppTheme.textSoft)
      .backgroundColor(selected === value ? AppTheme.primaryStrong : AppTheme.surface)
      .border({ width: 1, color: selected === value ? AppTheme.primaryStrong : AppTheme.border })
      .borderRadius(8)
      .onClick(() => change(value))
  }
}
