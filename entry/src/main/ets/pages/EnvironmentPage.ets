import router from '@ohos.router'
import { DEBUG } from 'BuildProfile'
import { Hm2DemoScenario } from '../model/Hm2Models'
import { accountRepositoryFactory } from '../repository/AccountRepository'
import { platformAdminRepositoryFactory } from '../repository/PlatformAdminRepository'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { RuntimeMode, runtimeModeStore } from '../preview/RuntimeMode'
import { runtimeSettings } from '../storage/RuntimeSettings'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

@Entry
@Component
struct EnvironmentPage {
  @State gatewayUrl: string = ''
  @State saving: boolean = false
  @State message: string = ''
  @State error: string = ''
  @State hm2Scenario: Hm2DemoScenario = 'NORMAL'

  aboutToAppear(): void {
    this.gatewayUrl = runtimeSettings.getGatewayUrl()
    if (runtimeModeStore.isDemo()) {
      this.hm2Scenario = platformAdminRepositoryFactory.current().demoScenario()
      repositoryFactory.setDemoScenario(this.hm2Scenario)
    }
  }

  private scenarioLabel(): string {
    if (this.hm2Scenario === 'EMPTY') return '空数据'
    if (this.hm2Scenario === 'FILTER_EMPTY') return '筛选无结果'
    if (this.hm2Scenario === 'LOADING') return '延迟加载'
    if (this.hm2Scenario === 'PARTIAL_FAILURE') return '局部失败'
    if (this.hm2Scenario === 'FORBIDDEN') return '无权限'
    if (this.hm2Scenario === 'CONFLICT') return '状态冲突'
    if (this.hm2Scenario === 'RATE_LIMITED') return '请求限流'
    if (this.hm2Scenario === 'DEPENDENCY_DOWN') return '依赖不可用'
    return '正常'
  }

  private selectNextScenario(): void {
    const scenarios: Hm2DemoScenario[] = [
      'NORMAL',
      'EMPTY',
      'FILTER_EMPTY',
      'LOADING',
      'PARTIAL_FAILURE',
      'FORBIDDEN',
      'CONFLICT',
      'RATE_LIMITED',
      'DEPENDENCY_DOWN'
    ]
    const current = scenarios.indexOf(this.hm2Scenario)
    const next = scenarios[(current + 1) % scenarios.length]
    platformAdminRepositoryFactory.current().setDemoScenario(next)
    repositoryFactory.setDemoScenario(next)
    this.hm2Scenario = next
    this.message = `Demo 场景已切换为${this.scenarioLabel()}`
    this.error = ''
  }

  private async saveGateway(): Promise<void> {
    if (!DEBUG || runtimeModeStore.getMode() !== RuntimeMode.REAL) {
      return
    }
    this.saving = true
    this.message = ''
    this.error = ''
    try {
      await runtimeSettings.setGatewayUrl(this.gatewayUrl)
      this.gatewayUrl = runtimeSettings.getGatewayUrl()
      this.message = 'Gateway 地址已保存'
    } catch (error) {
      this.error = error instanceof Error ? error.message : 'Gateway 地址保存失败'
    } finally {
      this.saving = false
    }
  }

  private confirmResetDemo(): void {
    AlertDialog.show({
      title: '重置本地演示',
      message: '通知、资料、社交身份和安全会话将恢复初始状态。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '重置',
        fontColor: AppTheme.dangerText,
        action: () => this.resetDemo()
      }
    })
  }

  private async resetDemo(): Promise<void> {
    this.message = ''
    this.error = ''
    try {
      await accountRepositoryFactory.current().resetDemo()
      await platformAdminRepositoryFactory.current().resetDemo()
      await repositoryFactory.resetDemoTenantOps()
      await sessionStore.resetDemoSession()
      runtimeModeStore.resetNetworkSentinel()
      this.hm2Scenario = 'NORMAL'
      this.message = '本地演示已重置'
    } catch (error) {
      this.error = error instanceof Error ? error.message : '本地演示重置失败'
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
        Text('环境')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.text)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 12 })

      Scroll() {
        Column() {
          Text('运行模式')
            .fontSize(13)
            .fontColor(AppTheme.muted)
            .width('100%')
            .margin({ bottom: 8 })
          Row({ space: 12 }) {
            Circle()
              .width(10)
              .height(10)
              .fill(runtimeModeStore.isDemo() ? AppTheme.info : AppTheme.success)
            Column({ space: 4 }) {
              Text(runtimeModeStore.isDemo() ? '本地演示' : '真实环境')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.text)
              Text(runtimeModeStore.isDemo()
                ? '使用独立本地数据空间'
                : (DEBUG ? '开发构建' : '生产构建'))
                .fontSize(12)
                .fontColor(AppTheme.muted)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .height(76)
          .padding({ left: 14, right: 14 })
          .backgroundColor(AppTheme.surface)
          .border({ width: 1, color: AppTheme.border })
          .borderRadius(8)

          if (runtimeModeStore.isDemo()) {
            Text('演示数据')
              .fontSize(13)
              .fontColor(AppTheme.muted)
              .width('100%')
              .margin({ top: 24, bottom: 8 })
            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text('平台场景')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.text)
                Text(this.scenarioLabel())
                  .fontSize(12)
                  .fontColor(AppTheme.muted)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Button('切换')
                .height(44)
                .fontSize(13)
                .fontColor(AppTheme.primary)
                .backgroundColor(AppTheme.surfaceMuted)
                .borderRadius(6)
                .onClick(() => this.selectNextScenario())
            }
            .width('100%')
            .height(64)
            .padding({ left: 14, right: 12 })
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)
            .margin({ bottom: 10 })
            Button('重置本地演示')
              .width('100%')
              .height(48)
              .fontSize(14)
              .fontColor(AppTheme.dangerText)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)
              .onClick(() => this.confirmResetDemo())
            Text(`网络哨兵：${runtimeModeStore.getBlockedNetworkAttempts()} 次阻断`)
              .fontSize(12)
              .fontColor(AppTheme.muted)
              .width('100%')
              .margin({ top: 12 })
          } else {
            Text('Gateway')
              .fontSize(13)
              .fontColor(AppTheme.muted)
              .width('100%')
              .margin({ top: 24, bottom: 8 })
            TextInput({ text: this.gatewayUrl })
              .enabled(DEBUG)
              .width('100%')
              .height(48)
              .fontSize(14)
              .fontColor(DEBUG ? AppTheme.text : AppTheme.muted)
              .backgroundColor(DEBUG ? AppTheme.surface : AppTheme.surfaceMuted)
              .border({ width: 1, color: AppTheme.borderStrong })
              .borderRadius(8)
              .onChange((value: string) => this.gatewayUrl = value)
            if (DEBUG) {
              Button(this.saving ? '保存中' : '保存 Gateway')
                .enabled(!this.saving)
                .width('100%')
                .height(48)
                .fontSize(14)
                .fontColor(AppTheme.primaryText)
                .backgroundColor(AppTheme.primaryStrong)
                .borderRadius(8)
                .margin({ top: 12 })
                .onClick(() => this.saveGateway())
            }
          }

          if (this.message.length > 0) {
            Text(this.message)
              .fontSize(13)
              .fontColor(AppTheme.successText)
              .width('100%')
              .margin({ top: 16 })
          }
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
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.background)
  }
}
