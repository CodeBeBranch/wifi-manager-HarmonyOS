import router from '@ohos.router'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ApiError } from '../model/ApiModels'
import { PlatformTenantDetailParams, TenantUpdateInput } from '../model/Hm2Models'
import { PlatformTenant } from '../model/TenantModels'
import { replaceMainRoot, resetToMain } from '../navigation/AppRouter'
import { isWorkspaceTransitionActive, leaveManagedTenant } from '../navigation/WorkspaceTransition'
import { platformAdminRepositoryFactory } from '../repository/PlatformAdminRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

const ROUTE_LOG_DOMAIN = 0x0000

@Entry
@Component
struct PlatformTenantDetailPage {
  @State tenant: PlatformTenant | null = null
  @State name: string = ''
  @State timezone: string = ''
  @State loading: boolean = false
  @State saving: boolean = false
  @State leaving: boolean = false
  @State enteringOperations: boolean = false
  @State message: string = ''
  @State errorMessage: string = ''
  private tenantId: string = ''
  private requestVersion: number = 0

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const params = router.getParams() as PlatformTenantDetailParams
    this.tenantId = params?.tenantId ?? snapshot.context?.tenantId ?? ''
    hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route',
      'detail appear context %{public}s leaving %{public}s transition %{public}s',
      snapshot.context?.contextType ?? 'NONE',
      this.leaving ? 'true' : 'false',
      isWorkspaceTransitionActive() ? 'true' : 'false')
    if (!snapshot.authenticated || snapshot.role !== 0 ||
      snapshot.context?.contextType !== 'PLATFORM_TENANT' ||
      snapshot.context.tenantId !== this.tenantId || this.tenantId.length === 0) {
      if (!isWorkspaceTransitionActive()) {
        resetToMain()
      }
      return
    }
    platformAdminRepositoryFactory.current().cacheManagedTenant(this.tenantId)
    this.load()
  }

  private async load(): Promise<void> {
    const version = ++this.requestVersion
    this.loading = true
    this.errorMessage = ''
    try {
      const result = await platformAdminRepositoryFactory.current().tenantDetail(this.tenantId)
      if (version !== this.requestVersion) return
      this.tenant = result
      this.name = result.name
      this.timezone = result.timezone
    } catch (error) {
      if (version !== this.requestVersion) return
      this.errorMessage = error instanceof ApiError ? error.message : '组织详情加载失败'
    } finally {
      if (version === this.requestVersion) this.loading = false
    }
  }

  private async save(): Promise<void> {
    if (this.saving || this.tenant === null) return
    this.saving = true
    this.message = ''
    this.errorMessage = ''
    const input: TenantUpdateInput = {
      name: this.name,
      timezone: this.timezone
    }
    try {
      this.tenant = await platformAdminRepositoryFactory.current().updateTenant(this.tenantId, input)
      this.name = this.tenant.name
      this.timezone = this.tenant.timezone
      this.message = '组织资料已更新'
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '组织资料更新失败'
    } finally {
      this.saving = false
    }
  }

  private confirmStatus(): void {
    if (this.tenant === null || this.saving) return
    const nextStatus = this.tenant.status === 'ACTIVE' ? 'DISABLED' : 'ACTIVE'
    AlertDialog.show({
      title: nextStatus === 'ACTIVE' ? '启用组织' : '停用组织',
      message: nextStatus === 'ACTIVE'
        ? '组织恢复后可再次进入管理。'
        : '停用后不能从平台列表再次进入代管。',
      primaryButton: {
        value: '取消',
        action: (): void => {}
      },
      secondaryButton: {
        value: nextStatus === 'ACTIVE' ? '启用' : '停用',
        fontColor: nextStatus === 'ACTIVE' ? AppTheme.primary : AppTheme.dangerText,
        action: (): void => {
          this.updateStatus(nextStatus)
        }
      }
    })
  }

  private async updateStatus(status: string): Promise<void> {
    if (this.saving) return
    this.saving = true
    this.message = ''
    this.errorMessage = ''
    try {
      this.tenant = await platformAdminRepositoryFactory.current().updateTenantStatus(
        this.tenantId,
        status
      )
      this.message = status === 'ACTIVE' ? '组织已启用' : '组织已停用'
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '组织状态更新失败'
    } finally {
      this.saving = false
    }
  }

  private async returnPlatform(): Promise<void> {
    if (this.leaving) return
    this.leaving = true
    hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route', 'detail leave start')
    this.errorMessage = ''
    try {
      await leaveManagedTenant(this.tenantId)
      hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route', 'detail leave done')
    } catch (error) {
      this.errorMessage = error instanceof Error ? error.message : '返回平台失败'
      this.leaving = false
    }
  }

  private async enterOperations(): Promise<void> {
    if (this.enteringOperations || this.tenant === null || this.tenant.status !== 'ACTIVE') return
    this.enteringOperations = true
    this.errorMessage = ''
    try {
      await replaceMainRoot('tenant/home')
    } catch (error) {
      this.errorMessage = error instanceof Error ? error.message : '进入组织工作台失败'
      this.enteringOperations = false
    }
  }

  private openMembers(): void {
    const params: PlatformTenantDetailParams = {
      tenantId: this.tenantId
    }
    router.pushUrl({
      url: 'pages/PlatformTenantMembersPage',
      params: params
    })
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
        .onClick(() => this.returnPlatform())
        Column({ space: 3 }) {
          Text('平台代管').fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.primary)
          Text('组织详情').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button(this.leaving ? '正在返回' : '返回平台')
          .enabled(!this.leaving)
          .height(40)
          .fontSize(13)
          .fontColor(AppTheme.primary)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.primary })
          .borderRadius(8)
          .onClick(() => this.returnPlatform())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 14 })

      if (this.loading) {
        Column({ space: 12 }) {
          LoadingProgress().width(36).height(36).color(AppTheme.primary)
          Text('正在加载组织').fontSize(14).fontColor(AppTheme.muted)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            if (this.tenant !== null) {
              Row() {
                Column({ space: 4 }) {
                  Text(this.tenant?.name ?? '')
                    .fontSize(19)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.text)
                  Text(this.tenant?.tenantCode ?? '')
                    .fontSize(12)
                    .fontColor(AppTheme.muted)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text(this.tenant?.status === 'ACTIVE' ? '可用' : '已停用')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.tenant?.status === 'ACTIVE'
                    ? AppTheme.successText
                    : AppTheme.dangerText)
              }
              .width('100%')
              .padding(16)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)

              Button(this.enteringOperations ? '正在进入' : '进入组织工作台')
                .enabled(!this.enteringOperations && this.tenant?.status === 'ACTIVE')
                .width('100%')
                .height(48)
                .fontSize(14)
                .fontColor(AppTheme.primaryText)
                .backgroundColor(AppTheme.primaryStrong)
                .borderRadius(8)
                .margin({ top: 14 })
                .onClick(() => this.enterOperations())

              Text('组织资料')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.muted)
                .width('100%')
                .margin({ top: 22, bottom: 8 })
              TextInput({ text: this.name, placeholder: '组织名称' })
                .width('100%')
                .height(48)
                .fontSize(14)
                .backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.borderStrong })
                .borderRadius(8)
                .maxLength(64)
                .onChange((value: string) => this.name = value)
              TextInput({ text: this.timezone, placeholder: '时区' })
                .width('100%')
                .height(48)
                .fontSize(14)
                .backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.borderStrong })
                .borderRadius(8)
                .maxLength(48)
                .margin({ top: 10 })
                .onChange((value: string) => this.timezone = value)
              Button(this.saving ? '正在保存' : '保存资料')
                .enabled(!this.saving)
                .width('100%')
                .height(48)
                .fontSize(14)
                .fontColor(AppTheme.primaryText)
                .backgroundColor(AppTheme.primaryStrong)
                .borderRadius(8)
                .margin({ top: 12 })
                .onClick(() => this.save())

              Text('成员与状态')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.muted)
                .width('100%')
                .margin({ top: 24, bottom: 8 })
              Column() {
                this.linkRow(
                  '成员列表',
                  `${this.tenant?.memberCount ?? 0} 位成员 · 平台只读`,
                  (): void => this.openMembers()
                )
                Divider().color(AppTheme.border)
                this.statusLinkRow()
              }
              .width('100%')
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)
            }

            if (this.message.length > 0) {
              Text(this.message)
                .fontSize(13)
                .fontColor(AppTheme.successText)
                .width('100%')
                .padding(12)
                .backgroundColor(AppTheme.successSurface)
                .borderRadius(8)
                .margin({ top: 14 })
            }
            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontSize(13)
                .fontColor(AppTheme.dangerText)
                .width('100%')
                .padding(12)
                .backgroundColor(AppTheme.dangerSurface)
                .borderRadius(8)
                .margin({ top: 14 })
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
  private linkRow(label: string, description: string, action: () => void) {
    Row() {
      Column({ space: 4 }) {
        Text(label).fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
        Text(description).fontSize(12).fontColor(AppTheme.muted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›').fontSize(21).fontColor(AppTheme.muted)
    }
    .width('100%')
    .height(68)
    .padding({ left: 14, right: 12 })
    .onClick(action)
  }

  @Builder
  private statusLinkRow() {
    Row() {
      Column({ space: 4 }) {
        Text(this.tenant?.status === 'ACTIVE' ? '停用组织' : '启用组织')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.text)
        Text(this.tenant?.status === 'ACTIVE' ? '阻止再次进入代管' : '恢复组织可用状态')
          .fontSize(12)
          .fontColor(AppTheme.muted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›').fontSize(21).fontColor(AppTheme.muted)
    }
    .width('100%')
    .height(68)
    .padding({ left: 14, right: 12 })
    .onClick(() => this.confirmStatus())
  }
}
