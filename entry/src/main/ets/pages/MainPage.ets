import router from '@ohos.router'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AlertEvent, AlertQuery } from '../model/AlertModels'
import { ApiError } from '../model/ApiModels'
import { SessionSnapshot, anonymousSnapshot } from '../model/AuthModels'
import { DeviceNode } from '../model/DeviceModels'
import { SessionQuery } from '../model/SessionModels'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { platformAdminMutationRevision } from '../repository/PlatformAdminRepository'
import { SessionListener, sessionStore } from '../session/SessionStore'
import {
  MainPageParams,
  addMainRootRouteListener,
  mainRootRouteFromParams,
  removeMainRootRouteListener,
  resetToLogin
} from '../navigation/AppRouter'
import { isWorkspaceTransitionActive, leaveManagedTenant } from '../navigation/WorkspaceTransition'
import { AppTheme } from '../ui/AppTheme'
import {
  canReadAdminWorkspace,
  hasTenantWorkspace,
  isManagedTenantWorkspace,
  isPlatformWorkspace,
  MainRootRouteId,
  MainTab,
  MainTabKey,
  mainTabKey,
  mainTabIndexForRoute,
  mainRootRouteId,
  mainTabs,
  mainTabRenderKey,
  roleLabel,
  workspaceTitle
} from '../ui/MainNavigation'
import { AlertListContent } from './AlertListPage'
import { DeviceListContent } from './DeviceListPage'
import { PlatformTenantListContent } from './PlatformTenantListPage'
import {
  PlatformAccountListContent,
  PlatformHomeContent,
  PlatformServiceContent
} from './PlatformRootContent'
import { SessionListContent } from './SessionListPage'
import { TenantServiceContent } from './TenantServiceContent'
import { MemberHomeContent, MemberServiceContent } from './MemberRootContent'

interface DeviceDetailParams {
  nodeId: string
}

interface AlertDetailParams {
  id: string
}

const ROUTE_LOG_DOMAIN = 0x0000

@Entry
@Component
struct MainPage {
  @State selectedTab: number = 0
  @State snapshot: SessionSnapshot = anonymousSnapshot()
  @State previewMode: boolean = false
  @State homeLoading: boolean = false
  @State homeError: string = ''
  @State deviceTotal: number = 0
  @State activeSessionTotal: number = 0
  @State unresolvedAlertTotal: number = 0
  @State recentDevices: DeviceNode[] = []
  @State recentAlerts: AlertEvent[] = []
  @State loggingOut: boolean = false
  @State contextSwitching: boolean = false
  @State accountError: string = ''
  @State platformMutationRevision: number = 0
  @State tenantContentRevision: number = 0
  private homeRequestVersion: number = 0
  private rootRouteListener = (rootRouteId: MainRootRouteId): void => {
    this.selectedTab = mainTabIndexForRoute(this.snapshot, rootRouteId)
  }
  private sessionListener: SessionListener = (next: SessionSnapshot): void => {
    if (isWorkspaceTransitionActive()) {
      return
    }
    const workspaceChanged = this.snapshot.role !== next.role ||
      this.snapshot.context?.contextType !== next.context?.contextType ||
      this.snapshot.context?.tenantId !== next.context?.tenantId
    this.snapshot = next
    this.previewMode = sessionStore.isPreviewMode()
    if (!next.authenticated) {
      resetToLogin()
      return
    }
    if (workspaceChanged || this.selectedTab >= mainTabs(next).length) {
      this.selectedTab = 0
      this.loadHome()
    }
  }

  aboutToAppear(): void {
    this.snapshot = sessionStore.getSnapshot()
    this.previewMode = sessionStore.isPreviewMode()
    if (!this.snapshot.authenticated) {
      resetToLogin()
      return
    }
    sessionStore.addListener(this.sessionListener)
    addMainRootRouteListener(this.rootRouteListener)
    const rootRouteId = mainRootRouteFromParams(router.getParams() as MainPageParams | null | undefined)
    hilog.info(ROUTE_LOG_DOMAIN, 'wifi-route',
      'main appear root %{public}s context %{public}s',
      rootRouteId ?? 'NONE', this.snapshot.context?.contextType ?? 'NONE')
    if (rootRouteId !== null) {
      this.selectedTab = mainTabIndexForRoute(this.snapshot, rootRouteId)
    }
    this.loadHome()
  }

  aboutToDisappear(): void {
    sessionStore.removeListener(this.sessionListener)
    removeMainRootRouteListener(this.rootRouteListener)
  }

  onPageShow(): void {
    this.platformMutationRevision = platformAdminMutationRevision()
    this.tenantContentRevision += 1
  }

  private async loadHome(): Promise<void> {
    const requestVersion = ++this.homeRequestVersion
    this.homeError = ''
    this.deviceTotal = 0
    this.activeSessionTotal = 0
    this.unresolvedAlertTotal = 0
    this.recentDevices = []
    this.recentAlerts = []
    if (!hasTenantWorkspace(this.snapshot)) {
      this.homeLoading = false
      return
    }

    this.homeLoading = true
    const admin = canReadAdminWorkspace(this.snapshot)
    try {
      const sessionQuery: SessionQuery = {
        current: 1,
        size: 1,
        mac: '',
        nodeId: '',
        userId: '',
        status: '1'
      }
      const sessions = await repositoryFactory.session().list(sessionQuery, admin)
      if (requestVersion !== this.homeRequestVersion) return
      this.activeSessionTotal = Number(sessions.total)

      if (admin) {
        const devices = await repositoryFactory.device().list(1, 3, '')
        if (requestVersion !== this.homeRequestVersion) return
        this.deviceTotal = Number(devices.total)
        this.recentDevices = devices.records ?? []

        const alertQuery: AlertQuery = {
          current: 1,
          size: 3,
          level: '',
          status: '0',
          mac: ''
        }
        const alerts = await repositoryFactory.alert().list(alertQuery)
        if (requestVersion !== this.homeRequestVersion) return
        this.unresolvedAlertTotal = Number(alerts.total)
        this.recentAlerts = alerts.records ?? []
      }
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        resetToLogin()
        return
      }
      if (requestVersion !== this.homeRequestVersion) return
      this.homeError = error instanceof Error ? error.message : '首页数据加载失败'
    } finally {
      if (requestVersion === this.homeRequestVersion) {
        this.homeLoading = false
      }
    }
  }

  private selectTab(index: number): void {
    if (this.selectedTab === index) {
      if (index === 0) {
        this.loadHome()
      }
      return
    }
    this.selectedTab = index
    if (index === 0) {
      this.loadHome()
    }
  }

  private currentTabKey(): MainTabKey {
    return mainTabKey(this.snapshot, this.selectedTab)
  }

  private currentRootRouteId(): MainRootRouteId {
    return mainRootRouteId(this.snapshot, this.selectedTab)
  }

  private selectTabByKey(key: MainTabKey): void {
    const tabs = mainTabs(this.snapshot)
    const index = tabs.findIndex((tab: MainTab): boolean => tab.key === key)
    if (index >= 0) {
      this.selectTab(index)
    }
  }

  private tabIcon(key: MainTabKey): Resource {
    if (key === 'HOME') return $r('sys.symbol.home_button')
    if (key === 'ORGANIZATIONS') return $r('sys.symbol.grid')
    if (key === 'ACCOUNTS') return $r('sys.symbol.person')
    if (key === 'DEVICES') return $r('sys.symbol.ohos_wifi')
    if (key === 'ALERTS') return $r('sys.symbol.bell')
    if (key === 'CONNECTIONS') return $r('sys.symbol.ohos_wifi')
    if (key === 'SERVICES') return $r('sys.symbol.grid')
    return $r('sys.symbol.person')
  }

  private openDevice(nodeId: number): void {
    const params: DeviceDetailParams = { nodeId: String(nodeId) }
    router.pushUrl({
      url: 'pages/DeviceDetail',
      params: params
    })
  }

  private openAlert(id: number): void {
    const params: AlertDetailParams = { id: String(id) }
    router.pushUrl({
      url: 'pages/AlertDetailPage',
      params: params
    })
  }

  private openOrganizations(): void {
    this.selectTabByKey('ORGANIZATIONS')
  }

  private openConnections(): void {
    if (this.snapshot.role === 2) {
      this.selectTabByKey('CONNECTIONS')
      return
    }
    router.pushUrl({ url: 'pages/SessionListPage' })
  }

  private async returnToPlatform(): Promise<void> {
    if (this.contextSwitching) return
    const tenantId = this.snapshot.context?.tenantId ?? ''
    if (tenantId.length === 0) return
    this.contextSwitching = true
    this.accountError = ''
    try {
      await leaveManagedTenant(tenantId)
    } catch (error) {
      this.accountError = error instanceof Error ? error.message : '工作区切换失败，请稍后重试'
    } finally {
      this.contextSwitching = false
    }
  }

  private async logout(): Promise<void> {
    if (this.loggingOut) return
    this.loggingOut = true
    this.accountError = ''
    try {
      await sessionStore.logout()
    } catch (_) {
      // 无论远端退出是否成功，都回到登录页并保持本地会话已清理。
    } finally {
      this.loggingOut = false
      resetToLogin()
    }
  }

  private levelLabel(level: number): string {
    if (level === 3) return '高'
    if (level === 2) return '中'
    if (level === 1) return '低'
    return '未知'
  }

  private levelColor(level: number): Resource {
    if (level === 3) return AppTheme.dangerText
    if (level === 2) return AppTheme.warningText
    return AppTheme.infoText
  }

  build() {
    Column() {
      if (this.currentRootRouteId() === 'platform/home') {
        PlatformHomeContent({
          selectedTab: $selectedTab
        })
          .layoutWeight(1)
      } else if (this.currentRootRouteId() === 'tenant/home') {
        this.homeTab()
      } else if (this.currentRootRouteId() === 'member/home') {
        MemberHomeContent()
          .layoutWeight(1)
      } else if (this.currentRootRouteId() === 'platform/tenants') {
        PlatformTenantListContent({ embedded: true })
          .layoutWeight(1)
      } else if (this.currentRootRouteId() === 'tenant/devices') {
        ForEach([this.tenantContentRevision], (_revision: number) => {
          DeviceListContent({ embedded: true })
            .layoutWeight(1)
        }, (revision: number): string => String(revision))
      } else if (this.currentRootRouteId() === 'tenant/alerts') {
        AlertListContent({ embedded: true })
          .layoutWeight(1)
      } else if (this.currentRootRouteId() === 'member/connections') {
        ForEach([this.tenantContentRevision], (_revision: number) => {
          SessionListContent({ embedded: true })
            .layoutWeight(1)
        }, (revision: number): string => String(revision))
      } else if (this.currentRootRouteId() === 'me/home') {
        this.profileTab()
      } else if (this.currentRootRouteId() === 'platform/accounts') {
        ForEach([this.platformMutationRevision], (_revision: number) => {
          PlatformAccountListContent()
            .layoutWeight(1)
        }, (revision: number): string => String(revision))
      } else if (this.currentRootRouteId() === 'platform/services') {
        PlatformServiceContent()
          .layoutWeight(1)
      } else if (this.currentRootRouteId() === 'tenant/services') {
        TenantServiceContent()
          .layoutWeight(1)
      } else if (this.currentRootRouteId() === 'member/services') {
        MemberServiceContent()
          .layoutWeight(1)
      } else {
        this.servicesTab()
      }

      Row() {
        ForEach(mainTabs(this.snapshot), (tab: MainTab, index: number) => {
          this.tabButton(tab, index)
        }, (tab: MainTab) => mainTabRenderKey(this.snapshot, tab))
      }
      .width('100%')
      .height(70)
      .padding({ left: 4, right: 4, bottom: 4 })
      .backgroundColor(AppTheme.surface)
      .border({ width: { top: 1 }, color: AppTheme.border })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private homeTab() {
    Scroll() {
      Column() {
        Row() {
          Column({ space: 3 }) {
            Text('WiFi Manager')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.primary)
            Text(`你好，${this.snapshot.nickname || this.snapshot.username}`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
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
          Button('刷新')
          .width(56)
          .height(44)
          .fontSize(13)
          .fontColor(AppTheme.textSoft)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border })
          .borderRadius(8)
          .onClick(() => this.loadHome())
        }
        .width('100%')

        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.cloud'))
            .fontSize(18)
            .fontColor([AppTheme.primary])
          Text(workspaceTitle(this.snapshot))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSoft)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(roleLabel(this.snapshot.role))
            .fontSize(12)
            .fontColor(AppTheme.muted)
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })
        .backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.border })
        .borderRadius(8)
        .margin({ top: 18 })

        if (this.previewMode) {
          Row({ space: 8 }) {
            Circle().width(7).height(7).fill(AppTheme.info)
            Text('本地演示')
              .fontSize(12)
              .fontColor(AppTheme.infoText)
          }
          .width('100%')
          .margin({ top: 12 })
        }

        if (isPlatformWorkspace(this.snapshot)) {
          Column({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.grid'))
              .fontSize(28)
              .fontColor([AppTheme.primary])
            Text('选择组织工作区')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.text)
            Text('设备、连接和告警数据按组织隔离。')
              .fontSize(13)
              .fontColor(AppTheme.muted)
              .textAlign(TextAlign.Center)
            Button('选择组织')
              .height(44)
              .fontSize(14)
              .fontColor(AppTheme.primaryText)
              .backgroundColor(AppTheme.primaryStrong)
              .borderRadius(8)
              .onClick(() => this.openOrganizations())
          }
          .width('100%')
          .padding({ top: 28, bottom: 28, left: 18, right: 18 })
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border })
          .borderRadius(8)
          .margin({ top: 18 })
        } else if (hasTenantWorkspace(this.snapshot)) {
          Text('运行概览')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.text)
            .width('100%')
            .margin({ top: 24, bottom: 10 })

          Row({ space: 8 }) {
            if (canReadAdminWorkspace(this.snapshot)) {
              this.metricItem('设备', this.deviceTotal, AppTheme.primary)
            }
            this.metricItem('在线连接', this.activeSessionTotal, AppTheme.success)
            if (canReadAdminWorkspace(this.snapshot)) {
              this.metricItem('未处理', this.unresolvedAlertTotal, AppTheme.warning)
            }
          }
          .width('100%')

          Text('常用服务')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.text)
            .width('100%')
            .margin({ top: 24, bottom: 10 })

          Row({ space: 8 }) {
            if (canReadAdminWorkspace(this.snapshot)) {
              this.quickAction('设备', $r('sys.symbol.ohos_wifi'), 1)
            }
            this.sessionAction()
            if (canReadAdminWorkspace(this.snapshot)) {
              this.quickAction('告警', $r('sys.symbol.bell'), 2)
            }
          }
          .width('100%')

          if (this.homeLoading) {
            Row({ space: 10 }) {
              LoadingProgress().width(24).height(24).color(AppTheme.primary)
              Text('正在更新首页数据').fontSize(13).fontColor(AppTheme.muted)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ top: 22 })
          } else if (this.homeError.length > 0) {
            Column({ space: 10 }) {
              Text(this.homeError)
                .fontSize(13)
                .fontColor(AppTheme.dangerText)
                .textAlign(TextAlign.Center)
              Button('重新加载')
                .height(44)
                .fontSize(13)
                .fontColor(AppTheme.primaryText)
                .backgroundColor(AppTheme.primaryStrong)
                .borderRadius(8)
                .onClick(() => this.loadHome())
            }
            .width('100%')
            .padding(16)
            .backgroundColor(AppTheme.dangerSurface)
            .borderRadius(8)
            .margin({ top: 18 })
          }

          if (canReadAdminWorkspace(this.snapshot) && this.recentDevices.length > 0) {
            this.sectionHeader('最近设备', '查看全部', 1)
            Column() {
              ForEach(this.recentDevices, (device: DeviceNode, index: number) => {
                Row({ space: 10 }) {
                  Circle()
                    .width(9)
                    .height(9)
                    .fill(device.status === 1 ? AppTheme.success : AppTheme.muted)
                  Column({ space: 3 }) {
                    Text(device.name || device.deviceCode)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.text)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`${device.currentClients ?? 0} 台终端 · ${device.location || '未设置位置'}`)
                      .fontSize(12)
                      .fontColor(AppTheme.muted)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Text('›').fontSize(20).fontColor(AppTheme.muted)
                }
                .width('100%')
                .height(62)
                .padding({ left: 14, right: 12 })
                .border({
                  width: { bottom: index < this.recentDevices.length - 1 ? 1 : 0 },
                  color: AppTheme.border
                })
                .onClick(() => this.openDevice(device.nodeId))
              }, (device: DeviceNode) => String(device.nodeId))
            }
            .width('100%')
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)
          }

          if (canReadAdminWorkspace(this.snapshot) && this.recentAlerts.length > 0) {
            this.sectionHeader('最新告警', '查看全部', 2)
            Column() {
              ForEach(this.recentAlerts, (alert: AlertEvent, index: number) => {
                Row({ space: 10 }) {
                  Text(this.levelLabel(alert.level))
                    .width(30)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.levelColor(alert.level))
                    .textAlign(TextAlign.Center)
                  Column({ space: 3 }) {
                    Text(alert.title || `告警 ${alert.id}`)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.text)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(alert.mac || alert.ruleCode || '未记录终端')
                      .fontSize(12)
                      .fontColor(AppTheme.muted)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Text('›').fontSize(20).fontColor(AppTheme.muted)
                }
                .width('100%')
                .height(62)
                .padding({ left: 12, right: 12 })
                .border({
                  width: { bottom: index < this.recentAlerts.length - 1 ? 1 : 0 },
                  color: AppTheme.border
                })
                .onClick(() => this.openAlert(alert.id))
              }, (alert: AlertEvent) => String(alert.id))
            }
            .width('100%')
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)
          }
        } else {
          Text('当前账号没有可用的组织工作区')
            .fontSize(14)
            .fontColor(AppTheme.warningText)
            .width('100%')
            .padding(16)
            .backgroundColor(AppTheme.warningSurface)
            .borderRadius(8)
            .margin({ top: 18 })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 28 })
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private metricItem(label: string, value: number, accent: Resource) {
    Column({ space: 7 }) {
      Text(String(value))
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(accent)
      Text(label)
        .fontSize(12)
        .fontColor(AppTheme.muted)
    }
    .layoutWeight(1)
    .height(82)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.surface)
    .border({ width: 1, color: AppTheme.border })
    .borderRadius(8)
  }

  @Builder
  private quickAction(label: string, icon: Resource, index: number) {
    Column({ space: 8 }) {
      SymbolGlyph(icon)
        .fontSize(25)
        .fontColor([AppTheme.primary])
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textSoft)
    }
    .layoutWeight(1)
    .height(76)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.surface)
    .border({ width: 1, color: AppTheme.border })
    .borderRadius(8)
    .onClick(() => this.selectTab(index))
  }

  @Builder
  private sessionAction() {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.grid'))
        .fontSize(25)
        .fontColor([AppTheme.info])
      Text('连接')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textSoft)
    }
    .layoutWeight(1)
    .height(76)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.surface)
    .border({ width: 1, color: AppTheme.border })
    .borderRadius(8)
    .onClick(() => this.openConnections())
  }

  @Builder
  private sectionHeader(title: string, action: string, index: number) {
    Row() {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.text)
        .layoutWeight(1)
      Button(action)
        .height(40)
        .fontSize(12)
        .fontColor(AppTheme.primary)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.selectTab(index))
    }
    .width('100%')
    .margin({ top: 22, bottom: 6 })
  }

  @Builder
  private platformAccountsTab() {
    Column() {
      Text('账号')
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.text)
        .width('100%')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.cloud'))
          .fontSize(18)
          .fontColor([AppTheme.primary])
        Text(workspaceTitle(this.snapshot))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textSoft)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(roleLabel(this.snapshot.role))
          .fontSize(12)
          .fontColor(AppTheme.muted)
      }
      .width('100%')
      .height(48)
      .padding({ left: 12, right: 12 })
      .backgroundColor(AppTheme.surface)
      .border({ width: 1, color: AppTheme.border })
      .borderRadius(8)
      .margin({ top: 16 })

      Column({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.person'))
          .fontSize(30)
          .fontColor([AppTheme.muted])
        Text('当前没有账号记录')
          .fontSize(14)
          .fontColor(AppTheme.muted)
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 18 })
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private servicesTab() {
    Column() {
      Text('服务')
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.text)
        .width('100%')

      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.cloud'))
          .fontSize(18)
          .fontColor([AppTheme.primary])
        Text(workspaceTitle(this.snapshot))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textSoft)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(roleLabel(this.snapshot.role))
          .fontSize(12)
          .fontColor(AppTheme.muted)
      }
      .width('100%')
      .height(48)
      .padding({ left: 12, right: 12 })
      .backgroundColor(AppTheme.surface)
      .border({ width: 1, color: AppTheme.border })
      .borderRadius(8)
      .margin({ top: 16 })

      Column({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.grid'))
          .fontSize(30)
          .fontColor([AppTheme.muted])
        Text('当前没有可用服务')
          .fontSize(14)
          .fontColor(AppTheme.muted)
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 18 })
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private restrictedTab(title: string, message: string) {
    Column() {
      Text(title)
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.text)
        .width('100%')
      Column({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.cloud'))
          .fontSize(30)
          .fontColor([AppTheme.muted])
        Text(message)
          .fontSize(14)
          .fontColor(AppTheme.muted)
          .textAlign(TextAlign.Center)
        if (isPlatformWorkspace(this.snapshot)) {
          Button('选择组织')
            .height(44)
            .fontSize(14)
            .fontColor(AppTheme.primaryText)
            .backgroundColor(AppTheme.primaryStrong)
            .borderRadius(8)
            .onClick(() => router.pushUrl({ url: 'pages/PlatformTenantListPage' }))
        }
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 18 })
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private profileTab() {
    Scroll() {
      Column() {
        Text('我的')
          .fontSize(23)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .width('100%')

        Row({ space: 14 }) {
          Stack() {
            Circle()
              .width(56)
              .height(56)
              .fill(AppTheme.primaryStrong)
            Text((this.snapshot.nickname || this.snapshot.username || 'U').substring(0, 1))
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.primaryText)
          }
          .width(56)
          .height(56)
          Column({ space: 4 }) {
            Text(this.snapshot.nickname || this.snapshot.username)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${this.snapshot.username} · ${roleLabel(this.snapshot.role)}`)
              .fontSize(13)
              .fontColor(AppTheme.textSoft)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })

        if (this.previewMode) {
          Row({ space: 8 }) {
            Circle().width(7).height(7).fill(AppTheme.info)
            Text('本地演示')
              .fontSize(12)
              .fontColor(AppTheme.infoText)
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
          .height(40)
          .backgroundColor(AppTheme.surfaceMuted)
          .borderRadius(8)
          .margin({ bottom: 14 })
        }

        Text('工作区')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.muted)
          .width('100%')
          .margin({ bottom: 8 })

        Column() {
          this.infoRow('当前组织', workspaceTitle(this.snapshot))
          this.infoRow('组织角色', this.snapshot.context?.tenantRole || '-')
          this.infoRow('组织状态', this.snapshot.context?.tenantStatus || '-')
        }
        .width('100%')
        .padding({ left: 14, right: 14 })
        .backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.border })
        .borderRadius(8)

        Text('账号与应用')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.muted)
          .width('100%')
          .margin({ top: 24, bottom: 8 })

        Column() {
          this.linkRow(
            '个人资料',
            '昵称、联系方式与部门',
            $r('sys.symbol.person'),
            'pages/ProfilePage'
          )
          this.linkRow(
            '通知',
            '安全、服务与账号消息',
            $r('sys.symbol.bell'),
            'pages/NoticeListPage'
          )
          this.linkRow(
            '账号安全',
            '密码、二次验证与登录设备',
            $r('sys.symbol.lock'),
            'pages/SecurityPage'
          )
          this.linkRow(
            '社交身份',
            '查看绑定状态',
            $r('sys.symbol.person'),
            'pages/SocialIdentitiesPage'
          )
          if (isPlatformWorkspace(this.snapshot)) {
            this.linkRow(
              '组织管理',
              '选择需要管理的组织',
              $r('sys.symbol.grid'),
              '',
              'ORGANIZATIONS'
            )
          }
          if (hasTenantWorkspace(this.snapshot)) {
            this.linkRow(
              '连接记录',
              canReadAdminWorkspace(this.snapshot) ? '查看当前组织连接' : '查看我的连接',
              $r('sys.symbol.ohos_wifi'),
              this.snapshot.role === 2 ? '' : 'pages/SessionListPage',
              'CONNECTIONS'
            )
          }
          this.linkRow(
            '外观',
            '跟随系统、浅色或深色',
            $r('sys.symbol.cloud'),
            'pages/AppearancePage'
          )
          this.linkRow(
            '环境',
            this.previewMode ? '本地演示与场景重置' : 'Gateway 与运行环境',
            $r('sys.symbol.gearshape'),
            'pages/EnvironmentPage'
          )
        }
        .width('100%')
        .backgroundColor(AppTheme.surface)
        .border({ width: 1, color: AppTheme.border })
        .borderRadius(8)

        if (isManagedTenantWorkspace(this.snapshot)) {
          Button(this.contextSwitching ? '正在返回' : '返回系统管理')
            .enabled(!this.contextSwitching)
            .width('100%')
            .height(48)
            .fontSize(14)
            .fontColor(AppTheme.primary)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.primary })
            .borderRadius(8)
            .margin({ top: 18 })
            .onClick(() => this.returnToPlatform())
        }

        if (this.accountError.length > 0) {
          Text(this.accountError)
            .fontSize(13)
            .fontColor(AppTheme.dangerText)
            .width('100%')
            .margin({ top: 12 })
        }

        Button(this.loggingOut ? '正在退出' : '退出登录')
          .enabled(!this.loggingOut)
          .width('100%')
          .height(48)
          .fontSize(14)
          .fontColor(AppTheme.dangerText)
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border })
          .borderRadius(8)
          .margin({ top: 18 })
          .onClick(() => this.logout())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 28 })
    }
    .layoutWeight(1)
    .width('100%')
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

  @Builder
  private linkRow(
    label: string,
    description: string,
    icon: Resource,
    url: string,
    tabKey: MainTabKey = 'HOME'
  ) {
    Row() {
      SymbolGlyph(icon)
        .fontSize(21)
        .fontColor([AppTheme.textSoft])
        .width(34)
      Column({ space: 3 }) {
        Text(label)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.text)
        Text(description)
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
    .onClick(() => {
      if (url.length > 0) {
        router.pushUrl({ url: url })
      } else {
        this.selectTabByKey(tabKey)
      }
    })
  }

  @Builder
  private tabButton(tab: MainTab, index: number) {
    Column({ space: 3 }) {
      Rect()
        .width(24)
        .height(2)
        .fill(this.selectedTab === index ? AppTheme.primary : Color.Transparent)
      SymbolGlyph(this.tabIcon(tab.key))
        .fontSize(23)
        .fontColor([this.selectedTab === index ? AppTheme.primary : AppTheme.muted])
      Text(tab.label)
        .fontSize(11)
        .fontWeight(this.selectedTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.selectedTab === index ? AppTheme.primary : AppTheme.muted)
    }
    .layoutWeight(1)
    .height(64)
    .justifyContent(FlexAlign.Center)
    .onClick(() => this.selectTab(index))
  }
}
