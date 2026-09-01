import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { MemberSummary } from '../model/Hm5Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface MemberShortcut {
  title: string
  description: string
  route: string
}

@Component
export struct MemberHomeContent {
  @State summary: MemberSummary | null = null
  @State loading: boolean = true
  @State error: string = ''

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.error = ''
    try {
      this.summary = await repositoryFactory.hm5Member().summary()
    } catch (error) {
      this.summary = null
      this.error = error instanceof ApiError ? error.message : '成员首页加载失败'
    } finally {
      this.loading = false
    }
  }

  private open(route: string): void {
    router.pushUrl({ url: route })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 4 }) {
          Text('成员中心').fontSize(12).fontColor(AppTheme.primary).width('100%')
          Text(`你好，${sessionStore.getSnapshot().nickname || '成员'}`)
            .fontSize(24).fontWeight(FontWeight.Bold).fontColor(AppTheme.text).width('100%')
          Text(sessionStore.getSnapshot().context?.tenantName ?? '当前组织')
            .fontSize(13).fontColor(AppTheme.muted).width('100%')
        }.width('100%').alignItems(HorizontalAlign.Start)

        if (this.loading) {
          LoadingProgress().width(36).height(36).color(AppTheme.primary).margin({ top: 24 })
        } else if (this.summary === null) {
          Text(this.error.length > 0 ? this.error : '成员权益暂不可用')
            .width('100%').padding(14).fontColor(AppTheme.dangerText)
            .backgroundColor(AppTheme.dangerSurface).borderRadius(8)
        } else {
          Column({ space: 12 }) {
            Row() {
              Column({ space: 3 }) {
                Text(this.summary.entitlementName).fontSize(17).fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.text)
                Text('当前权益').fontSize(12).fontColor(AppTheme.muted)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(`${this.summary.remainingGb.toFixed(1)} GB`)
                .fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppTheme.primary)
            }.width('100%')
            Row() {
              this.metric('在线连接', String(this.summary.activeConnections))
              this.metric('待支付', String(this.summary.pendingOrders))
              this.metric('未读通知', String(this.summary.unreadNotices))
            }.width('100%')
          }.width('100%').padding(16).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(8)
        }

        Text('常用服务').fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textSoft).width('100%').margin({ top: 4 })
        ForEach([
          { title: '可购产品', description: '选择适合当前连接的权益产品', route: 'pages/MemberProductListPage' },
          { title: '我的订单', description: '创建、支付或取消待处理订单', route: 'pages/MemberOrderListPage' },
          { title: '退款申请', description: '查看退款进度或提交新申请', route: 'pages/MemberRefundListPage' },
          { title: '位置隐私', description: '管理授权并查看本人位置历史', route: 'pages/MemberLocationPrivacyPage' }
        ] as MemberShortcut[], (item: MemberShortcut) => {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text(item.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
              Text(item.description).fontSize(12).fontColor(AppTheme.muted)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('›').fontSize(22).fontColor(AppTheme.muted)
          }.width('100%').padding(14).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            .onClick(() => this.open(item.route))
        }, (item: MemberShortcut): string => item.route)
      }.width('100%').padding({ left: 16, right: 16, top: 18, bottom: 24 })
    }.width('100%').height('100%').backgroundColor(AppTheme.background)
  }

  @Builder
  private metric(label: string, value: string) {
    Column({ space: 3 }) {
      Text(value).fontSize(19).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
      Text(label).fontSize(11).fontColor(AppTheme.muted)
    }.layoutWeight(1)
  }
}

@Component
export struct MemberServiceContent {
  private open(route: string): void {
    router.pushUrl({ url: route })
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 4 }) {
          Text('成员中心').fontSize(11).fontColor(AppTheme.primary).width('100%')
          Text('服务').fontSize(24).fontWeight(FontWeight.Bold).fontColor(AppTheme.text).width('100%')
          Text('权益、消费记录与本人数据')
            .fontSize(13).fontColor(AppTheme.muted).width('100%')
        }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 8 })

        ForEach([
          { title: '当前权益', description: '查看剩余额度、模式和有效期', route: 'pages/MemberEntitlementPage' },
          { title: '产品与购买', description: '浏览产品和本人购买记录', route: 'pages/MemberProductListPage' },
          { title: '订单', description: '创建订单并跟踪支付状态', route: 'pages/MemberOrderListPage' },
          { title: '退款', description: '申请退款并查看处理进度', route: 'pages/MemberRefundListPage' },
          { title: '使用流水', description: '查看本人流量和连接使用记录', route: 'pages/MemberUsageHistoryPage' },
          { title: '位置隐私', description: '授权、撤销和清除位置历史', route: 'pages/MemberLocationPrivacyPage' },
          { title: 'Marketplace', description: '浏览商品并查看履约订单', route: 'pages/MemberMarketplaceProductListPage' },
          { title: '公告', description: '阅读公告并参与评论', route: 'pages/MemberAnnouncementListPage' },
          { title: 'Support 工单', description: '创建工单并跟踪回复', route: 'pages/MemberSupportListPage' },
          { title: '消息', description: '查看服务消息并安全跳转', route: 'pages/MemberMessageListPage' },
          { title: '个人资料', description: '查看并维护本人资料', route: 'pages/ProfilePage' },
          { title: '社交身份', description: '查看第三方身份绑定状态', route: 'pages/SocialIdentitiesPage' }
        ] as MemberShortcut[], (item: MemberShortcut) => {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text(item.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
              Text(item.description).fontSize(12).fontColor(AppTheme.muted)
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('›').fontSize(22).fontColor(AppTheme.muted)
          }.width('100%').padding(15).backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border }).borderRadius(6)
            .onClick(() => this.open(item.route))
        }, (item: MemberShortcut): string => item.route)
      }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 24 })
    }.width('100%').height('100%').backgroundColor(AppTheme.background)
  }
}
