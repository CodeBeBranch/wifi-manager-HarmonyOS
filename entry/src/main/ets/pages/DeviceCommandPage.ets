import router from '@ohos.router'
import util from '@ohos.util'
import { ApiError } from '../model/ApiModels'
import {
  DeviceCommandMode,
  DeviceCommandPollState,
  DeviceCommandRecord,
  deviceCommandStatusLabel,
  deviceCommandTypeLabel,
  isDeviceCommandTerminal,
  isValidIpv4Address,
  isValidMacAddress
} from '../model/DeviceCommandModels'
import { deviceCommandPoller } from '../network/DeviceCommandPoller'
import { deviceCommandRepository } from '../repository/DeviceCommandRepository'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface DeviceCommandParams {
  deviceCode: string
  deviceName: string
}

@Entry
@Component
struct DeviceCommandPage {
  @State deviceCode: string = ''
  @State deviceName: string = ''
  @State mode: DeviceCommandMode = 'restart'
  @State reason: string = ''
  @State mac: string = ''
  @State dstIp: string = ''
  @State sni: string = ''
  @State writable: boolean = false
  @State confirming: boolean = false
  @State submitting: boolean = false
  @State historyLoading: boolean = false
  @State history: DeviceCommandRecord[] = []
  @State currentRequestId: string = ''
  @State currentRecord: DeviceCommandRecord | null = null
  @State pollState: DeviceCommandPollState = 'idle'
  @State pollAttempt: number = 0
  @State errorMessage: string = ''
  @State successMessage: string = ''
  @State historyErrorMessage: string = ''
  private pageVersion: number = 0
  private historyRequestVersion: number = 0
  private submitRequestVersion: number = 0
  private readonly encoder: util.TextEncoder = new util.TextEncoder('utf-8')

  aboutToAppear(): void {
    const snapshot = sessionStore.getSnapshot()
    const contextType = snapshot.context?.contextType ?? ''
    const admin = snapshot.role === 0 || snapshot.role === 1
    if (!snapshot.authenticated || !admin ||
      (contextType !== 'TENANT' && contextType !== 'PLATFORM_TENANT')) {
      router.replaceUrl({ url: 'pages/WorkspacePage' })
      return
    }

    const params = router.getParams() as DeviceCommandParams | null
    this.deviceCode = params?.deviceCode?.trim() ?? ''
    this.deviceName = params?.deviceName?.trim() ?? ''
    this.writable = snapshot.context?.writable ?? false
    if (this.deviceCode.length === 0 || this.deviceCode.length > 64) {
      this.errorMessage = '设备编号无效'
      return
    }
    this.loadHistory()
  }

  aboutToDisappear(): void {
    this.pageVersion += 1
    this.historyRequestVersion += 1
    this.submitRequestVersion += 1
    this.historyLoading = false
    this.submitting = false
    deviceCommandPoller.stop()
  }

  private async loadHistory(): Promise<void> {
    if (this.deviceCode.length === 0 || this.historyLoading) return
    const pageVersion = this.pageVersion
    const requestVersion = ++this.historyRequestVersion
    this.historyLoading = true
    this.historyErrorMessage = ''
    try {
      const result = await deviceCommandRepository.list({
        current: 1,
        size: 20,
        requestId: '',
        deviceCode: this.deviceCode
      })
      if (pageVersion !== this.pageVersion ||
        requestVersion !== this.historyRequestVersion) return
      this.history = result.records
      if (this.currentRequestId.length > 0) {
        const current = this.history.find(
          (record: DeviceCommandRecord): boolean => record.requestId === this.currentRequestId
        )
        if (current !== undefined) this.currentRecord = current
      }
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        router.replaceUrl({ url: 'pages/LoginPage' })
        return
      }
      if (pageVersion !== this.pageVersion ||
        requestVersion !== this.historyRequestVersion) return
      this.historyErrorMessage = error instanceof ApiError ? error.message : '设备执行记录加载失败'
    } finally {
      if (pageVersion === this.pageVersion &&
        requestVersion === this.historyRequestVersion) {
        this.historyLoading = false
      }
    }
  }

  private changeMode(mode: DeviceCommandMode): void {
    if (this.submitting || this.mode === mode) return
    this.mode = mode
    this.confirming = false
    this.errorMessage = ''
    this.successMessage = ''
  }

  private validateForm(): string {
    if (!this.writable) return '当前工作区为只读状态'
    if (this.mode === 'restart') {
      if (this.encoder.encodeInto(this.reason.trim()).length > 255) {
        return '重启原因不能超过 255 个 UTF-8 字节'
      }
      return ''
    }
    if (this.mode === 'disconnect') {
      return isValidMacAddress(this.mac) ? '' : '请输入完整的 MAC 地址'
    }
    if (!isValidIpv4Address(this.dstIp)) return '请输入合法的 IPv4 地址'
    if (this.sni.trim().length > 255) return 'SNI 不能超过 255 个字符'
    return ''
  }

  private beginConfirm(): void {
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
    if (!this.confirming || this.submitting) return
    const validation = this.validateForm()
    if (validation.length > 0) {
      this.confirming = false
      this.errorMessage = validation
      return
    }

    const pageVersion = this.pageVersion
    const requestVersion = ++this.submitRequestVersion
    const deviceCode = this.deviceCode
    const mode = this.mode
    this.submitting = true
    this.errorMessage = ''
    try {
      const result = mode === 'restart'
        ? await deviceCommandRepository.restart(deviceCode, this.reason)
        : mode === 'disconnect'
          ? await deviceCommandRepository.disconnectMac(deviceCode, this.mac)
          : await deviceCommandRepository.blockTraffic(deviceCode, this.dstIp, this.sni)
      if (pageVersion !== this.pageVersion ||
        requestVersion !== this.submitRequestVersion ||
        deviceCode !== this.deviceCode) return

      this.confirming = false
      this.currentRequestId = result.requestId
      this.currentRecord = null
      this.pollState = 'polling'
      this.pollAttempt = 0
      this.submitting = false
      this.successMessage = `命令已提交，操作编号：${result.requestId}`
      this.startPolling(result.requestId)
      this.loadHistory()
    } catch (error) {
      if (error instanceof ApiError && error.httpStatus === 401) {
        router.replaceUrl({ url: 'pages/LoginPage' })
        return
      }
      if (pageVersion !== this.pageVersion ||
        requestVersion !== this.submitRequestVersion) return
      this.errorMessage = error instanceof ApiError ? error.message : '设备命令提交失败'
    } finally {
      if (pageVersion === this.pageVersion &&
        requestVersion === this.submitRequestVersion) {
        this.submitting = false
      }
    }
  }

  private startPolling(requestId: string): void {
    deviceCommandPoller.start(
      this.deviceCode,
      requestId,
      (
        state: DeviceCommandPollState,
        attempt: number,
        record: DeviceCommandRecord | null,
        error: ApiError | null
      ): void => {
        if (requestId !== this.currentRequestId) return
        this.pollState = state
        this.pollAttempt = attempt
        if (record !== null) {
          this.currentRecord = record
          this.mergeRecord(record)
        }
        if (error !== null) {
          if (error.httpStatus === 401) {
            router.replaceUrl({ url: 'pages/LoginPage' })
            return
          }
          this.errorMessage = error.message
        }
        if (state === 'terminal' && record !== null) {
          if (record.status === 2) {
            this.errorMessage = ''
            this.successMessage = '设备已确认命令执行成功'
          } else {
            this.successMessage = ''
            this.errorMessage = `设备命令已结束：${deviceCommandStatusLabel(record.status)}`
          }
          this.loadHistory()
        } else if (state === 'exhausted') {
          this.errorMessage = '暂未收到设备终态，请稍后手动继续查询'
        }
      }
    )
  }

  private mergeRecord(record: DeviceCommandRecord): void {
    const next: DeviceCommandRecord[] = []
    let replaced = false
    this.history.forEach((item: DeviceCommandRecord): void => {
      if (item.requestId === record.requestId) {
        next.push(record)
        replaced = true
      } else {
        next.push(item)
      }
    })
    if (!replaced) next.unshift(record)
    this.history = next
  }

  private selectRecord(record: DeviceCommandRecord): void {
    this.currentRequestId = record.requestId
    this.currentRecord = record
    this.errorMessage = ''
    this.successMessage = ''
    if (!isDeviceCommandTerminal(record.status)) {
      this.startPolling(record.requestId)
    } else {
      deviceCommandPoller.stop()
      this.pollState = 'terminal'
      this.pollAttempt = 0
    }
  }

  private actionTitle(): string {
    if (this.mode === 'restart') return '重启设备'
    if (this.mode === 'disconnect') return '断开联网终端'
    return '阻断目标流量'
  }

  private pollLabel(): string {
    if (this.pollState === 'polling') return `正在查询设备结果 (${this.pollAttempt}/20)`
    if (this.pollState === 'paused') return '应用已进入后台，查询已暂停'
    if (this.pollState === 'exhausted') return '本轮查询已停止'
    if (this.pollState === 'failed') return '本次查询失败，将按计划重试'
    if (this.pollState === 'terminal') return deviceCommandStatusLabel(this.currentRecord?.status)
    return '未开始查询'
  }

  private statusColor(status: number | null | undefined): Resource {
    if (status === 2) return AppTheme.successText
    if (status === 3 || status === 4) return AppTheme.dangerText
    if (status === 0 || status === 5) return AppTheme.warningText
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
          Text(this.deviceName || this.deviceCode)
            .fontSize(11).fontColor(AppTheme.primary).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('设备控制').fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('刷新')
          .height(44).fontSize(13).fontColor(AppTheme.textSoft)
          .backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
          .onClick(() => this.loadHistory())
      }
      .width('100%')
      .margin({ bottom: 16 })

      Scroll() {
        Column({ space: 14 }) {
          Row({ space: 6 }) {
            this.modeButton('restart', '重启设备')
            this.modeButton('disconnect', '断开终端')
            this.modeButton('block', '阻断流量')
          }
          .width('100%')
          .padding(4)
          .backgroundColor(AppTheme.surfaceMuted)
          .borderRadius(8)

          Column({ space: 12 }) {
            Text(this.actionTitle())
              .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
              .width('100%')

            if (this.mode === 'restart') {
              TextArea({ text: this.reason, placeholder: '重启原因（选填）' })
                .height(88)
                .maxLength(255)
                .fontSize(14)
                .fontColor(AppTheme.text)
                .placeholderColor(AppTheme.muted)
                .backgroundColor(AppTheme.surfaceRaised)
                .border({ width: 1, color: AppTheme.borderStrong })
                .borderRadius(8)
                .onChange((value: string) => this.reason = value)
            } else if (this.mode === 'disconnect') {
              TextInput({ text: this.mac, placeholder: 'AA:BB:CC:DD:EE:FF' })
                .height(48)
                .maxLength(17)
                .fontSize(14)
                .fontColor(AppTheme.text)
                .placeholderColor(AppTheme.muted)
                .backgroundColor(AppTheme.surfaceRaised)
                .border({ width: 1, color: AppTheme.borderStrong })
                .borderRadius(8)
                .onChange((value: string) => this.mac = value.toUpperCase())
            } else {
              TextInput({ text: this.dstIp, placeholder: '目标 IPv4 地址' })
                .height(48)
                .maxLength(15)
                .fontSize(14)
                .fontColor(AppTheme.text)
                .placeholderColor(AppTheme.muted)
                .backgroundColor(AppTheme.surfaceRaised)
                .border({ width: 1, color: AppTheme.borderStrong })
                .borderRadius(8)
                .onChange((value: string) => this.dstIp = value)
              TextInput({ text: this.sni, placeholder: 'SNI（选填）' })
                .height(48)
                .maxLength(255)
                .fontSize(14)
                .fontColor(AppTheme.text)
                .placeholderColor(AppTheme.muted)
                .backgroundColor(AppTheme.surfaceRaised)
                .border({ width: 1, color: AppTheme.borderStrong })
                .borderRadius(8)
                .onChange((value: string) => this.sni = value)
            }

            if (!this.writable) {
              Text('当前工作区为只读状态，设备控制不可用')
                .fontSize(13).fontColor(AppTheme.warningText).width('100%')
            }

            if (!this.confirming) {
              Button('提交命令')
                .enabled(this.writable && !this.submitting)
                .width('100%').height(48).fontSize(14)
                .fontColor(AppTheme.primaryText)
                .backgroundColor(this.writable ? AppTheme.danger : AppTheme.muted)
                .borderRadius(8)
                .onClick(() => this.beginConfirm())
            } else {
              Column({ space: 12 }) {
                Text(`确认向 ${this.deviceCode} 提交“${this.actionTitle()}”吗？最终结果以设备回执为准。`)
                  .fontSize(13).fontColor(AppTheme.dangerText).width('100%')
                Row({ space: 10 }) {
                  Button('取消')
                    .enabled(!this.submitting)
                    .layoutWeight(1).height(46).fontSize(14)
                    .fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surface)
                    .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
                    .onClick(() => this.confirming = false)
                  Button(this.submitting ? '正在提交' : '确认提交')
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

          if (this.currentRequestId.length > 0) {
            Column({ space: 8 }) {
              Row() {
                Text('当前命令').fontSize(12).fontColor(AppTheme.muted)
                Text(this.pollLabel())
                  .fontSize(12)
                  .fontColor(this.statusColor(this.currentRecord?.status))
                  .layoutWeight(1)
                  .textAlign(TextAlign.End)
                  .maxLines(2)
              }
              .width('100%')
              Text(this.currentRequestId)
                .fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
                .width('100%').maxLines(2)
              if (this.currentRecord !== null && this.currentRecord.resultMessage !== null) {
                Text(this.currentRecord.resultMessage)
                  .fontSize(13).fontColor(AppTheme.textSoft).width('100%').maxLines(3)
              }
              if (this.pollState === 'exhausted' ||
                (this.currentRecord !== null && !isDeviceCommandTerminal(this.currentRecord.status) &&
                  this.pollState === 'idle')) {
                Button('继续查询')
                  .height(44).fontSize(13).fontColor(AppTheme.primary)
                  .backgroundColor(AppTheme.surfaceRaised)
                  .border({ width: 1, color: AppTheme.primary }).borderRadius(8)
                  .onClick(() => this.startPolling(this.currentRequestId))
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.surfaceMuted)
            .borderRadius(8)
          }

          Row() {
            Text('最近执行记录')
              .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
            Text(this.historyLoading ? '加载中' : `${this.history.length} 条`)
              .fontSize(12).fontColor(AppTheme.muted)
              .layoutWeight(1).textAlign(TextAlign.End)
          }
          .width('100%')

          if (this.historyErrorMessage.length > 0) {
            Text(this.historyErrorMessage)
              .fontSize(13).fontColor(AppTheme.dangerText).width('100%')
              .padding(12).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
          }

          if (!this.historyLoading && this.history.length === 0) {
            Text('暂无设备执行记录')
              .fontSize(13).fontColor(AppTheme.muted).width('100%')
              .padding(18).textAlign(TextAlign.Center)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border }).borderRadius(8)
          } else {
            ForEach(this.history, (record: DeviceCommandRecord) => {
              Column({ space: 7 }) {
                Row() {
                  Text(deviceCommandTypeLabel(record.commandType, record.purpose))
                    .fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.text)
                  Text(deviceCommandStatusLabel(record.status))
                    .fontSize(12).fontColor(this.statusColor(record.status))
                    .layoutWeight(1).textAlign(TextAlign.End)
                }
                .width('100%')
                Text(record.requestId)
                  .fontSize(11).fontColor(AppTheme.muted).width('100%').maxLines(2)
                Row() {
                  Text(this.formatTime(record.resultTime || record.publishTime || record.createTime))
                    .fontSize(12).fontColor(AppTheme.textSoft)
                  if (!isDeviceCommandTerminal(record.status)) {
                    Text('继续查询')
                      .fontSize(12).fontColor(AppTheme.primary)
                      .layoutWeight(1).textAlign(TextAlign.End)
                  }
                }
                .width('100%')
                if (record.resultMessage !== null && record.resultMessage.length > 0) {
                  Text(record.resultMessage)
                    .fontSize(12).fontColor(AppTheme.textSoft).width('100%').maxLines(2)
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.border })
              .borderRadius(8)
              .onClick(() => this.selectRecord(record))
            }, (record: DeviceCommandRecord): string => `${record.commandId}-${record.requestId}`)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 16 })
    .backgroundColor(AppTheme.background)
  }

  @Builder
  private modeButton(mode: DeviceCommandMode, label: string) {
    Button(label)
      .layoutWeight(1)
      .height(44)
      .fontSize(12)
      .fontColor(this.mode === mode ? AppTheme.primaryText : AppTheme.textSoft)
      .backgroundColor(this.mode === mode ? AppTheme.primaryStrong : Color.Transparent)
      .borderRadius(6)
      .onClick(() => this.changeMode(mode))
  }
}
