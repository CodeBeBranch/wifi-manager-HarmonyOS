import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import {
  Hm7ActionResult,
  Hm7PageConfig,
  Hm7Record,
  Hm7RecordInput,
  Hm7RequestContext
} from '../model/Hm7Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface Hm7RouteParams {
  id?: string
}

@Component
export struct Hm7FeaturePage {
  config: Hm7PageConfig = {
    pageId: '', title: '', eyebrow: '', capability: 'SAAS', scope: 'PLATFORM',
    mode: 'LIST', emptyText: '', detailRoute: '', editorRoute: '',
    primaryAction: '', secondaryAction: '', readOnly: true
  }
  @State records: Hm7Record[] = []
  @State record: Hm7Record | null = null
  @State keyword: string = ''
  @State statusFilter: string = ''
  @State titleValue: string = ''
  @State subtitleValue: string = ''
  @State detailValue: string = ''
  @State loading: boolean = true
  @State saving: boolean = false
  @State error: string = ''
  @State notice: string = ''
  @State confirmAction: string = ''
  private recordId: number = 0

  aboutToAppear(): void {
    const params = router.getParams() as Hm7RouteParams
    this.recordId = Number(params?.id ?? '0')
    if (!Number.isFinite(this.recordId)) this.recordId = 0
    this.load()
  }

  private context(): Hm7RequestContext {
    const snapshot = sessionStore.getSnapshot()
    return {
      scope: this.config.scope,
      role: snapshot.role,
      userId: snapshot.userId,
      tenantId: snapshot.context?.tenantId ?? '',
      tenantRole: snapshot.context?.tenantRole ?? '',
      contextType: snapshot.context?.contextType ?? ''
    }
  }

  private writable(): boolean {
    const context = this.context()
    if (this.config.readOnly) return false
    if (context.scope === 'PLATFORM') return context.role === 0
    if (context.scope === 'TENANT') {
      if (this.config.pageId === 'P108') return context.role === 0
      if (this.config.pageId === 'P216') return context.tenantRole === 'TENANT_OWNER'
      return context.role === 1 &&
        (context.tenantRole === 'TENANT_OWNER' || context.tenantRole === 'TENANT_ADMIN')
    }
    return context.role === 2
  }

  private relatedRoute(): string {
    if (this.config.pageId === 'P111') return 'pages/PlatformQuotaPage'
    if (this.config.pageId === 'P113') return 'pages/PlatformMarketplaceOrderListPage'
    if (this.config.pageId === 'P119') return 'pages/PlatformRuntimeJobListPage'
    if (this.config.pageId === 'P213') return 'pages/TenantMemberListPage'
    if (this.config.pageId === 'P214') return 'pages/TenantInvitationListPage'
    if (this.config.pageId === 'P217') return 'pages/TenantQuotaPage'
    if (this.config.pageId === 'P220') return 'pages/TenantMarketplaceOrderListPage'
    if (this.config.pageId === 'P233') return 'pages/TenantOwnerTransferPage'
    if (this.config.pageId === 'P310') return 'pages/MemberMarketplaceOrderListPage'
    return ''
  }

  private relatedLabel(): string {
    if (this.config.pageId === 'P111' || this.config.pageId === 'P217') return '查看配额'
    if (this.config.pageId === 'P113' || this.config.pageId === 'P220' ||
      this.config.pageId === 'P310') return '查看订单'
    if (this.config.pageId === 'P119') return '异常任务'
    if (this.config.pageId === 'P213') return '成员管理'
    if (this.config.pageId === 'P214') return '邀请管理'
    if (this.config.pageId === 'P233') return '所有权转移'
    return '相关页面'
  }

  private editorReturnRoute(): string {
    if (this.config.pageId === 'P116') return 'pages/PlatformAnnouncementListPage'
    if (this.config.pageId === 'P122') return 'pages/PlatformSaasPlanListPage'
    if (this.config.pageId === 'P125') return 'pages/PlatformMarketplaceProductListPage'
    if (this.config.pageId === 'P239') return 'pages/TenantAnnouncementListPage'
    if (this.config.pageId === 'P240') return 'pages/TenantSupportListPage'
    if (this.config.pageId === 'P324') return 'pages/MemberSupportListPage'
    return ''
  }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    this.notice = ''
    try {
      if (this.config.mode === 'LIST') {
        this.records = await repositoryFactory.hm7Capability().list(
          this.context(), this.config.capability, this.keyword, this.statusFilter)
      } else if (this.config.mode === 'DETAIL') {
        this.record = await repositoryFactory.hm7Capability().detail(
          this.context(), this.config.capability, this.recordId)
      } else if (this.recordId > 0 || this.config.capability === 'ORGANIZATION') {
        this.record = await repositoryFactory.hm7Capability().detail(
          this.context(), this.config.capability, this.recordId)
        if (this.config.capability === 'ORGANIZATION') this.recordId = this.record.id
        this.titleValue = this.record.title
        this.subtitleValue = this.record.subtitle
        this.detailValue = this.record.detail
      }
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '页面数据加载失败'
    } finally {
      this.loading = false
    }
  }

  private openDetail(item: Hm7Record): void {
    if (this.config.detailRoute.length === 0) return
    router.pushUrl({ url: this.config.detailRoute, params: { id: String(item.id) } })
  }

  private openEditor(item: Hm7Record | null): void {
    if (this.config.editorRoute.length === 0 || !this.writable()) return
    router.pushUrl({
      url: this.config.editorRoute,
      params: { id: item === null ? '0' : String(item.id) }
    })
  }

  private requestAction(action: string): void {
    if (!this.writable() || action.length === 0) return
    this.confirmAction = action
  }

  private async executeAction(): Promise<void> {
    const action = this.confirmAction
    this.confirmAction = ''
    if (action.length === 0) return
    this.saving = true
    this.error = ''
    try {
      const result = await repositoryFactory.hm7Capability().act(
        this.context(), this.config.capability, this.record?.id ?? this.recordId, action)
      this.record = result.record
      this.notice = `${result.message} · ${result.requestId}`
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '操作失败'
    } finally {
      this.saving = false
    }
  }

  private async save(): Promise<void> {
    if (!this.writable()) return
    this.saving = true
    this.error = ''
    const input: Hm7RecordInput = {
      title: this.titleValue,
      subtitle: this.subtitleValue,
      detail: this.detailValue
    }
    try {
      const result = await repositoryFactory.hm7Capability().save(
        this.context(), this.config.capability, this.recordId, input)
      this.notice = `${result.message} · ${result.requestId}`
      this.record = result.record
      this.recordId = result.record.id
      if (this.editorReturnRoute().length > 0) {
        router.replaceUrl({ url: this.editorReturnRoute() })
      }
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '保存失败'
    } finally {
      this.saving = false
    }
  }

  private statusLabel(value: string): string {
    if (value === 'ACTIVE') return '生效中'
    if (value === 'DRAFT') return '草稿'
    if (value === 'PUBLISHED') return '已发布'
    if (value === 'ON_SALE') return '销售中'
    if (value === 'OFF_SALE') return '已下架'
    if (value === 'FULFILLING') return '履约中'
    if (value === 'PENDING' || value === 'REVIEW') return '待处理'
    if (value === 'MANUAL') return '人工复核'
    if (value === 'FAILED') return '失败'
    if (value === 'RUNNING') return '执行中'
    if (value === 'RECOVERED') return '已恢复'
    if (value === 'RESOLVED') return '已解决'
    if (value === 'UNREAD') return '未读'
    if (value === 'READ') return '已读'
    if (value === 'INVITED') return '已邀请'
    if (value === 'REJECTED') return '已驳回'
    return value
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24)
          .backgroundColor(AppTheme.surfaceRaised).fontColor(AppTheme.textSoft)
          .borderRadius(8).onClick(() => router.back())
        Column({ space: 2 }) {
          Text(this.config.eyebrow).fontSize(11).fontColor(AppTheme.primary)
          Text(this.config.title).fontSize(21).fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.text).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (this.config.mode === 'LIST' && this.config.editorRoute.length > 0 && this.writable()) {
          Button('+').accessibilityText('新建').width(44).height(44).fontSize(24).backgroundColor(AppTheme.primaryStrong)
            .fontColor(AppTheme.primaryText).borderRadius(8).onClick(() => this.openEditor(null))
        } else if (!this.loading) {
          Button('↻').accessibilityText('刷新').width(44).height(44).fontSize(20).backgroundColor(AppTheme.surfaceMuted)
            .fontColor(AppTheme.primary).borderRadius(8).onClick(() => this.load())
        }
      }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 12 })

      if (this.config.mode === 'LIST') {
        this.listBody()
      } else if (this.config.mode === 'DETAIL') {
        this.detailBody()
      } else {
        this.editorBody()
      }
    }.width('100%').height('100%').backgroundColor(AppTheme.background)
  }

  @Builder
  private messages() {
    if (this.error.length > 0) {
      Text(this.error).width('100%').padding(12).fontSize(13)
        .fontColor(AppTheme.dangerText).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
    }
    if (this.notice.length > 0) {
      Text(this.notice).width('100%').padding(12).fontSize(13)
        .fontColor(AppTheme.successText).backgroundColor(AppTheme.successSurface).borderRadius(8)
    }
  }

  @Builder
  private listBody() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        TextInput({ text: this.keyword, placeholder: '名称、编码或状态' })
          .layoutWeight(1).height(44).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
          .onChange((value: string) => this.keyword = value)
          .onSubmit(() => this.load())
        Button('查询').height(44).fontSize(13).backgroundColor(AppTheme.primaryStrong)
          .fontColor(AppTheme.primaryText).borderRadius(8).onClick(() => this.load())
      }.width('100%')
      if (this.relatedRoute().length > 0) {
        Button(this.relatedLabel()).width('100%').height(44)
          .backgroundColor(AppTheme.surface).fontColor(AppTheme.primary)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
          .onClick(() => router.pushUrl({ url: this.relatedRoute() }))
      }
      Row({ space: 8 }) {
        this.filterButton('全部', '')
        this.filterButton('处理中', 'PENDING')
        this.filterButton('已生效', 'ACTIVE')
      }.width('100%').padding(8).backgroundColor(AppTheme.surfaceMuted).borderRadius(8)
      this.messages()
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
      } else if (this.records.length === 0) {
        Text(this.config.emptyText).width('100%').padding({ top: 48, bottom: 48 })
          .textAlign(TextAlign.Center).fontColor(AppTheme.muted)
          .backgroundColor(AppTheme.surface).borderRadius(8)
      } else {
        List({ space: 8 }) {
          ForEach(this.records, (item: Hm7Record) => {
            ListItem() {
              Column({ space: 8 }) {
                Row() {
                  Column({ space: 3 }) {
                    Text(item.title).fontSize(16).fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.text).maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(item.subtitle).fontSize(12).fontColor(AppTheme.muted).maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text(this.statusLabel(item.status)).fontSize(12)
                    .fontColor(item.status === 'FAILED' ? AppTheme.dangerText : AppTheme.primary)
                }.width('100%')
                Text(item.summary).fontSize(13).fontColor(AppTheme.textSoft)
                  .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                Row() {
                  Text(`${item.metricLabel} · ${item.metricValue}`).fontSize(12)
                    .fontColor(AppTheme.muted).layoutWeight(1)
                  Text('查看 ›').fontSize(13).fontColor(AppTheme.primary)
                }.width('100%')
              }.width('100%').padding(14).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
                .onClick(() => this.openDetail(item))
            }
          }, (item: Hm7Record): string => String(item.id))
        }.width('100%').layoutWeight(1)
      }
    }.width('100%').layoutWeight(1).padding({ left: 16, right: 16, bottom: 18 })
  }

  @Builder
  private detailBody() {
    Scroll() {
      Column({ space: 12 }) {
        this.messages()
        if (this.loading) {
          LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
        } else if (this.record === null) {
          Text(this.config.emptyText).width('100%').padding(32)
            .textAlign(TextAlign.Center).fontColor(AppTheme.muted)
        } else {
          Column({ space: 10 }) {
            Row() {
              Text(this.record.title).fontSize(19).fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.text).layoutWeight(1)
              Text(this.statusLabel(this.record.status)).fontSize(12).fontColor(AppTheme.primary)
            }.width('100%')
            Text(this.record.subtitle).fontSize(13).fontColor(AppTheme.muted).width('100%')
            Divider().color(AppTheme.border)
            Text(this.record.summary).fontSize(15).fontColor(AppTheme.text).width('100%')
            Text(this.record.detail).fontSize(14).fontColor(AppTheme.textSoft)
              .lineHeight(22).width('100%')
            Row() {
              Text(this.record.metricLabel).fontSize(12).fontColor(AppTheme.muted)
              Text(this.record.metricValue).fontSize(15).fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.text).layoutWeight(1).textAlign(TextAlign.End)
            }.width('100%').padding({ top: 8 })
            Text(`更新时间 ${this.record.updatedAt}`).fontSize(11)
              .fontColor(AppTheme.muted).width('100%')
          }.width('100%').padding(16).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(8)

          if (this.config.readOnly || !this.writable()) {
            Text(this.config.readOnly ? '此页面为只读记录' : '当前工作区仅可查看')
              .width('100%').padding(12).fontSize(13).fontColor(AppTheme.muted)
              .backgroundColor(AppTheme.surfaceMuted).borderRadius(8)
            if (this.relatedRoute().length > 0) {
              Button(this.relatedLabel()).width('100%').height(44)
                .backgroundColor(AppTheme.surface).fontColor(AppTheme.primary)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
                .onClick(() => router.pushUrl({ url: this.relatedRoute() }))
            }
          } else {
            if (this.config.editorRoute.length > 0) {
              Button('编辑').width('100%').height(46).backgroundColor(AppTheme.surface)
                .fontColor(AppTheme.primary).border({ width: 1, color: AppTheme.primary })
                .borderRadius(8).onClick(() => this.openEditor(this.record))
            }
            if (this.config.primaryAction.length > 0) {
              Button(this.saving ? '处理中' : this.config.primaryAction)
                .enabled(!this.saving).width('100%').height(48)
                .backgroundColor(AppTheme.primaryStrong).fontColor(AppTheme.primaryText)
                .borderRadius(8).onClick(() => this.requestAction(this.config.primaryAction))
            }
            if (this.config.secondaryAction.length > 0) {
              Button(this.config.secondaryAction).enabled(!this.saving).width('100%').height(46)
                .backgroundColor(AppTheme.surface).fontColor(AppTheme.dangerText)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
                .onClick(() => this.requestAction(this.config.secondaryAction))
            }
          }
        }
      }.width('100%').padding({ left: 16, right: 16, bottom: 24 })
    }.width('100%').layoutWeight(1)

    if (this.confirmAction.length > 0) {
      Column({ space: 12 }) {
        Text(`确认${this.confirmAction}？`).fontSize(17).fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text).width('100%')
        Text('此操作会更新本地演示状态并生成独立 requestId。')
          .fontSize(13).fontColor(AppTheme.muted).width('100%')
        Row({ space: 8 }) {
          Button('取消').layoutWeight(1).height(44).backgroundColor(AppTheme.surfaceMuted)
            .fontColor(AppTheme.textSoft).borderRadius(8).onClick(() => this.confirmAction = '')
          Button('确认').layoutWeight(1).height(44).backgroundColor(AppTheme.primaryStrong)
            .fontColor(AppTheme.primaryText).borderRadius(8).onClick(() => this.executeAction())
        }.width('100%')
      }.width('100%').padding(16).backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.borderStrong })
    }
  }

  @Builder
  private editorBody() {
    Scroll() {
      Column({ space: 14 }) {
        this.messages()
        if (this.loading) {
          LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 32 })
        } else if (!this.writable()) {
          Column({ space: 8 }) {
            Text('当前工作区仅可查看').fontSize(13).fontColor(AppTheme.muted).width('100%')
            Text(this.record?.title ?? this.config.title).fontSize(18)
              .fontWeight(FontWeight.Bold).fontColor(AppTheme.text).width('100%')
            Text(this.record?.detail ?? '当前记录暂不可用').fontSize(14)
              .fontColor(AppTheme.textSoft).width('100%')
          }.width('100%').padding(16).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(8)
          if (this.relatedRoute().length > 0) {
            Button(this.relatedLabel()).width('100%').height(44)
              .backgroundColor(AppTheme.surface).fontColor(AppTheme.primary)
              .border({ width: 1, color: AppTheme.border }).borderRadius(8)
              .onClick(() => router.pushUrl({ url: this.relatedRoute() }))
          }
        } else {
          if (this.relatedRoute().length > 0) {
            Button(this.relatedLabel()).width('100%').height(44)
              .backgroundColor(AppTheme.surface).fontColor(AppTheme.primary)
              .border({ width: 1, color: AppTheme.border }).borderRadius(8)
              .onClick(() => router.pushUrl({ url: this.relatedRoute() }))
          }
          Text('标题').fontSize(13).fontColor(AppTheme.textSoft).width('100%')
          TextInput({ text: this.titleValue, placeholder: '输入标题' }).width('100%').height(46)
            .backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.border })
            .borderRadius(8).onChange((value: string) => this.titleValue = value)
          Text('摘要').fontSize(13).fontColor(AppTheme.textSoft).width('100%')
          TextInput({ text: this.subtitleValue, placeholder: '输入摘要或编码' })
            .width('100%').height(46).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            .onChange((value: string) => this.subtitleValue = value)
          Text('详细内容').fontSize(13).fontColor(AppTheme.textSoft).width('100%')
          TextArea({ text: this.detailValue, placeholder: '输入详细内容' })
            .width('100%').height(150).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            .onChange((value: string) => this.detailValue = value)
          Column({ space: 5 }) {
            Text('预览').fontSize(12).fontColor(AppTheme.primary).width('100%')
            Text(this.titleValue.length > 0 ? this.titleValue : '未填写标题')
              .fontSize(17).fontWeight(FontWeight.Bold).fontColor(AppTheme.text).width('100%')
            Text(this.detailValue.length > 0 ? this.detailValue : '填写内容后将在此处预览')
              .fontSize(13).fontColor(AppTheme.muted).width('100%').maxLines(3)
          }.width('100%').padding(14).backgroundColor(AppTheme.surfaceMuted).borderRadius(8)
          Row({ space: 8 }) {
            Button('取消').layoutWeight(1).height(48).backgroundColor(AppTheme.surface)
              .fontColor(AppTheme.textSoft).border({ width: 1, color: AppTheme.border })
              .borderRadius(8).onClick(() => router.back())
            Button(this.saving ? '保存中' : '保存').enabled(!this.saving)
              .layoutWeight(1).height(48).backgroundColor(AppTheme.primaryStrong)
              .fontColor(AppTheme.primaryText).borderRadius(8).onClick(() => this.save())
          }.width('100%')
        }
      }.width('100%').padding({ left: 16, right: 16, bottom: 24 })
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private filterButton(label: string, value: string) {
    Button(label).layoutWeight(1).height(44).fontSize(12)
      .backgroundColor(this.statusFilter === value ? AppTheme.surface : Color.Transparent)
      .fontColor(this.statusFilter === value ? AppTheme.text : AppTheme.muted)
      .borderRadius(6).onClick(() => {
        this.statusFilter = value
        this.load()
      })
  }
}
