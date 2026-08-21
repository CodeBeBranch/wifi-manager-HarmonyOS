import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { TenantCreateInput } from '../model/Hm2Models'
import { replaceMainRoot, resetToMain } from '../navigation/AppRouter'
import { platformAdminRepositoryFactory } from '../repository/PlatformAdminRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'
import { isPlatformWorkspace } from '../ui/MainNavigation'

@Entry
@Component
struct PlatformTenantCreatePage {
  @State tenantCode: string = ''
  @State name: string = ''
  @State timezone: string = 'Asia/Shanghai'
  @State ownerUsername: string = ''
  @State submitting: boolean = false
  @State errorMessage: string = ''

  private hasPlatformAccess(): boolean {
    return isPlatformWorkspace(sessionStore.getSnapshot())
  }

  aboutToAppear(): void {
    if (!this.hasPlatformAccess()) {
      resetToMain()
      return
    }
  }

  private async submit(): Promise<void> {
    if (this.submitting) return
    if (!this.hasPlatformAccess()) {
      resetToMain()
      return
    }
    this.submitting = true
    this.errorMessage = ''
    const input: TenantCreateInput = {
      tenantCode: this.tenantCode,
      name: this.name,
      timezone: this.timezone,
      ownerUsername: this.ownerUsername
    }
    try {
      await platformAdminRepositoryFactory.current().createTenant(input)
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '组织创建失败'
      this.submitting = false
      return
    }
    try {
      await replaceMainRoot('platform/tenants')
    } catch (_) {
      this.errorMessage = '组织已创建，但返回列表失败，请使用左上角返回'
    } finally {
      this.submitting = false
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
        .height(42)
        .backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.border })
        .onClick(() => router.back())
        Column({ space: 3 }) {
          Text('组织').fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.primary)
          Text('创建组织').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 14 })

      Scroll() {
        Column() {
          this.fieldLabel('组织标识')
          TextInput({ text: this.tenantCode, placeholder: '例如 branch-office' })
            .width('100%')
            .height(48)
            .fontSize(14)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.borderStrong })
            .borderRadius(8)
            .maxLength(32)
            .onChange((value: string) => this.tenantCode = value)

          this.fieldLabel('组织名称')
          TextInput({ text: this.name, placeholder: '输入对外显示名称' })
            .width('100%')
            .height(48)
            .fontSize(14)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.borderStrong })
            .borderRadius(8)
            .maxLength(64)
            .onChange((value: string) => this.name = value)

          this.fieldLabel('负责人账号')
          TextInput({ text: this.ownerUsername, placeholder: '输入已有正常账号' })
            .width('100%')
            .height(48)
            .fontSize(14)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.borderStrong })
            .borderRadius(8)
            .maxLength(64)
            .onChange((value: string) => this.ownerUsername = value)

          this.fieldLabel('时区')
          TextInput({ text: this.timezone, placeholder: 'Asia/Shanghai' })
            .width('100%')
            .height(48)
            .fontSize(14)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.borderStrong })
            .borderRadius(8)
            .maxLength(48)
            .onChange((value: string) => this.timezone = value)

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(13)
              .fontColor(AppTheme.dangerText)
              .width('100%')
              .padding(12)
              .backgroundColor(AppTheme.dangerSurface)
              .borderRadius(8)
              .margin({ top: 16 })
          }

          Button(this.submitting ? '正在创建' : '创建组织')
            .enabled(!this.submitting)
            .width('100%')
            .height(50)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primaryText)
            .backgroundColor(AppTheme.primaryStrong)
            .borderRadius(8)
            .margin({ top: 24 })
            .onClick(() => this.submit())
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
  private fieldLabel(label: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppTheme.textSoft)
      .width('100%')
      .margin({ top: 16, bottom: 8 })
  }
}
