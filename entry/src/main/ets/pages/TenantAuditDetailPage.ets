import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { TenantAuditRecord } from '../model/Hm4Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { AppTheme } from '../ui/AppTheme'

interface AuditDetailParams {
  id?: string
}

@Entry
@Component
struct TenantAuditDetailPage {
  @State record: TenantAuditRecord | null = null
  @State loading: boolean = true
  @State error: string = ''
  private auditId: number = 0
  aboutToAppear(): void {
    const params = router.getParams() as AuditDetailParams | null
    this.auditId = Number(params?.id ?? '0')
    this.load()
  }
  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.record = await repositoryFactory.hm4Security().auditDetail(this.auditId)
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '审计详情加载失败'
    } finally {
      this.loading = false
    }
  }
  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24).backgroundColor(AppTheme.surfaceRaised)
          .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => router.back())
        Text('审计详情').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text).layoutWeight(1)
      }.width('100%')
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.record === null) {
        Text(this.error.length > 0 ? this.error : '审计详情不可用').width('100%').padding(16)
          .fontColor(AppTheme.dangerText).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
      } else {
        Column({ space: 14 }) {
          Text(this.record.action).fontSize(19).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
          this.row('操作对象', this.record.target)
          this.row('操作人', this.record.operator)
          this.row('发生时间', this.record.createTime.replace('T', ' '))
          Text('详情').fontSize(12).fontColor(AppTheme.muted).width('100%')
          Text(this.record.detail).fontSize(14).fontColor(AppTheme.textSoft).width('100%').lineHeight(21)
        }.width('100%').padding(16).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
      }
    }.width('100%').height('100%').padding(16).backgroundColor(AppTheme.background)
  }
  @Builder private row(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor(AppTheme.muted)
      Text(value).fontSize(13).fontColor(AppTheme.textSoft).layoutWeight(1).textAlign(TextAlign.End)
    }.width('100%')
  }
}
