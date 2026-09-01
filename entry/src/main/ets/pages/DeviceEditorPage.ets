import router from '@ohos.router'
import { ApiError } from '../model/ApiModels'
import { DeviceEditInput } from '../model/Hm3Models'
import { repositoryFactory } from '../repository/RepositoryFactory'
import { sessionStore } from '../session/SessionStore'
import { AppTheme } from '../ui/AppTheme'

interface DeviceEditorParams {
  nodeId: string
}

@Entry
@Component
struct DeviceEditorPage {
  @State nodeId: string = ''
  @State deviceCode: string = ''
  @State name: string = ''
  @State location: string = ''
  @State ip: string = ''
  @State maxClients: string = '32'
  @State loading: boolean = false
  @State saving: boolean = false
  @State errorMessage: string = ''

  aboutToAppear(): void {
    const context = sessionStore.getSnapshot().context
    if (context === null || !context.authorities.includes('DEVICE_WRITE')) {
      router.back()
      return
    }
    const params = router.getParams() as DeviceEditorParams | null
    this.nodeId = params?.nodeId ?? ''
    if (this.nodeId.length > 0) this.load()
  }

  private async load(): Promise<void> {
    this.loading = true
    try {
      const device = await repositoryFactory.device().detail(this.nodeId)
      this.deviceCode = device.deviceCode
      this.name = device.name
      this.location = device.location
      this.ip = device.ip
      this.maxClients = String(device.maxClients)
    } catch (error) {
      this.errorMessage = error instanceof Error ? error.message : '设备加载失败'
    } finally {
      this.loading = false
    }
  }

  private validation(): string {
    if (!/^[A-Za-z0-9][A-Za-z0-9._-]{2,63}$/.test(this.deviceCode.trim())) {
      return '设备编码需为 3 到 64 位字母、数字、点、横线或下划线'
    }
    if (this.name.trim().length < 2 || this.name.trim().length > 64) {
      return '设备名称需为 2 到 64 个字符'
    }
    const count = Number(this.maxClients)
    if (!Number.isInteger(count) || count < 1 || count > 512) {
      return '最大连接数需为 1 到 512'
    }
    return ''
  }

  private async save(): Promise<void> {
    const validation = this.validation()
    if (validation.length > 0) {
      this.errorMessage = validation
      return
    }
    const input: DeviceEditInput = {
      deviceCode: this.deviceCode,
      name: this.name,
      location: this.location,
      ip: this.ip,
      maxClients: Number(this.maxClients)
    }
    this.saving = true
    this.errorMessage = ''
    try {
      if (this.nodeId.length > 0) {
        const device = await repositoryFactory.device().update(this.nodeId, input)
        router.back()
        await new Promise<void>((resolve: () => void): void => {
          setTimeout(resolve, 150)
        })
        await router.replaceUrl({
          url: 'pages/DeviceDetail',
          params: { nodeId: String(device.nodeId) }
        })
      } else {
        const device = await repositoryFactory.device().create(input)
        router.replaceUrl({
          url: 'pages/DeviceDetail',
          params: { nodeId: String(device.nodeId) }
        })
      }
    } catch (error) {
      this.errorMessage = error instanceof ApiError ? error.message : '设备保存失败'
    } finally {
      this.saving = false
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button('‹').accessibilityText('返回').width(44).height(44).fontSize(24)
          .fontColor(AppTheme.textSoft).backgroundColor(AppTheme.surfaceRaised)
          .border({ width: 1, color: AppTheme.border }).borderRadius(8)
          .onClick(() => router.back())
        Text(this.nodeId.length > 0 ? '编辑设备' : '创建设备')
          .fontSize(23).fontWeight(FontWeight.Bold).fontColor(AppTheme.text).layoutWeight(1)
      }
      .width('100%').margin({ bottom: 18 })

      if (this.loading) {
        LoadingProgress().width(36).height(36).color(AppTheme.primary).layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            TextInput({ text: this.deviceCode, placeholder: '设备编码' })
              .height(48).fontSize(14).backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
              .onChange((value: string) => this.deviceCode = value.toUpperCase())
            TextInput({ text: this.name, placeholder: '设备名称' })
              .height(48).fontSize(14).backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
              .onChange((value: string) => this.name = value)
            TextInput({ text: this.location, placeholder: '位置（选填）' })
              .height(48).fontSize(14).backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
              .onChange((value: string) => this.location = value)
            TextInput({ text: this.ip, placeholder: 'IP 地址（选填）' })
              .height(48).fontSize(14).backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
              .onChange((value: string) => this.ip = value)
            TextInput({ text: this.maxClients, placeholder: '最大连接数' })
              .type(InputType.Number).height(48).fontSize(14).backgroundColor(AppTheme.surface)
              .border({ width: 1, color: AppTheme.borderStrong }).borderRadius(8)
              .onChange((value: string) => this.maxClients = value)
            if (this.errorMessage.length > 0) {
              Text(this.errorMessage).fontSize(13).fontColor(AppTheme.dangerText)
                .width('100%').padding(12).backgroundColor(AppTheme.dangerSurface).borderRadius(8)
            }
            Button(this.saving ? '正在保存' : '保存设备')
              .enabled(!this.saving).width('100%').height(48).fontSize(14)
              .fontColor(AppTheme.primaryText).backgroundColor(AppTheme.primaryStrong)
              .borderRadius(8).onClick(() => this.save())
          }
          .width('100%')
        }
        .layoutWeight(1)
      }
    }
    .width('100%').height('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 16 })
    .backgroundColor(AppTheme.background)
  }
}
