import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { AppNotice, unreadNoticeCount } from '../model/Hm1Models'
import { accountRepositoryFactory } from '../repository/AccountRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface NoticeDetailParams {
  id: string
}

@Entry
@Component
struct NoticeListPage {
  @State notices: AppNotice[] = []
  @State category: string = '全部'
  @State loading: boolean = false
  @State working: boolean = false
  @State error: string = ''

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      const snapshot = sessionStore.getSnapshot()
      this.notices = await accountRepositoryFactory.current().listNotices(snapshot.username)
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '通知加载失败'
    } finally {
      this.loading = false
    }
  }

  private visibleNotices(): AppNotice[] {
    if (this.category === '全部') {
      return this.notices
    }
    return this.notices.filter(
      (notice: AppNotice): boolean => notice.category === this.category
    )
  }

  private async markAllRead(): Promise<void> {
    if (this.working) return
    this.working = true
    this.error = ''
    try {
      const snapshot = sessionStore.getSnapshot()
      await accountRepositoryFactory.current().markAllNoticesRead(snapshot.username)
      await this.load()
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '通知状态更新失败'
    } finally {
      this.working = false
    }
  }

  private async openNotice(notice: AppNotice): Promise<void> {
    if (this.working) return
    this.working = true
    this.error = ''
    try {
      const snapshot = sessionStore.getSnapshot()
      await accountRepositoryFactory.current().markNoticeRead(snapshot.username, notice.id)
      const params: NoticeDetailParams = { id: notice.id }
      await router.pushUrl({ url: 'pages/NoticeDetailPage', params: params })
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '通知打开失败'
    } finally {
      this.working = false
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
        Text('通知')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .layoutWeight(1)
        Button('全部已读')
          .height(44)
          .fontSize(13)
          .fontColor(unreadNoticeCount(this.notices) > 0 ? AppTheme.primary : AppTheme.muted)
          .backgroundColor(Color.Transparent)
          .enabled(!this.working && unreadNoticeCount(this.notices) > 0)
          .onClick(() => this.markAllRead())
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12 })

      Row({ space: 8 }) {
        ForEach(['全部', '安全', '服务', '账号'], (item: string) => {
          Button(item)
            .layoutWeight(1)
            .height(44)
            .fontSize(13)
            .fontColor(this.category === item ? AppTheme.primaryText : AppTheme.textSoft)
            .backgroundColor(this.category === item ? AppTheme.primaryStrong : AppTheme.surface)
            .borderRadius(6)
            .onClick(() => this.category = item)
        })
      }
      .width('100%')
      .padding(4)
      .backgroundColor(AppTheme.surfaceMuted)
      .borderRadius(8)
      .margin({ left: 16, right: 16, top: 12, bottom: 12 })

      if (this.loading) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.primary)
          .layoutWeight(1)
      } else if (this.error.length > 0) {
        Column({ space: 12 }) {
          Text(this.error)
            .fontSize(14)
            .fontColor(AppTheme.dangerText)
            .textAlign(TextAlign.Center)
          Button('重试')
            .height(44)
            .fontColor(AppTheme.primary)
            .backgroundColor(AppTheme.surface)
            .onClick(() => this.load())
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.visibleNotices(), (notice: AppNotice) => {
            ListItem() {
              Row({ space: 12 }) {
                Circle()
                  .width(8)
                  .height(8)
                  .fill(notice.read ? AppTheme.borderStrong : AppTheme.primary)
                Column({ space: 5 }) {
                  Row() {
                    Text(notice.title)
                      .fontSize(15)
                      .fontWeight(notice.read ? FontWeight.Regular : FontWeight.Bold)
                      .fontColor(AppTheme.text)
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(notice.createTime)
                      .fontSize(11)
                      .fontColor(AppTheme.muted)
                  }
                  .width('100%')
                  Text(notice.summary)
                    .fontSize(13)
                    .fontColor(AppTheme.textSoft)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                  Text(notice.category)
                    .fontSize(11)
                    .fontColor(AppTheme.primary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)
              .onClick(() => this.openNotice(notice))
            }
          }, (notice: AppNotice) => notice.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 20 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }
}
