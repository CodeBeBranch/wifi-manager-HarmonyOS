import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import {
  PlatformAccount,
  PlatformAccountDetailParams,
  PlatformSummary,
  SaasPlan
} from '../model/Hm2Models'
import { platformAdminRepositoryFactory } from '../repository/PlatformAdminRepository'
import { AppTheme } from '../ui/AppTheme'

interface PlatformHm7ServiceItem {
  title: string
  description: string
  route: string
}

@Component
export struct PlatformHomeContent {
  @Link selectedTab: number
  @State summary: PlatformSummary = {
    tenantTotal: 0,
    activeTenantTotal: 0,
    accountTotal: 0,
    pendingReviewTotal: 0,
    activePlanTotal: 0
  }
  @State loading: boolean = false
  @State errorMessage: string = ''
  private requestVersion: number = 0

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    const version = ++this.requestVersion
    this.loading = true
    this.errorMessage = ''
    try {
      const result = await platformAdminRepositoryFactory.current().summary()
      if (version !== this.requestVersion) return
      this.summary = result
    } catch (error) {
      if (version !== this.requestVersion) return
      this.errorMessage = error instanceof ApiError ? error.message : '平台摘要加载失败'
    } finally {
      if (version === this.requestVersion) this.loading = false
    }
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Column({ space: 3 }) {
            Text('WiFi Manager')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.primary)
            Text('平台治理')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.text)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.bell'))
              .fontSize(20)
              .fontColor([AppTheme.textSoft])
          }
          .width(44)
          .height(44)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border })
          .onClick(() => router.pushUrl({ url: 'pages/NoticeListPage' }))
        }
        .width('100%')

        Row({ space: 8 }) {
          Circle().width(8).height(8).fill(AppTheme.success)
          Text('系统管理')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .layoutWeight(1)
          Text('本地演示')
            .fontSize(12)
            .fontColor(AppTheme.infoText)
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })
        .backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.border })
        .borderRadius(8)
        .margin({ top: 18 })

        Text('平台概览')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .width('100%')
          .margin({ top: 24, bottom: 10 })

        Row({ space: 8 }) {
          this.metric('组织', this.summary.tenantTotal, AppTheme.primary)
          this.metric('可用组织', this.summary.activeTenantTotal, AppTheme.success)
        }
        .width('100%')
        Row({ space: 8 }) {
          this.metric('账号', this.summary.accountTotal, AppTheme.info)
          this.metric('待审核', this.summary.pendingReviewTotal, AppTheme.warning)
        }
        .width('100%')
        .margin({ top: 8 })

        if (this.loading) {
          Row({ space: 10 }) {
            LoadingProgress().width(22).height(22).color(AppTheme.primary)
            Text('正在更新平台摘要').fontSize(13).fontColor(AppTheme.muted)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 16 })
        } else if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor(AppTheme.dangerText)
            .width('100%')
            .padding(12)
            .backgroundColor(AppTheme.dangerSurface)
            .borderRadius(8)
            .margin({ top: 16 })
            .onClick(() => this.load())
        }

        Text('常用操作')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .width('100%')
          .margin({ top: 24, bottom: 10 })

        Column() {
          this.actionRow('组织管理', `${this.summary.activeTenantTotal} 个组织可进入代管`,
            $r('sys.symbol.grid'), (): void => {
              this.selectedTab = 1
            })
          Divider().color(AppTheme.border)
          this.actionRow('账号治理', `${this.summary.pendingReviewTotal} 项删除申请待处理`,
            $r('sys.symbol.person'), (): void => {
              this.selectedTab = 2
            })
          Divider().color(AppTheme.border)
          this.actionRow('SaaS 套餐', `${this.summary.activePlanTotal} 个已发布套餐`,
            $r('sys.symbol.cloud'), (): void => {
              this.selectedTab = 3
            })
        }
        .width('100%')
        .backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.border })
        .borderRadius(8)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 28 })
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private metric(label: string, value: number, color: Resource) {
    Column({ space: 7 }) {
      Text(String(value))
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label).fontSize(12).fontColor(AppTheme.muted)
    }
    .layoutWeight(1)
    .height(84)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.surface)
    .border({ width: 1, color: AppTheme.border })
    .borderRadius(8)
  }

  @Builder
  private actionRow(label: string, description: string, icon: Resource, action: () => void) {
    Row({ space: 10 }) {
      SymbolGlyph(icon).fontSize(22).fontColor([AppTheme.primary]).width(32)
      Column({ space: 3 }) {
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
}

@Component
export struct PlatformAccountListContent {
  @State accounts: PlatformAccount[] = []
  @State keyword: string = ''
  @State appliedKeyword: string = ''
  @State statusFilter: string = ''
  @State current: number = 0
  @State pageSize: number = 3
  @State total: number = 0
  @State loading: boolean = false
  @State errorMessage: string = ''
  private requestVersion: number = 0

  aboutToAppear(): void {
    this.load(true)
  }

  private async load(reset: boolean): Promise<void> {
    const version = ++this.requestVersion
    const page = reset ? 1 : this.current + 1
    this.loading = true
    this.errorMessage = ''
    try {
      const result = await platformAdminRepositoryFactory.current().listAccounts(
        page,
        this.pageSize,
        this.appliedKeyword,
        this.statusFilter
      )
      if (version !== this.requestVersion) return
      this.accounts = reset ? result.records : this.accounts.concat(result.records)
      this.current = result.current
      this.pageSize = result.size
      this.total = result.total
    } catch (error) {
      if (version !== this.requestVersion) return
      this.errorMessage = error instanceof ApiError ? error.message : '账号列表加载失败'
    } finally {
      if (version === this.requestVersion) this.loading = false
    }
  }

  private search(): void {
    this.appliedKeyword = this.keyword.trim()
    this.load(true)
  }

  private applyStatus(status: string): void {
    if (this.statusFilter === status) return
    this.statusFilter = status
    this.load(true)
  }

  private openAccount(account: PlatformAccount): void {
    const params: PlatformAccountDetailParams = {
      userId: account.userId
    }
    router.pushUrl({
      url: 'pages/PlatformAccountDetailPage',
      params: params
    })
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Column({ space: 3 }) {
            Text('系统管理').fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.primary)
            Text('账号').fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button('删除审核')
            .height(40)
            .fontSize(13)
            .fontColor(AppTheme.primary)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.borderStrong })
            .borderRadius(8)
            .onClick(() => router.pushUrl({ url: 'pages/PlatformAccountReviewsPage' }))
        }
        .width('100%')

        Row({ space: 10 }) {
          TextInput({ text: this.keyword, placeholder: '账号、昵称或邮箱' })
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
        .margin({ top: 18 })

        Row() {
          this.filterButton('全部', '')
          this.filterButton('正常', 'ACTIVE')
          this.filterButton('停用', 'SUSPENDED')
        }
        .width('100%')
        .height(42)
        .padding(3)
        .backgroundColor(AppTheme.surfaceMuted)
        .borderRadius(8)
        .margin({ top: 12 })

        Text(`共 ${this.total} 个账号`)
          .fontSize(12)
          .fontColor(AppTheme.muted)
          .width('100%')
          .margin({ top: 14, bottom: 8 })

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor(AppTheme.dangerText)
            .width('100%')
            .padding(12)
            .backgroundColor(AppTheme.dangerSurface)
            .borderRadius(8)
            .onClick(() => this.load(true))
        } else if (this.loading && this.accounts.length === 0) {
          LoadingProgress().width(34).height(34).color(AppTheme.primary).margin({ top: 48 })
        } else if (this.accounts.length === 0) {
          Text('没有符合条件的账号')
            .fontSize(14)
            .fontColor(AppTheme.muted)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 56, bottom: 56 })
        } else {
          Column({ space: 10 }) {
            ForEach(this.accounts, (account: PlatformAccount) => {
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text(account.nickname || account.username)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.text)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${account.username} · ${this.roleLabel(account.role)}`)
                    .fontSize(12)
                    .fontColor(AppTheme.muted)
                    .maxLines(1)
                  if (account.deletionState === 'PENDING') {
                    Text('删除待审核').fontSize(12).fontColor(AppTheme.warningText)
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text(this.statusLabel(account.status))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(account.status === 'ACTIVE' ? AppTheme.successText : AppTheme.muted)
                Text('›').fontSize(21).fontColor(AppTheme.muted)
              }
              .width('100%')
              .height(78)
              .padding({ left: 14, right: 12, top: 12, bottom: 12 })
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)
              .onClick(() => this.openAccount(account))
            }, (account: PlatformAccount) => account.userId)

            if (this.accounts.length < this.total) {
              Button(this.loading ? '正在加载' : '加载更多')
                .enabled(!this.loading)
                .width('100%')
                .height(46)
                .fontSize(14)
                .fontColor(AppTheme.textSoft)
                .backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.borderStrong })
                .borderRadius(8)
                .onClick(() => this.load(false))
            }
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 28 })
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor(AppTheme.background)
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

  @Builder
  private filterButton(label: string, value: string) {
    Button(label)
      .layoutWeight(1)
      .height(36)
      .fontSize(13)
      .fontColor(this.statusFilter === value ? AppTheme.text : AppTheme.muted)
      .backgroundColor(this.statusFilter === value ? AppTheme.surface : Color.Transparent)
      .borderRadius(6)
      .onClick(() => this.applyStatus(value))
  }
}

@Component
export struct PlatformServiceContent {
  @State plans: SaasPlan[] = []
  @State loading: boolean = false
  @State errorMessage: string = ''

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    this.errorMessage = ''
    try {
      const result = await platformAdminRepositoryFactory.current().listSaasPlans(1, 3, '', '')
      this.plans = result.records
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '服务目录加载失败'
    } finally {
      this.loading = false
    }
  }

  build() {
    Scroll() {
      Column() {
        Text('服务')
          .fontSize(23)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .width('100%')
        Text('平台可用服务')
          .fontSize(13)
          .fontColor(AppTheme.muted)
          .width('100%')
          .margin({ top: 4, bottom: 18 })

        Column() {
          Row({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.cloud'))
              .fontSize(25)
              .fontColor([AppTheme.primary])
              .width(36)
            Column({ space: 4 }) {
              Text('SaaS 套餐')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.text)
              Text('查看版本、价格、配额和发布状态')
                .fontSize(12)
                .fontColor(AppTheme.muted)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›').fontSize(21).fontColor(AppTheme.muted)
          }
          .width('100%')
          .height(76)
          .padding({ left: 14, right: 12 })
          .onClick(() => router.pushUrl({ url: 'pages/PlatformSaasPlanListPage' }))
        }
        .width('100%')
        .backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.border })
        .borderRadius(8)

        ForEach([
          {
            title: '订阅与配额',
            description: '查询组织订阅、续期、停用和配额',
            route: 'pages/PlatformSubscriptionListPage'
          },
          {
            title: 'Marketplace',
            description: '管理商品、SKU、订单和履约异常',
            route: 'pages/PlatformMarketplaceProductListPage'
          },
          {
            title: '公告治理',
            description: '发布、撤回和审核平台公告',
            route: 'pages/PlatformAnnouncementListPage'
          },
          {
            title: 'AI 人工复核',
            description: '审核模型建议并通过、驳回或转人工',
            route: 'pages/PlatformAiReviewListPage'
          },
          {
            title: 'Support 工单',
            description: '审核、回复和分派跨组织工单',
            route: 'pages/PlatformSupportListPage'
          },
          {
            title: '平台运行',
            description: '查看健康摘要并人工恢复异常任务',
            route: 'pages/PlatformRuntimePage'
          },
          {
            title: '平台审计',
            description: '只读查询平台计划能力操作记录',
            route: 'pages/PlatformAuditListPage'
          }
        ] as PlatformHm7ServiceItem[], (item: PlatformHm7ServiceItem) => {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text(item.title).fontSize(16).fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.text)
              Text(item.description).fontSize(12).fontColor(AppTheme.muted)
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('›').fontSize(21).fontColor(AppTheme.muted)
          }
          .width('100%').height(72).padding({ left: 14, right: 12 })
          .backgroundColor(AppTheme.surface).border({ width: 1, color: AppTheme.border })
          .borderRadius(8).margin({ top: 10 })
          .onClick(() => router.pushUrl({ url: item.route }))
        }, (item: PlatformHm7ServiceItem): string => item.route)

        Text('已发布套餐')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .width('100%')
          .margin({ top: 24, bottom: 10 })

        if (this.loading) {
          LoadingProgress().width(34).height(34).color(AppTheme.primary).margin({ top: 36 })
        } else if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor(AppTheme.dangerText)
            .width('100%')
            .padding(12)
            .backgroundColor(AppTheme.dangerSurface)
            .borderRadius(8)
            .onClick(() => this.load())
        } else {
          Column({ space: 10 }) {
            ForEach(this.plans, (plan: SaasPlan) => {
              Row() {
                Column({ space: 4 }) {
                  Text(`${plan.name} ${plan.version}`)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.text)
                  Text(`${plan.priceLabel} · ${plan.deviceLimit} 台设备`)
                    .fontSize(12)
                    .fontColor(AppTheme.muted)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text(plan.status === 'PUBLISHED' ? '已发布' : '草稿')
                  .fontSize(12)
                  .fontColor(plan.status === 'PUBLISHED' ? AppTheme.successText : AppTheme.muted)
              }
              .width('100%')
              .height(68)
              .padding({ left: 14, right: 14 })
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)
            }, (plan: SaasPlan) => plan.planId)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 28 })
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor(AppTheme.background)
  }
}
