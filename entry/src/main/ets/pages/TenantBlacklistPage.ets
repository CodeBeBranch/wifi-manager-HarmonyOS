import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { BlacklistEntry } from '../model/Hm3Models'
import { resetToMain } from '../navigation/AppRouter'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct TenantBlacklistPage {
  @State tenantId: string = ''
  @State keyword: string = ''
  @State appliedKeyword: string = ''
  @State mac: string = ''
  @State reason: string = ''
  @State entries: BlacklistEntry[] = []
  @State loading: boolean = false
  @State submitting: boolean = false
  @State errorMessage: string = ''
  @State message: string = ''
  @State writable: boolean = false
  private requestVersion: number = 0

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const context = snapshot.context
    if (!snapshot.authenticated || snapshot.role > 1 ||
      context === null || (context.contextType !== 'TENANT' &&
        context.contextType !== 'PLATFORM_TENANT')) {
      resetToMain()
      return
    }
    this.tenantId = context.tenantId
    this.writable = context.authorities.includes('BLACKLIST_WRITE')
    this.load()
  }

  private async load(): Promise<void> {
    const requestVersion = ++this.requestVersion
    this.loading = true
    this.errorMessage = ''
    try {
      const entries = await repositoryFactory.blacklist().listBlacklist(
        this.tenantId,
        { keyword: this.appliedKeyword }
      )
      if (requestVersion !== this.requestVersion) return
      this.entries = entries
    } catch (error) {
      if (requestVersion !== this.requestVersion) return
      this.errorMessage = error instanceof ApiError
        ? error.message
        : '黑名单加载失败'
    } finally {
      if (requestVersion === this.requestVersion) this.loading = false
    }
  }

  private search(): void {
    this.appliedKeyword = this.keyword.trim()
    this.load()
  }

  private async add(): Promise<void> {
    if (this.submitting || !this.writable) return
    this.submitting = true
    this.errorMessage = ''
    this.message = ''
    try {
      await repositoryFactory.blacklist().addBlacklist(this.tenantId, this.mac, this.reason)
      this.mac = ''
      this.reason = ''
      this.message = '黑名单记录已新增'
      await this.load()
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '黑名单新增失败'
    } finally {
      this.submitting = false
    }
  }

  private confirmRemove(entry: BlacklistEntry): void {
    if (!this.writable) return
    AlertDialog.show({
      title: '移除黑名单',
      message: `确认移除 ${entry.mac}？`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '移除',
        fontColor: AppTheme.dangerText,
        action: () => this.remove(entry)
      }
    })
  }

  private async remove(entry: BlacklistEntry): Promise<void> {
    this.errorMessage = ''
    this.message = ''
    try {
      await repositoryFactory.blacklist().removeBlacklist(this.tenantId, entry.id)
      this.message = '黑名单记录已移除'
      await this.load()
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '黑名单移除失败'
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button('‹').accessibilityText('返回')
          .width(44).height(44).fontSize(24)
          .fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.border }).borderRadius(6)
          .onClick(() => router.back())
        Column({ space: 2 }) {
          Text('租户运维').fontSize(11).fontColor(AppTheme.primary)
          Text('黑名单').fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('刷新')
          .height(44).fontSize(13).fontColor(AppTheme.textSoft)
          .backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(6)
          .onClick(() => this.load())
      }
      .width('100%')

      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 8 }) {
            TextInput({ text: this.keyword, placeholder: 'MAC 或加入原因' })
              .height(44).fontSize(13).fontColor(AppTheme.text)
              .placeholderColor(AppTheme.muted).backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(6)
              .layoutWeight(1)
              .onChange((value: string) => this.keyword = value)
              .onSubmit(() => this.search())
            Button('查询')
              .height(44).fontSize(13).fontColor(AppTheme.primaryText)
              .backgroundColor(AppTheme.primaryStrong).borderRadius(6)
              .onClick(() => this.search())
          }
          .width('100%')

          if (this.writable) {
            Column({ space: 8 }) {
              Text('新增黑名单').fontSize(15).fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.text).width('100%')
              TextInput({ text: this.mac, placeholder: 'MAC 地址，例如 AA:BB:CC:11:22:33' })
                .height(44).fontSize(13).fontColor(AppTheme.text)
                .placeholderColor(AppTheme.muted).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(6)
                .onChange((value: string) => this.mac = value)
              TextInput({ text: this.reason, placeholder: '加入原因' })
                .height(44).fontSize(13).fontColor(AppTheme.text)
                .placeholderColor(AppTheme.muted).backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(6)
                .onChange((value: string) => this.reason = value)
              Button(this.submitting ? '正在新增' : '新增黑名单')
                .enabled(!this.submitting).width('100%').height(44).fontSize(13)
                .fontColor(AppTheme.primaryText).backgroundColor(AppTheme.primaryStrong)
                .borderRadius(6).onClick(() => this.add())
            }
            .width('100%').padding(14).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(6)
          }

          if (this.message.length > 0) {
            Text(this.message).fontSize(13).fontColor(AppTheme.successText)
              .width('100%').padding(10).backgroundColor(AppTheme.successSurface)
              .borderRadius(6)
          }
          if (this.errorMessage.length > 0) {
            Column({ space: 8 }) {
              Text(this.errorMessage).fontSize(13).fontColor(AppTheme.dangerText)
                .textAlign(TextAlign.Center)
              Button('重试').height(44).fontSize(13)
                .fontColor(AppTheme.primaryText).backgroundColor(AppTheme.primaryStrong)
                .borderRadius(6).onClick(() => this.load())
            }
            .width('100%').padding(14).backgroundColor(AppTheme.dangerSurface)
            .border({ width: 1, color: AppTheme.danger }).borderRadius(6)
          } else if (this.loading && this.entries.length === 0) {
            LoadingProgress().width(32).height(32).color(AppTheme.primary)
          } else if (this.entries.length === 0) {
            Text('当前没有黑名单记录').fontSize(14).fontColor(AppTheme.muted)
              .width('100%').padding(24).textAlign(TextAlign.Center)
              .backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.border })
              .borderRadius(6)
          } else {
            ForEach(this.entries, (entry: BlacklistEntry) => {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Text(entry.mac).fontSize(15).fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.text)
                  Text(entry.reason).fontSize(12).fontColor(AppTheme.muted)
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`加入时间 ${entry.createdAt}`).fontSize(11).fontColor(AppTheme.muted)
                }
                .alignItems(HorizontalAlign.Start).layoutWeight(1)
                if (this.writable) {
                  Button('移除').height(44).fontSize(12).fontColor(AppTheme.dangerText)
                    .backgroundColor(AppTheme.surfaceRaised)
                    .border({ width: 1, color: AppTheme.danger }).borderRadius(6)
                    .onClick(() => this.confirmRemove(entry))
                }
              }
              .width('100%').padding(14).backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border }).borderRadius(6)
            }, (entry: BlacklistEntry): string => String(entry.id))
          }
        }
        .width('100%').padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }
      .layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor(AppTheme.background)
  }
}
