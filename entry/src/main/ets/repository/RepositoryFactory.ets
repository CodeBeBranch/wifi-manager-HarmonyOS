import { ApiError } from '../model/ApiModels'
import { AlertEvent, AlertPageResult, AlertQuery } from '../model/AlertModels'
import {
  DeviceCommandPageResult,
  DeviceCommandQuery,
  DeviceCommandRecord,
  DeviceCommandResult
} from '../model/DeviceCommandModels'
import { DeviceNode, DevicePageResult } from '../model/DeviceModels'
import { NetworkSession, SessionPageResult, SessionQuery } from '../model/SessionModels'
import { PlatformTenantPageResult } from '../model/TenantModels'
import { WifiConfigTask } from '../model/WifiConfigModels'
import {
  previewAlertDetail,
  previewAlertPage,
  previewDeviceCommandPage,
  previewDeviceDetail,
  previewDevicePage,
  previewLatestWifiConfig,
  previewSessionPage,
  previewTenantPage
} from '../preview/PreviewData'
import { runtimeModeStore } from '../preview/RuntimeMode'
import { alertRepository } from './AlertRepository'
import { deviceCommandRepository } from './DeviceCommandRepository'
import { deviceRepository } from './DeviceRepository'
import { sessionRepository } from './SessionRepository'
import { tenantRepository } from './TenantRepository'
import { wifiConfigRepository } from './WifiConfigRepository'

export interface AlertRepositoryContract {
  list(query: AlertQuery): Promise<AlertPageResult>
  detail(id: number): Promise<AlertEvent>
  handle(id: number): Promise<void>
}

export interface DeviceRepositoryContract {
  list(current: number, size: number, keyword: string): Promise<DevicePageResult>
  detail(nodeId: string): Promise<DeviceNode>
}

export interface SessionRepositoryContract {
  list(query: SessionQuery, admin: boolean): Promise<SessionPageResult>
  close(sessionId: number, admin: boolean): Promise<NetworkSession>
}

export interface TenantRepositoryContract {
  listPlatformTenants(current: number, size: number, keyword: string): Promise<PlatformTenantPageResult>
}

export interface DeviceCommandRepositoryContract {
  restart(deviceCode: string, reason: string): Promise<DeviceCommandResult>
  disconnectMac(deviceCode: string, mac: string): Promise<DeviceCommandResult>
  blockTraffic(deviceCode: string, dstIp: string, sni: string): Promise<DeviceCommandResult>
  list(query: DeviceCommandQuery): Promise<DeviceCommandPageResult>
  findByRequestId(deviceCode: string, requestId: string): Promise<DeviceCommandRecord | null>
}

export interface WifiConfigRepositoryContract {
  stage(deviceCode: string, ssid: string, password: string): Promise<WifiConfigTask>
  latest(deviceCode: string): Promise<WifiConfigTask | null>
  find(deviceCode: string, requestId: string): Promise<WifiConfigTask>
}

function demoWriteBlocked(): ApiError {
  return new ApiError(
    '当前演示阶段只展示本地状态，不会提交真实操作',
    403,
    403,
    'DEMO_OPERATION_NOT_AVAILABLE'
  )
}

class DemoAlertRepository implements AlertRepositoryContract {
  async list(query: AlertQuery): Promise<AlertPageResult> {
    return previewAlertPage(query)
  }

  async detail(id: number): Promise<AlertEvent> {
    const alert = previewAlertDetail(id)
    if (alert === null) {
      throw new ApiError('没有找到告警', 404, 404, 'ALERT_NOT_FOUND')
    }
    return alert
  }

  async handle(_id: number): Promise<void> {
    throw demoWriteBlocked()
  }
}

class DemoDeviceRepository implements DeviceRepositoryContract {
  async list(current: number, size: number, keyword: string): Promise<DevicePageResult> {
    return previewDevicePage(current, size, keyword)
  }

  async detail(nodeId: string): Promise<DeviceNode> {
    const device = previewDeviceDetail(nodeId)
    if (device === null) {
      throw new ApiError('没有找到设备', 404, 404, 'DEVICE_NOT_FOUND')
    }
    return device
  }
}

class DemoSessionRepository implements SessionRepositoryContract {
  async list(query: SessionQuery, admin: boolean): Promise<SessionPageResult> {
    return previewSessionPage(query, admin)
  }

  async close(_sessionId: number, _admin: boolean): Promise<NetworkSession> {
    throw demoWriteBlocked()
  }
}

class DemoTenantRepository implements TenantRepositoryContract {
  async listPlatformTenants(
    current: number,
    size: number,
    keyword: string
  ): Promise<PlatformTenantPageResult> {
    return previewTenantPage(current, size, keyword)
  }
}

class DemoDeviceCommandRepository implements DeviceCommandRepositoryContract {
  async restart(_deviceCode: string, _reason: string): Promise<DeviceCommandResult> {
    throw demoWriteBlocked()
  }

  async disconnectMac(_deviceCode: string, _mac: string): Promise<DeviceCommandResult> {
    throw demoWriteBlocked()
  }

  async blockTraffic(_deviceCode: string, _dstIp: string, _sni: string): Promise<DeviceCommandResult> {
    throw demoWriteBlocked()
  }

  async list(query: DeviceCommandQuery): Promise<DeviceCommandPageResult> {
    return previewDeviceCommandPage(query)
  }

  async findByRequestId(deviceCode: string, requestId: string): Promise<DeviceCommandRecord | null> {
    const page = previewDeviceCommandPage({
      current: 1,
      size: 1,
      requestId: requestId,
      deviceCode: deviceCode
    })
    return page.records.length > 0 ? page.records[0] : null
  }
}

class DemoWifiConfigRepository implements WifiConfigRepositoryContract {
  async stage(_deviceCode: string, _ssid: string, _password: string): Promise<WifiConfigTask> {
    throw demoWriteBlocked()
  }

  async latest(deviceCode: string): Promise<WifiConfigTask | null> {
    return previewLatestWifiConfig(deviceCode)
  }

  async find(deviceCode: string, requestId: string): Promise<WifiConfigTask> {
    const task = previewLatestWifiConfig(deviceCode)
    if (task === null || task.requestId !== requestId) {
      throw new ApiError('没有找到 WiFi 配置任务', 404, 404, 'WIFI_CONFIG_NOT_FOUND')
    }
    return task
  }
}

class RepositoryFactory {
  private readonly demoAlert = new DemoAlertRepository()
  private readonly demoDevice = new DemoDeviceRepository()
  private readonly demoSession = new DemoSessionRepository()
  private readonly demoTenant = new DemoTenantRepository()
  private readonly demoCommand = new DemoDeviceCommandRepository()
  private readonly demoWifi = new DemoWifiConfigRepository()

  alert(): AlertRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoAlert : alertRepository
  }

  device(): DeviceRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoDevice : deviceRepository
  }

  session(): SessionRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoSession : sessionRepository
  }

  tenant(): TenantRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoTenant : tenantRepository
  }

  deviceCommand(): DeviceCommandRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoCommand : deviceCommandRepository
  }

  wifiConfig(): WifiConfigRepositoryContract {
    return runtimeModeStore.isDemo() ? this.demoWifi : wifiConfigRepository
  }
}

export const repositoryFactory = new RepositoryFactory()
