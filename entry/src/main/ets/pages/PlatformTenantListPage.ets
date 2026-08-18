import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { resetToLogin, resetToMain } from '../navigation/AppRouter'
import { PlatformTenant } from '../model/TenantModels'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Component
export struct PlatformTenantListContent {
  @Prop embedded: boolean = false
  @State tenants: PlatformTenant[] = []
  @State keyword: string = ''
  @State appliedKeyword: string = ''
  @State selectedTenantId: string = ''
  @State reason: string = ''
  @State current: number = 0
  @State pageSize: number = 20
  @State total: number = 0
  @State loading: boolean = false
  @State switching: boolean = false
  @State errorMessage: string = ''

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    if (!snapshot.authenticated || snapshot.role !== 0 ||
      snapshot.context?.contextType !== 'PLATFORM') {
      resetToMain()
      return
    }
    this.loadTenants(true)
  }

  private async loadTenants(reset: boolean): Promise<void> {
    if (this.loading || this.switching) return
    const page = reset ? 1 : this.current + 1
    this.loading = true
    this.errorMessage = ''
    try {
      const result = await repositoryFactory.tenant().listPlatformTenants(
        page,
        this.pageSize,
        this.appliedKeyword
      )
      this.tenants = reset ? result.records : this.tenants.concat(result.records)
      this.current = Number(result.current)
      this.pageSize = Number(result.size)
      this.total = Number(result.total)
      if (!this.tenants.some((tenant: PlatformTenant) => tenant.tenantId === this.selectedTenantId)) {
        this.selectedTenantId = ''
        this.reason = ''
      }
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        resetToLogin()
        return
      }
      this.errorMessage = error instanceof ApiError ? error.message : '组织列表加载失败，请稍后重试'
    } finally {
      this.loading = false
    }
  }

  private search(): void {
    this.appliedKeyword = this.keyword.trim()
    this.loadTenants(true)
  }

  private hasMore(): boolean {
    return this.tenants.length < this.total
  }

  private selectTenant(tenant: PlatformTenant): void {
    if (this.switching || tenant.status !== 'ACTIVE') return
    if (this.selectedTenantId === tenant.tenantId) {
      this.selectedTenantId = ''
      this.reason = ''
      return
    }
    this.selectedTenantId = tenant.tenantId
    this.reason = ''
    this.errorMessage = ''
  }

  private async enterTenant(tenant: PlatformTenant): Promise<void> {
    if (this.switching || tenant.status !== 'ACTIVE') return
    const reason = this.reason.trim()
    if (reason.length === 0) {
      this.errorMessage = '请输入此次管理操作的原因'
      return
    }
    if (reason.length > 255) {
      this.errorMessage = '操作原因不能超过 255 个字符'
      return
    }

    this.switching = true
    this.errorMessage = ''
    try {
      await sessionStore.enterPlatformTenant(tenant.tenantId, reason)
      resetToMain()
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '工作区切换失败，请稍后重试'
    } finally {
      this.switching = false
    }
  }

  private statusLabel(status: string): string {
    return status === 'ACTIVE' ? '可用' : '已停用'
  }

  build() {
    Scroll() {
      Column() {
        Row({ space: 12 }) {
          if (!this.embedded) {
            Button('返回')
              .height(44)
              .fontSize(13)
              .fontColor(AppTheme.textSoft)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong })
              .borderRadius(6)
              .onClick(() => router.back())
          }
          Column({ space: 3 }) {
            Text('系统管理')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.primary)
            Text('选择组织')
              .fontSize(23)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.text)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        Row({ space: 10 }) {
          TextInput({ text: this.keyword, placeholder: '组织名称或标识' })
            .layoutWeight(1)
            .height(46)
            .fontSize(14)
            .fontColor(AppTheme.text)
            .placeholderColor(AppTheme.muted)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.borderStrong })
            .borderRadius(8)
            .onChange((value: string) => this.keyword = value)
            .onSubmit(() => this.search())
          Button('搜索')
            .enabled(!this.loading && !this.switching)
            .width(76)
            .height(46)
            .fontSize(14)
            .fontColor(AppTheme.primaryText)
            .backgroundColor(AppTheme.primaryStrong)
            .borderRadius(8)
            .onClick(() => this.search())
        }
        .width('100%')
        .margin({ top: 22 })

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor(AppTheme.dangerText)
            .width('100%')
            .padding(11)
            .backgroundColor(AppTheme.dangerSurface)
            .border({ width: 1, color: AppTheme.danger })
            .borderRadius(6)
            .margin({ top: 14 })
        }

        if (this.loading && this.tenants.length === 0) {
          Column({ space: 12 }) {
            LoadingProgress().width(34).height(34).color(AppTheme.primary)
            Text('正在加载组织').fontSize(14).fontColor(AppTheme.muted)
          }
          .width('100%')
          .padding({ top: 48, bottom: 48 })
        } else if (this.tenants.length === 0) {
          Text('没有符合条件的组织')
            .fontSize(14)
            .fontColor(AppTheme.muted)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 48, bottom: 48 })
        } else {
          Column({ space: 10 }) {
            ForEach(this.tenants, (tenant: PlatformTenant) => {
              Column() {
                Row({ space: 12 }) {
                  Column({ space: 4 }) {
                    Text(tenant.name || tenant.tenantCode)
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppTheme.text)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(tenant.tenantCode)
                      .fontSize(12)
                      .fontColor(AppTheme.muted)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`${tenant.memberCount} 位成员`)
                      .fontSize(12)
                      .fontColor(AppTheme.textSoft)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Text(this.statusLabel(tenant.status))
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(tenant.status === 'ACTIVE' ? AppTheme.successText : AppTheme.muted)
                }
                .width('100%')
                .onClick(() => this.selectTenant(tenant))

                if (this.selectedTenantId === tenant.tenantId) {
                  Divider()
                    .color(AppTheme.border)
                    .margin({ top: 14, bottom: 14 })
                  Text('管理原因')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.textSoft)
                    .width('100%')
                    .margin({ bottom: 8 })
                  TextArea({ text: this.reason, placeholder: '简要说明为什么需要管理该组织' })
                    .height(96)
                    .fontSize(14)
                    .fontColor(AppTheme.text)
                    .placeholderColor(AppTheme.muted)
                    .backgroundColor(AppTheme.backgroundSoft)
                    .border({ width: 1, color: AppTheme.borderStrong })
                    .borderRadius(6)
                    .maxLength(255)
                    .onChange((value: string) => this.reason = value)
                  Button(this.switching ? '正在进入' : '开始管理')
                    .enabled(!this.switching)
                    .width('100%')
                    .height(48)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.primaryText)
                    .backgroundColor(AppTheme.primaryStrong)
                    .borderRadius(6)
                    .margin({ top: 12 })
                    .onClick(() => this.enterTenant(tenant))
                }
              }
              .width('100%')
              .padding(15)
              .backgroundColor(AppTheme.surface)
              .border({
                width: 1,
                color: this.selectedTenantId === tenant.tenantId ? AppTheme.primary : AppTheme.border
              })
              .borderRadius(8)
              .opacity(tenant.status === 'ACTIVE' ? 1 : 0.6)
            }, (tenant: PlatformTenant) => tenant.tenantId)

            if (this.hasMore()) {
              Button(this.loading ? '正在加载' : '加载更多')
                .enabled(!this.loading && !this.switching)
                .width('100%')
                .height(46)
                .fontSize(14)
                .fontColor(AppTheme.textSoft)
                .backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.borderStrong })
                .borderRadius(8)
                .onClick(() => this.loadTenants(false))
            } else {
              Text(`共 ${this.total} 个组织`)
                .fontSize(12)
                .fontColor(AppTheme.muted)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 10, bottom: 6 })
            }
          }
          .width('100%')
          .margin({ top: 16 })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.embedded ? 14 : 26, bottom: 36 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }
}

@Entry
@Component
struct PlatformTenantListPage {
  build() {
    Column() {
      PlatformTenantListContent({ embedded: false })
    }
    .width('100%')
    .height('100%')
  }
}
