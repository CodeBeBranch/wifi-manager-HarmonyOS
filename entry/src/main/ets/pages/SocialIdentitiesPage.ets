import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { SocialIdentity } from '../model/Hm1Models'
import { accountRepositoryFactory } from '../repository/AccountRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct SocialIdentitiesPage {
  @State identities: SocialIdentity[] = []
  @State loading: boolean = true
  @State workingProvider: string = ''
  @State error: string = ''

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      const snapshot = sessionStore.getSnapshot()
      this.identities = await accountRepositoryFactory.current()
        .listSocialIdentities(snapshot.username)
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '社交身份加载失败'
    } finally {
      this.loading = false
    }
  }

  private async toggle(item: SocialIdentity): Promise<void> {
    this.workingProvider = item.provider
    this.error = ''
    try {
      const snapshot = sessionStore.getSnapshot()
      this.identities = await accountRepositoryFactory.current().setSocialIdentity(
        snapshot.username,
        item.provider,
        !item.bound
      )
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '操作失败'
    } finally {
      this.workingProvider = ''
    }
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_backward'))
            .fontSize(22)
            .fontColor([AppTheme.text])
        }
        .width(44)
        .height(44)
        .backgroundColor(AppTheme.surface)
        .onClick(() => router.back())
        Text('社交身份')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 12 })

      if (this.loading) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.primary)
          .layoutWeight(1)
      } else {
        Scroll() {
          Column() {
            Text('已绑定身份可用于账号识别，真实授权回跳将在契约冻结后独立验收。')
              .fontSize(13)
              .fontColor(AppTheme.muted)
              .lineHeight(21)
              .width('100%')
              .margin({ bottom: 18 })

            Column() {
              ForEach(this.identities, (item: SocialIdentity, index: number) => {
                Row({ space: 12 }) {
                  SymbolGlyph($r('sys.symbol.person'))
                    .fontSize(28)
                    .fontColor([item.bound ? AppTheme.primary : AppTheme.textSoft])
                    .width(40)
                  Column({ space: 4 }) {
                    Text(item.label)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.text)
                    Text(item.bound ? item.account : '未绑定')
                      .fontSize(12)
                      .fontColor(item.bound ? AppTheme.textSoft : AppTheme.muted)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Button(this.workingProvider === item.provider
                    ? '处理中'
                    : (item.bound ? '解绑' : '绑定'))
                    .enabled(this.workingProvider.length === 0)
                    .height(40)
                    .fontSize(13)
                    .fontColor(item.bound ? AppTheme.dangerText : AppTheme.primary)
                    .backgroundColor(Color.Transparent)
                    .onClick(() => this.toggle(item))
                }
                .width('100%')
                .height(76)
                .border({
                  width: { bottom: index < this.identities.length - 1 ? 1 : 0 },
                  color: AppTheme.border
                })
              }, (item: SocialIdentity) => item.provider)
            }
            .width('100%')
            .padding({ left: 14, right: 10 })
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)

            if (this.error.length > 0) {
              Text(this.error)
                .fontSize(13)
                .fontColor(AppTheme.dangerText)
                .width('100%')
                .margin({ top: 16 })
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 20, bottom: 32 })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }
}
