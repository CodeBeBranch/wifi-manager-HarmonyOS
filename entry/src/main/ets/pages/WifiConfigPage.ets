import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { DeviceNode } from '../model/DeviceModels'
import {
  WifiConfigPollState,
  WifiConfigTask,
  isWifiConfigTerminal,
  validateWifiCredentials,
  wifiConfigStatusLabel
} from '../model/WifiConfigModels'
import { wifiConfigPoller } from '../network/WifiConfigPoller'
import { deviceRepository } from '../repository/DeviceRepository'
import { wifiConfigRepository } from '../repository/WifiConfigRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface WifiConfigParams {
  nodeId: string
}

@Entry
@Component
struct WifiConfigPage {
  @State nodeId: string = ''
  @State device: DeviceNode | null = null
  @State writable: boolean = false
  @State loading: boolean = true
  @State submitting: boolean = false
  @State confirming: boolean = false
  @State ssid: string = ''
  @State password: string = ''
  @State passwordVisible: boolean = false
  @State task: WifiConfigTask | null = null
  @State pollState: WifiConfigPollState = 'idle'
  @State pollAttempt: number = 0
  @State errorMessage: string = ''
  @State successMessage: string = ''
  private pageVersion: number = 0
  private loadRequestVersion: number = 0
  private submitRequestVersion: number = 0

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const contextType = snapshot.context?.contextType ?? ''
    const admin = snapshot.role === 0 || snapshot.role === 1
    if (!snapshot.authenticated || !admin ||
      (contextType !== 'TENANT' && contextType !== 'PLATFORM_TENANT')) {
      router.replaceUrl({ url: 'pages/WorkspacePage' })
      return
    }

    const params = router.getParams() as WifiConfigParams | null
    this.nodeId = params?.nodeId?.trim() ?? ''
    this.writable = snapshot.context?.writable ?? false
    if (!/^[1-9]\d{0,18}$/.test(this.nodeId)) {
      this.loading = false
      this.errorMessage = '设备编号无效'
      return
    }
    this.load()
  }

  aboutToDisappear(): void {
    this.pageVersion += 1
    this.loadRequestVersion += 1
    this.submitRequestVersion += 1
    this.clearCredentials()
    this.submitting = false
    wifiConfigPoller.stop()
  }

  onPageHide(): void {
    this.clearCredentials()
  }

  private clearCredentials(): void {
    this.password = ''
    this.passwordVisible = false
    this.confirming = false
  }

  private async load(): Promise<void> {
    if (this.loading && this.device !== null) return
    const pageVersion = this.pageVersion
    const requestVersion = ++this.loadRequestVersion
    wifiConfigPoller.stop()
    this.loading = true
    this.errorMessage = ''
    this.successMessage = ''
    this.pollState = 'idle'
    this.pollAttempt = 0
    try {
      const device = await deviceRepository.detail(this.nodeId)
      if (pageVersion !== this.pageVersion ||
        requestVersion !== this.loadRequestVersion) return
      if (!Number.isInteger(device.nodeId) || String(device.nodeId) !== this.nodeId ||
        typeof device.deviceCode !== 'string' || device.deviceCode.trim().length === 0 ||
        device.deviceCode.length > 64 ||
        (device.status !== 0 && device.status !== 1)) {
        throw new ApiError('设备详情响应无效', 502, 502, 'DEPENDENCY_PROTOCOL_INVALID')
      }
      this.device = device

      const latest = await wifiConfigRepository.latest(device.deviceCode)
      if (pageVersion !== this.pageVersion ||
        requestVersion !== this.loadRequestVersion ||
        this.device?.deviceCode !== device.deviceCode) return
      this.task = latest
      if (latest !== null && !isWifiConfigTerminal(latest.status)) {
        this.startPolling(latest.requestId)
      } else if (latest !== null) {
        this.pollState = 'terminal'
      }
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        router.replaceUrl({ url: 'pages/LoginPage' })
        return
      }
      if (pageVersion !== this.pageVersion ||
        requestVersion !== this.loadRequestVersion) return
      this.errorMessage = error instanceof ApiError ? error.message : 'WiFi 配置加载失败'
    } finally {
      if (pageVersion === this.pageVersion &&
        requestVersion === this.loadRequestVersion) {
        this.loading = false
      }
    }
  }

  private unavailableReason(): string {
    if (!this.writable) return '当前工作区为只读状态'
    if (this.device === null) return '设备信息尚未加载'
    if (this.device.status !== 1) return '设备当前离线，不能下发上游 WiFi 配置'
    return ''
  }

  private validateForm(): string {
    const unavailable = this.unavailableReason()
    if (unavailable.length > 0) return unavailable
    return validateWifiCredentials(this.ssid, this.password)
  }

  private beginConfirm(): void {
    if (this.submitting) return
    const validation = this.validateForm()
    if (validation.length > 0) {
      this.errorMessage = validation
      return
    }
    this.errorMessage = ''
    this.successMessage = ''
    this.confirming = true
  }

  private async submit(): Promise<void> {
    if (!this.confirming || this.submitting || this.device === null) return
    const validation = this.validateForm()
    if (validation.length > 0) {
      this.confirming = false
      this.errorMessage = validation
      return
    }

    const pageVersion = this.pageVersion
    const requestVersion = ++this.submitRequestVersion
    const deviceCode = this.device.deviceCode
    const ssid = this.ssid.trim()
    const password = this.password
    this.submitting = true
    this.errorMessage = ''
    this.successMessage = ''
    try {
      const request = wifiConfigRepository.stage(deviceCode, ssid, password)
      this.clearCredentials()
      const task = await request
      if (pageVersion !== this.pageVersion ||
        requestVersion !== this.submitRequestVersion ||
        this.device?.deviceCode !== deviceCode) return

      this.task = task
      this.ssid = task.ssid
      this.submitting = false
      if (isWifiConfigTerminal(task.status)) {
        this.pollState = 'terminal'
        this.applyTerminalMessage(task)
      } else {
        this.successMessage = `WiFi 修改请求已提交，操作编号：${task.requestId}`
        this.startPolling(task.requestId)
      }
    } catch (error) {
      this.clearCredentials()
      if (error instanceof ApiError && error.httpStatus === 401) {
        router.replaceUrl({ url: 'pages/LoginPage' })
        return
      }
      if (pageVersion !== this.pageVersion ||
        requestVersion !== this.submitRequestVersion) return
      this.errorMessage = error instanceof ApiError ? error.message : 'WiFi 候选配置提交失败'
    } finally {
      if (pageVersion === this.pageVersion &&
        requestVersion === this.submitRequestVersion) {
        this.submitting = false
      }
    }
  }

  private startPolling(requestId: string): void {
    if (this.device === null) return
    wifiConfigPoller.start(
      this.device.deviceCode,
      requestId,
      (
        state: WifiConfigPollState,
        attempt: number,
        task: WifiConfigTask | null,
        error: ApiError | null
      ): void => {
        if (this.task?.requestId !== requestId) return
        this.pollState = state
        this.pollAttempt = attempt
        if (task !== null) {
          this.task = task
          this.errorMessage = ''
        }
        if (error !== null) {
          if (error.httpStatus === 401) {
            router.replaceUrl({ url: 'pages/LoginPage' })
            return
          }
          this.errorMessage = error.message
        }
        if (state === 'terminal' && task !== null) {
          this.applyTerminalMessage(task)
        } else if (state === 'exhausted') {
          this.successMessage = ''
          this.errorMessage = '暂未收到 WiFi 配置终态，请稍后手动继续查询'
        }
      }
    )
  }

  private applyTerminalMessage(task: WifiConfigTask): void {
    if (task.status === 2) {
      this.errorMessage = ''
      this.successMessage = '设备已确认新的上游 WiFi 配置生效'
    } else if (task.status === 3) {
      this.successMessage = ''
      this.errorMessage = task.failureMessage || '设备未能应用新的上游 WiFi 配置'
    } else if (task.status === 5) {
      this.successMessage = ''
      this.errorMessage = '该配置任务已被更新的候选配置替代'
    }
  }

  private pollLabel(): string {
    if (this.pollState === 'polling') return `正在查询设备结果 (${this.pollAttempt}/20)`
    if (this.pollState === 'paused') return '应用已进入后台，查询已暂停'
    if (this.pollState === 'exhausted') return '本轮查询已停止'
    if (this.pollState === 'failed') return '本次查询失败，将按计划重试'
    if (this.pollState === 'terminal') return wifiConfigStatusLabel(this.task?.status)
    return this.task === null ? '暂无配置任务' : wifiConfigStatusLabel(this.task.status)
  }

  private statusColor(status: number | null | undefined): Resource {
    if (status === 2) return AppTheme.successText
    if (status === 3) return AppTheme.dangerText
    if (status === 0 || status === 4) return AppTheme.warningText
    if (status === 1) return AppTheme.infoText
    return AppTheme.muted
  }

  private formatTime(value: string | null | undefined): string {
    return value === null || value === undefined || value.length === 0
      ? '-'
      : value.replace('T', ' ')
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button('‹')
          .width(44).height(44).fontSize(24)
          .fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
          .onClick(() => router.back())
        Column({ space: 2 }) {
          Text(this.device?.name || this.device?.deviceCode || '设备配置')
            .fontSize(11).fontColor(AppTheme.primary).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('上游 WiFi 配置').fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('刷新')
          .enabled(!this.loading && !this.submitting)
          .height(44).fontSize(13).fontColor(AppTheme.textSoft)
          .backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
          .onClick(() => this.load())
      }
      .width('100%')
      .margin({ bottom: 16 })

      if (this.loading) {
        Column({ space: 12 }) {
          LoadingProgress().width(36).height(36).color(AppTheme.primary)
          Text('正在加载 WiFi 配置').fontSize(13).fontColor(AppTheme.muted)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 14 }) {
            if (this.device !== null) {
              Row() {
                Column({ space: 4 }) {
                  Text(this.device.deviceCode)
                    .fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
                  Text(`${this.device.status === 1 ? '在线' : '离线'} · ${this.device.wifiStatus || '状态未知'}`)
                    .fontSize(12)
                    .fontColor(this.device.status === 1 ? AppTheme.successText : AppTheme.muted)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Circle()
                  .width(12).height(12)
                  .fill(this.device.status === 1 ? AppTheme.success : AppTheme.muted)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppTheme.surfaceMuted)
              .borderRadius(8)
            }

            Column({ space: 12 }) {
              Text('新的连接信息')
                .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
                .width('100%')

              Text('SSID').fontSize(12).fontColor(AppTheme.muted).width('100%')
              TextInput({ text: this.ssid, placeholder: '请输入新的 WiFi 名称' })
                .height(48)
                .maxLength(32)
                .fontSize(14)
                .fontColor(AppTheme.text)
                .placeholderColor(AppTheme.muted)
                .backgroundColor(AppTheme.surfaceRaised)
                .border({ width: 1, color: AppTheme.borderStrong })
                .borderRadius(8)
                .enabled(!this.submitting)
                .onChange((value: string) => this.ssid = value)

              Text('WiFi 密码').fontSize(12).fontColor(AppTheme.muted).width('100%')
              Row({ space: 8 }) {
                TextInput({ text: this.password, placeholder: '开放网络留空，其他网络至少 8 字节' })
                  .layoutWeight(1)
                  .height(48)
                  .maxLength(63)
                  .type(this.passwordVisible ? InputType.Normal : InputType.Password)
                  .fontSize(14)
                  .fontColor(AppTheme.text)
                  .placeholderColor(AppTheme.muted)
                  .backgroundColor(AppTheme.surfaceRaised)
                  .border({ width: 1, color: AppTheme.borderStrong })
                  .borderRadius(8)
                  .enabled(!this.submitting)
                  .onChange((value: string) => this.password = value)
                Button(this.passwordVisible ? '隐藏' : '显示')
                  .width(58).height(48).fontSize(12)
                  .fontColor(AppTheme.primary)
                  .backgroundColor(AppTheme.surfaceRaised)
                  .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
                  .enabled(!this.submitting)
                  .onClick(() => this.passwordVisible = !this.passwordVisible)
              }
              .width('100%')

              if (this.unavailableReason().length > 0) {
                Text(this.unavailableReason())
                  .fontSize(13).fontColor(AppTheme.warningText).width('100%')
              }

              if (!this.confirming) {
                Button('修改设备 WiFi')
                  .enabled(this.unavailableReason().length === 0 && !this.submitting)
                  .width('100%').height(48).fontSize(14)
                  .fontColor(AppTheme.primaryText)
                  .backgroundColor(this.unavailableReason().length === 0
                    ? AppTheme.danger : AppTheme.muted)
                  .borderRadius(8)
                  .onClick(() => this.beginConfirm())
              } else {
                Column({ space: 12 }) {
                  Text(`确认让 ${this.device?.deviceCode || '该设备'} 改为连接“${this.ssid.trim()}”吗？` +
                    '切换期间设备可能暂时离线，最终结果以设备回执为准。')
                    .fontSize(13).fontColor(AppTheme.dangerText).width('100%')
                  Row({ space: 10 }) {
                    Button('取消')
                      .enabled(!this.submitting)
                      .layoutWeight(1).height(46).fontSize(14)
                      .fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surface)
                      .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
                      .onClick(() => this.confirming = false)
                    Button(this.submitting ? '正在提交' : '确认修改')
                      .enabled(!this.submitting)
                      .layoutWeight(1).height(46).fontSize(14)
                      .fontColor(AppTheme.primaryText).backgroundColor(AppTheme.danger)
                      .borderRadius(8)
                      .onClick(() => this.submit())
                  }
                  .width('100%')
                }
                .padding(14)
                .backgroundColor(AppTheme.dangerSurface)
                .borderRadius(8)
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor(AppTheme.surface)
            .border({ width: 1, color: AppTheme.border })
            .borderRadius(8)

            if (this.errorMessage.length > 0) {
              Text(this.errorMessage)
                .fontSize(13).fontColor(AppTheme.dangerText).width('100%')
                .padding(12).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
            }
            if (this.successMessage.length > 0) {
              Text(this.successMessage)
                .fontSize(13).fontColor(AppTheme.successText).width('100%')
                .padding(12).backgroundColor(AppTheme.successSurface).borderRadius(8)
            }

            if (this.task === null) {
              Text('该设备暂无上游 WiFi 配置任务')
                .fontSize(13).fontColor(AppTheme.muted).width('100%')
                .padding(18).textAlign(TextAlign.Center)
                .backgroundColor(AppTheme.surface)
                .border({ width: 1, color: AppTheme.border }).borderRadius(8)
            } else {
              Column({ space: 10 }) {
                Row() {
                  Text('最近配置任务')
                    .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
                  Text(this.pollLabel())
                    .fontSize(12).fontColor(this.statusColor(this.task.status))
                    .layoutWeight(1).textAlign(TextAlign.End).maxLines(2)
                }
                .width('100%')
                this.taskRow('操作编号', this.task.requestId)
                this.taskRow('SSID', this.task.ssid)
                this.taskRow('使用密码', this.task.passwordConfigured ? '是' : '否')
                this.taskRow('配置版本', String(this.task.configVersion))
                this.taskRow('提交时间', this.formatTime(this.task.stagedTime || this.task.createTime))
                this.taskRow('生效时间', this.formatTime(this.task.activatedTime))
                if (this.task.failureMessage !== null && this.task.failureMessage.length > 0) {
                  this.taskRow('失败原因', this.task.failureMessage)
                }
                if (this.pollState === 'exhausted' ||
                  (!isWifiConfigTerminal(this.task.status) && this.pollState === 'idle')) {
                  Button('继续查询')
                    .height(44).fontSize(13).fontColor(AppTheme.primary)
                    .backgroundColor(AppTheme.surfaceRaised)
                    .border({ width: 1, color: AppTheme.primary }).borderRadius(8)
                    .onClick(() => this.startPolling(this.task?.requestId ?? ''))
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 16 })
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private taskRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(AppTheme.muted)
      Text(value)
        .fontSize(12).fontColor(AppTheme.textSoft).layoutWeight(1)
        .textAlign(TextAlign.End).maxLines(3)
    }
    .width('100%')
  }
}
