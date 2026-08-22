import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface RuleParams { id: string, code: string, name: string, level: string, condition: string }

@Entry
@Component
struct TenantRuleEditorPage {
  @State ruleId: string = ''
  @State code: string = ''
  @State name: string = ''
  @State level: string = '2'
  @State condition: string = ''
  @State saving: boolean = false
  @State error: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as RuleParams | null
    this.ruleId = params?.id ?? ''
    this.code = params?.code ?? ''
    this.name = params?.name ?? ''
    this.level = params?.level ?? '2'
    this.condition = params?.condition ?? ''
  }

  private async save(): Promise<void> {
    this.saving = true
    this.error = ''
    try {
      await repositoryFactory.hm4Security().saveRule({
        code: this.code, name: this.name, level: Number(this.level), condition: this.condition
      }, this.ruleId.length === 0 ? null : Number(this.ruleId))
      router.back()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '规则保存失败'
    } finally {
      this.saving = false
    }
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Button('‹').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text(this.ruleId.length === 0 ? '新建规则' : '编辑规则').fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).layoutWeight(1)
      }.width('100%')
      TextInput({ text: this.code, placeholder: '规则编码，例如 RULE-ACCESS' }).width('100%').height(46)
        .backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.border }).borderRadius(8)
        .onChange((value: string) => this.code = value)
      TextInput({ text: this.name, placeholder: '规则名称' }).width('100%').height(46)
        .backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.border }).borderRadius(8)
        .onChange((value: string) => this.name = value)
      Row({ space: 8 }) {
        Text('告警级别').fontSize(14).fontColor(AppTheme.textSoft).layoutWeight(1)
        Button('低').height(36).backgroundColor(this.level === '1' ? AppTheme.primaryStrong : AppTheme.surfaceMuted)
          .fontColor(this.level === '1' ? AppTheme.primaryText : AppTheme.textSoft).borderRadius(6).onClick(() => this.level = '1')
        Button('中').height(36).backgroundColor(this.level === '2' ? AppTheme.primaryStrong : AppTheme.surfaceMuted)
          .fontColor(this.level === '2' ? AppTheme.primaryText : AppTheme.textSoft).borderRadius(6).onClick(() => this.level = '2')
        Button('高').height(36).backgroundColor(this.level === '3' ? AppTheme.primaryStrong : AppTheme.surfaceMuted)
          .fontColor(this.level === '3' ? AppTheme.primaryText : AppTheme.textSoft).borderRadius(6).onClick(() => this.level = '3')
      }.width('100%')
      TextArea({ text: this.condition, placeholder: '触发条件' }).width('100%').height(120)
        .backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.border }).borderRadius(8)
        .onChange((value: string) => this.condition = value)
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      }
      Button(this.saving ? '保存中' : '确认保存').enabled(!this.saving).width('100%').height(48)
        .fontColor(AppTheme.primaryText).backgroundColor(AppTheme.primaryStrong).borderRadius(8).onClick(() => this.save())
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
