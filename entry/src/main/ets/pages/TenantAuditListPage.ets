import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { TenantAuditRecord } from '../model/Hm4Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct TenantAuditListPage {
  @State records: TenantAuditRecord[] = []
  @State keyword: string = ''
  @State loading: boolean = false
  @State error: string = ''

  aboutToAppear(): void { this.load() }
  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.records = await repositoryFactory.hm4Security().listAudits(this.keyword)
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '审计记录加载失败'
    } finally {
      this.loading = false
    }
  }
  private openDetail(record: TenantAuditRecord): void {
    router.pushUrl({ url: 'pages/TenantAuditDetailPage', params: { id: String(record.id) } })
  }
  build() {
    Column() {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('安全审计').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text).layoutWeight(1)
        Button('刷新').height(44).fontSize(13).backgroundColor(AppTheme.surfaceMuted).fontColor(AppTheme.primary)
          .borderRadius(6).onClick(() => this.load())
      }.width('100%')
      Row({ space: 8 }) {
        TextInput({ text: this.keyword, placeholder: '动作或目标' }).layoutWeight(1).height(44)
          .backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.border }).borderRadius(8)
          .onChange((value: string) => this.keyword = value).onSubmit(() => this.load())
        Button('查询').height(44).backgroundColor(AppTheme.primaryStrong).fontColor(AppTheme.primaryText)
          .borderRadius(8).onClick(() => this.load())
      }.width('100%').margin({ top: 14 })
      if (this.error.length > 0) {
        Text(this.error).width('100%').padding(12).fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.dangerSurface).borderRadius(8).margin({ top: 10 })
      }
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.records.length === 0) {
        Text('当前条件下没有审计记录').width('100%').padding(24).textAlign(TextAlign.Center)
          .fontColor(AppTheme.muted).backgroundColor(AppTheme.surface).borderRadius(8).margin({ top: 14 })
      } else {
        List({ space: 8 }) {
          ForEach(this.records, (record: TenantAuditRecord) => {
            ListItem() {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Text(record.action).fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
                  Text(`${record.target}  |  ${record.operator}`).fontSize(12).fontColor(AppTheme.muted)
                  Text(record.createTime.replace('T', ' ')).fontSize(12).fontColor(AppTheme.textSoft)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('›').fontSize(22).fontColor(AppTheme.muted)
              }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            }.onClick(() => this.openDetail(record))
          }, (record: TenantAuditRecord) => String(record.id))
        }.width('100%').layoutWeight(1).margin({ top: 14 })
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
}
