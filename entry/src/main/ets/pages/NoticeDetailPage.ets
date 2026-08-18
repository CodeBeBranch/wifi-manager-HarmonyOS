import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { AppNotice } from '../model/Hm1Models'
import { resolveNoticeTargetRoute } from '../navigation/AppRouter'
import { accountRepositoryFactory } from '../repository/AccountRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface NoticeDetailParams {
  id?: string
}

@Entry
@Component
struct NoticeDetailPage {
  @State notice: AppNotice | null = null
  @State error: string = ''

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    const params = router.getParams() as NoticeDetailParams
    const id = params.id ?? ''
    if (id.length === 0) {
      this.error = '通知参数无效'
      return
    }
    try {
      const snapshot = sessionStore.getSnapshot()
      this.notice = await accountRepositoryFactory.current().noticeDetail(snapshot.username, id)
      await accountRepositoryFactory.current().markNoticeRead(snapshot.username, id)
    } catch (error) {
      this.error = error instanceof ApiError ? error.message : '通知加载失败'
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
        Text('通知详情')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 12 })

      if (this.notice !== null) {
        Scroll() {
          Column({ space: 14 }) {
            Text(this.notice.title)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.text)
              .width('100%')
            Row({ space: 10 }) {
              Text(this.notice.category)
                .fontSize(12)
                .fontColor(AppTheme.primary)
              Text(this.notice.createTime)
                .fontSize(12)
                .fontColor(AppTheme.muted)
            }
            .width('100%')
            Text(this.notice.content)
              .fontSize(15)
              .fontColor(AppTheme.textSoft)
              .lineHeight(25)
              .width('100%')
              .margin({ top: 10 })
            if (this.notice.targetRoute.length > 0 &&
              this.notice.targetRoute !== 'pages/MainPage') {
              Button('查看相关页面')
                .width('100%')
                .height(48)
                .fontSize(14)
                .fontColor(AppTheme.primary)
                .backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.primary })
                .borderRadius(8)
                .margin({ top: 18 })
                .onClick(() => router.pushUrl({
                  url: resolveNoticeTargetRoute(this.notice?.targetRoute ?? '')
                }))
            }
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 28, bottom: 32 })
        }
        .layoutWeight(1)
        .width('100%')
      } else if (this.error.length > 0) {
        Text(this.error)
          .fontSize(14)
          .fontColor(AppTheme.dangerText)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      } else {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.primary)
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }
}
