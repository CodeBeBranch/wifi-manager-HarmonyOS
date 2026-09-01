import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { PlatformTenantDetailParams, PlatformTenantMember } from '../model/Hm2Models'
import { resetToMain } from '../navigation/AppRouter'
import { platformAdminRepositoryFactory } from '../repository/PlatformAdminRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct PlatformTenantMembersPage {
  @State members: PlatformTenantMember[] = []
  @State keyword: string = ''
  @State appliedKeyword: string = ''
  @State loading: boolean = false
  @State errorMessage: string = ''
  private tenantId: string = ''
  private requestVersion: number = 0

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const params = router.getParams() as PlatformTenantDetailParams
    this.tenantId = params?.tenantId ?? ''
    if (!snapshot.authenticated || snapshot.role !== 0 ||
      snapshot.context?.contextType !== 'PLATFORM_TENANT' ||
      snapshot.context.tenantId !== this.tenantId) {
      resetToMain()
      return
    }
    this.load()
  }

  private async load(): Promise<void> {
    const version = ++this.requestVersion
    this.loading = true
    this.errorMessage = ''
    try {
      const result = await platformAdminRepositoryFactory.current().listTenantMembers(
        this.tenantId,
        this.appliedKeyword
      )
      if (version !== this.requestVersion) return
      this.members = result
    } catch (error) {
      if (version !== this.requestVersion) return
      this.errorMessage = error instanceof ApiError ? error.message : '成员列表加载失败'
    } finally {
      if (version === this.requestVersion) this.loading = false
    }
  }

  private search(): void {
    this.appliedKeyword = this.keyword.trim()
    this.load()
  }

  private roleLabel(role: string): string {
    if (role === 'TENANT_OWNER') return '负责人'
    if (role === 'TENANT_ADMIN') return '管理员'
    return '成员'
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
          Text('平台只读').fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.primary)
          Text('组织成员').fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 14 })

      Scroll() {
        Column() {
          Row({ space: 10 }) {
            TextInput({ text: this.keyword, placeholder: '账号、昵称或角色' })
              .layoutWeight(1)
              .height(46)
              .fontSize(14)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong })
              .borderRadius(8)
              .onChange((value: string) => this.keyword = value)
              .onSubmit(() => this.search())
            Button('搜索')
              .width(72)
              .height(46)
              .fontSize(14)
              .fontColor(AppTheme.primaryText)
              .backgroundColor(AppTheme.primaryStrong)
              .borderRadius(8)
              .onClick(() => this.search())
          }
          .width('100%')

          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.lock'))
              .fontSize(17)
              .fontColor([AppTheme.info])
            Text('平台代管仅可查看成员，成员管理由组织负责人执行。')
              .fontSize(12)
              .fontColor(AppTheme.infoText)
              .layoutWeight(1)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(AppTheme.surfaceMuted)
          .borderRadius(8)
          .margin({ top: 12, bottom: 14 })

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(13)
              .fontColor(AppTheme.dangerText)
              .width('100%')
              .padding(12)
              .backgroundColor(AppTheme.dangerSurface)
              .borderRadius(8)
              .onClick(() => this.load())
          } else if (this.loading) {
            LoadingProgress().width(34).height(34).color(AppTheme.primary).margin({ top: 48 })
          } else if (this.members.length === 0) {
            Text('没有符合条件的成员')
              .fontSize(14)
              .fontColor(AppTheme.muted)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 56, bottom: 56 })
          } else {
            Column({ space: 10 }) {
              ForEach(this.members, (member: PlatformTenantMember) => {
                Row({ space: 12 }) {
                  Column({ space: 4 }) {
                    Text(member.nickname || member.username)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.text)
                    Text(`${member.username} · ${member.joinedAt} 加入`)
                      .fontSize(12)
                      .fontColor(AppTheme.muted)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Text(this.roleLabel(member.role))
                    .fontSize(12)
                    .fontColor(AppTheme.textSoft)
                }
                .width('100%')
                .height(70)
                .padding({ left: 14, right: 14 })
                .backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border })
                .borderRadius(8)
              }, (member: PlatformTenantMember) => member.memberId)
            }
            .width('100%')
          }
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
}
