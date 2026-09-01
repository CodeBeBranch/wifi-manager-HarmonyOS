import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { TenantAlertRule } from '../model/Hm4Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface RuleEditorParams {
  id: string
  code: string
  name: string
  level: string
  condition: string
}

@Entry
@Component
struct TenantRuleListPage {
  @State rules: TenantAlertRule[] = []
  @State keyword: string = ''
  @State loading: boolean = false
  @State error: string = ''
  @State message: string = ''
  @State confirmingDelete: number = 0
  private requestVersion: number = 0

  onPageShow(): void {
    this.load()
  }

  private canWrite(): boolean {
    return sessionStore.getSnapshot().context?.authorities.includes('RULE_WRITE') ?? false
  }

  private async load(): Promise<void> {
    if (this.loading) return
    const version = ++this.requestVersion
    this.loading = true
    this.error = ''
    try {
      const rules = await repositoryFactory.hm4Security().listRules(this.keyword)
      if (version !== this.requestVersion) return
      this.rules = rules
    } catch (error) {
      if (version !== this.requestVersion) return
      this.error = error instanceof ApiError ? error.message : '规则加载失败'
    } finally {
      if (version === this.requestVersion) this.loading = false
    }
  }

  private edit(rule: TenantAlertRule | null): void {
    const params: RuleEditorParams = rule === null
      ? { id: '', code: '', name: '', level: '2', condition: '' }
      : {
        id: String(rule.id), code: rule.code, name: rule.name,
        level: String(rule.level), condition: rule.condition
      }
    router.pushUrl({ url: 'pages/TenantRuleEditorPage', params: params })
  }

  private async toggle(rule: TenantAlertRule): Promise<void> {
    this.error = ''
    try {
      await repositoryFactory.hm4Security().toggleRule(rule.id)
      this.message = `规则已${rule.enabled ? '停用' : '启用'}`
      await this.load()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '规则状态更新失败'
    }
  }

  private async remove(id: number): Promise<void> {
    this.error = ''
    try {
      await repositoryFactory.hm4Security().deleteRule(id)
      this.confirmingDelete = 0
      this.message = '规则已删除'
      await this.load()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '规则删除失败'
    }
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('告警规则').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text).layoutWeight(1)
        if (this.canWrite()) {
          Button('+').accessibilityText('新建').width(44).height(44).fontSize(24).backgroundColor(AppTheme.primaryStrong)
            .fontColor(AppTheme.primaryText).borderRadius(8).onClick(() => this.edit(null))
        }
      }.width('100%')
      Row({ space: 8 }) {
        TextInput({ text: this.keyword, placeholder: '规则名称或编码' }).layoutWeight(1).height(44)
          .backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.border }).borderRadius(8)
          .onChange((value: string) => this.keyword = value).onSubmit(() => this.load())
        Button('查询').height(44).backgroundColor(AppTheme.primaryStrong).fontColor(AppTheme.primaryText)
          .borderRadius(8).onClick(() => this.load())
      }.width('100%').margin({ top: 14 })
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8).margin({ top: 10 })
      }
      if (this.message.length > 0) {
        Text(this.message).width('100%').padding(10).fontColor(AppTheme.successText)
          .backgroundColor(AppTheme.successSurface).borderRadius(8).margin({ top: 10 })
      }
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.rules.length === 0) {
        Text('当前条件下没有告警规则').width('100%').padding(24).textAlign(TextAlign.Center)
          .fontColor(AppTheme.muted).backgroundColor(AppTheme.surface).borderRadius(8).margin({ top: 14 })
      } else {
        List({ space: 8 }) {
          ForEach(this.rules, (rule: TenantAlertRule) => {
            ListItem() {
              Column({ space: 8 }) {
                Row() {
                  Column({ space: 3 }) {
                    Text(rule.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
                    Text(`${rule.code}  |  ${rule.enabled ? '已启用' : '已停用'}`)
                      .fontSize(12).fontColor(AppTheme.muted)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  if (this.canWrite()) {
                    Button('编辑').height(44).fontSize(12).backgroundColor(AppTheme.surfaceMuted)
                      .fontColor(AppTheme.primary).borderRadius(6).onClick(() => this.edit(rule))
                  }
                }.width('100%')
                Text(rule.condition).fontSize(13).fontColor(AppTheme.textSoft).width('100%').maxLines(2)
                if (this.canWrite()) {
                  Row({ space: 8 }) {
                    Button(rule.enabled ? '停用' : '启用').layoutWeight(1).height(44).fontSize(12)
                      .backgroundColor(AppTheme.surfaceMuted).fontColor(AppTheme.textSoft).borderRadius(6)
                      .onClick(() => this.toggle(rule))
                    Button(this.confirmingDelete === rule.id ? '确认删除' : '删除').layoutWeight(1).height(44)
                      .fontSize(12).backgroundColor(AppTheme.dangerSurface).fontColor(AppTheme.dangerText).borderRadius(6)
                      .onClick(() => this.confirmingDelete === rule.id
                        ? this.remove(rule.id) : this.confirmingDelete = rule.id)
                  }.width('100%')
                }
              }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            }
          }, (rule: TenantAlertRule) => String(rule.id))
        }.width('100%').layoutWeight(1).margin({ top: 14 })
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
