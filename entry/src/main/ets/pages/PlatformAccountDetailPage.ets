import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { PlatformAccount, PlatformAccountDetailParams } from '../model/Hm2Models'
import { resetToMain } from '../navigation/AppRouter'
import { platformAdminRepositoryFactory } from '../repository/PlatformAdminRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct PlatformAccountDetailPage {
  @State account: PlatformAccount | null = null
  @State deletionReason: string = ''
  @State loading: boolean = false
  @State submitting: boolean = false
  @State message: string = ''
  @State errorMessage: string = ''
  private userId: string = ''

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const params = router.getParams() as PlatformAccountDetailParams
    this.userId = params?.userId ?? ''
    if (!snapshot.authenticated || snapshot.role !== 0 ||
      snapshot.context?.contextType !== 'PLATFORM' || this.userId.length === 0) {
      resetToMain()
      return
    }
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.errorMessage = ''
    try {
      this.account = await platformAdminRepositoryFactory.current().accountDetail(this.userId)
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '账号详情加载失败'
    } finally {
      this.loading = false
    }
  }

  private confirmStatus(): void {
    if (this.account === null || this.submitting) return
    const nextStatus = this.account.status === 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE'
    AlertDialog.show({
      title: nextStatus === 'ACTIVE' ? '恢复账号' : '停用账号',
      message: nextStatus === 'ACTIVE'
        ? '账号恢复后可以再次登录。'
        : '停用会阻止账号继续登录，但不会删除历史记录。',
      primaryButton: {
        value: '取消',
        action: (): void => {}
      },
      secondaryButton: {
        value: nextStatus === 'ACTIVE' ? '恢复' : '停用',
        fontColor: nextStatus === 'ACTIVE' ? AppTheme.primary : AppTheme.dangerText,
        action: (): void => {
          this.updateStatus(nextStatus)
        }
      }
    })
  }

  private async updateStatus(status: string): Promise<void> {
    if (this.submitting) return
    this.submitting = true
    this.message = ''
    this.errorMessage = ''
    try {
      this.account = await platformAdminRepositoryFactory.current().updateAccountStatus(
        this.userId,
        status
      )
      this.message = status === 'ACTIVE' ? '账号已恢复' : '账号已停用'
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '账号状态更新失败'
    } finally {
      this.submitting = false
    }
  }

  private async submitDeletion(): Promise<void> {
    if (this.submitting) return
    this.submitting = true
    this.message = ''
    this.errorMessage = ''
    try {
      await platformAdminRepositoryFactory.current().submitAccountDeletion(
        this.userId,
        this.deletionReason
      )
      this.account = await platformAdminRepositoryFactory.current().accountDetail(this.userId)
      this.deletionReason = ''
      this.message = '删除申请已提交审核'
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '删除申请提交失败'
    } finally {
      this.submitting = false
    }
  }

  private roleLabel(role: string): string {
    if (role === 'SUPER_ADMIN') return '超级管理员'
    if (role === 'TENANT_OWNER') return '组织负责人'
    if (role === 'TENANT_ADMIN') return '组织管理员'
    return '成员'
  }

  private statusLabel(status: string): string {
    if (status === 'ACTIVE') return '正常'
    if (status === 'SUSPENDED') return '已停用'
    return '已删除'
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
          Text('账号治理').fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.primary)
          Text('账号详情').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 14 })

      if (this.loading) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.primary)
          .layoutWeight(1)
      } else {
        Scroll() {
          Column() {
            if (this.account !== null) {
              Column() {
                this.infoRow('账号', this.account?.username ?? '')
                Divider().color(AppTheme.border)
                this.infoRow('昵称', this.account?.nickname ?? '')
                Divider().color(AppTheme.border)
                this.infoRow('邮箱', this.account?.email ?? '')
                Divider().color(AppTheme.border)
                this.infoRow('角色', this.roleLabel(this.account?.role ?? ''))
                Divider().color(AppTheme.border)
                this.infoRow('状态', this.statusLabel(this.account?.status ?? ''))
                Divider().color(AppTheme.border)
                this.infoRow('所属组织', `${this.account?.tenantCount ?? 0} 个`)
                Divider().color(AppTheme.border)
                this.infoRow('最近登录', this.account?.lastLoginAt ?? '')
              }
              .width('100%')
              .padding({ left: 14, right: 14 })
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)

              if (this.account?.status !== 'DELETED') {
                Button(this.account?.status === 'ACTIVE' ? '停用账号' : '恢复账号')
                  .enabled(!this.submitting)
                  .width('100%')
                  .height(48)
                  .fontSize(14)
                  .fontColor(this.account?.status === 'ACTIVE'
                    ? AppTheme.dangerText
                    : AppTheme.primary)
                  .backgroundColor(AppTheme.surface)
                  .border({ width: 1, color: AppTheme.borderStrong })
                  .borderRadius(8)
                  .margin({ top: 16 })
                  .onClick(() => this.confirmStatus())
              }

              if (this.account?.role !== 'SUPER_ADMIN' &&
                this.account?.status !== 'DELETED' &&
                this.account?.deletionState !== 'PENDING') {
                Text('提交删除审核')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.muted)
                  .width('100%')
                  .margin({ top: 24, bottom: 8 })
                TextArea({
                  text: this.deletionReason,
                  placeholder: '说明删除原因，审核通过后才会删除'
                })
                  .width('100%')
                  .height(96)
                  .fontSize(14)
                  .backgroundColor(AppTheme.surface)
                  .border({ width: 1, color: AppTheme.borderStrong })
                  .borderRadius(8)
                  .maxLength(255)
                  .onChange((value: string) => this.deletionReason = value)
                Button(this.submitting ? '正在提交' : '提交审核')
                  .enabled(!this.submitting)
                  .width('100%')
                  .height(48)
                  .fontSize(14)
                  .fontColor(AppTheme.dangerText)
                  .backgroundColor(AppTheme.surface)
                  .border({ width: 1, color: AppTheme.danger })
                  .borderRadius(8)
                  .margin({ top: 12 })
                  .onClick(() => this.submitDeletion())
              } else if (this.account?.deletionState === 'PENDING') {
                Text('该账号已有待处理删除申请')
                  .fontSize(13)
                  .fontColor(AppTheme.warningText)
                  .width('100%')
                  .padding(12)
                  .backgroundColor(AppTheme.warningSurface)
                  .borderRadius(8)
                  .margin({ top: 18 })
              }
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
  private infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor(AppTheme.muted)
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.text)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(48)
  }
}
