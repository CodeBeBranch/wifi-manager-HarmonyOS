import router from '@ohos.router'
import { resetToMain } from '../navigation/AppRouter'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface ServiceItem {
  title: string
  description: string
  route: string
}

@Component
export struct TenantServiceContent {
  @State tenantName: string = '工作区'
  @State roleLabel: string = ''

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const context = snapshot.context
    if (!snapshot.authenticated || snapshot.role > 1 ||
      context === null || (context.contextType !== 'TENANT' &&
        context.contextType !== 'PLATFORM_TENANT')) {
      resetToMain()
      return
    }
    this.tenantName = context.tenantName || '工作区'
    this.roleLabel = snapshot.role === 0 ? '平台代管' : '租户管理员'
  }

  private open(item: ServiceItem): void {
    router.pushUrl({ url: item.route })
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 4 }) {
          Text('租户运维').fontSize(11).fontColor(AppTheme.primary).width('100%')
          Text('服务').fontSize(24).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
          Text(`${this.tenantName} · ${this.roleLabel}`)
            .fontSize(13).fontColor(AppTheme.muted).width('100%')
        }
        .width('100%').alignItems(HorizontalAlign.Start)
        .margin({ bottom: 8 })

        ForEach([
          { title: '设备管理', description: '设备状态、详情和网络运行信息', route: 'pages/DeviceListPage' },
          { title: '连接会话', description: '查看当前组织的在线连接和历史会话', route: 'pages/SessionListPage' },
          { title: '设备命令', description: '提交命令并跟踪 requestId 与执行状态', route: 'pages/DeviceListPage' },
          { title: '上游 WiFi', description: '查看配置任务和设备侧执行结果', route: 'pages/DeviceListPage' },
          { title: '黑名单', description: '查看、新增和移除当前组织的黑名单记录', route: 'pages/TenantBlacklistPage' },
          { title: '告警中心', description: '查看当前组织告警和关联设备', route: 'pages/AlertListPage' }
        ] as ServiceItem[], (item: ServiceItem) => {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text(item.title).fontSize(16).fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.text)
              Text(item.description).fontSize(12).fontColor(AppTheme.muted)
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('›').fontSize(22).fontColor(AppTheme.muted)
          }
          .width('100%').padding(15).backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border }).borderRadius(6)
          .onClick(() => this.open(item))
        }, (item: ServiceItem): string => item.title)
      }
      .width('100%').padding({ left: 16, right: 16, top: 16, bottom: 24 })
    }
    .width('100%').height('100%').backgroundColor(AppTheme.background)
  }
}
