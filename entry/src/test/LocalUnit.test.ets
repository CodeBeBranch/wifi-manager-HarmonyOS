import { describe, it, expect } from '@ohos/hypium'
import http from '@ohos.net.http'
import {
  buildAlertWebSocketUrl,
  normalizeGatewayUrl
} from '../main/ets/config/RuntimeConfig'
import {
  configuredDefaultGatewayUrl,
  realApiPath,
  resolveRealApiPath
} from '../main/ets/config/RealApiCatalog'
import { ApiError } from '../main/ets/model/ApiModels'
import {
  AlertEvent,
  AlertPageResult,
  AlertQuery,
  alertReconnectDelay,
  parseAlertSocketMessage
} from '../main/ets/model/AlertModels'
import {
  AuthResult,
  RegisterResult,
  SessionSnapshot,
  isEmailContact,
  isPhoneContact,
  isValidContact,
  isValidVerifyCode,
  validateAccountPassword,
  validateUsername
} from '../main/ets/model/AuthModels'
import { DeviceNode, DevicePageResult } from '../main/ets/model/DeviceModels'
import {
  DeviceCommandPageResult,
  DeviceCommandResult,
  deviceCommandStatusLabel,
  isDeviceCommandTerminal,
  isValidDeviceCommandRequestId,
  isValidIpv4Address,
  isValidMacAddress
} from '../main/ets/model/DeviceCommandModels'
import {
  WifiConfigTask,
  isValidWifiConfigRequestId,
  isWifiConfigTerminal,
  utf8ByteLength,
  validateWifiCredentials,
  wifiConfigStatusLabel
} from '../main/ets/model/WifiConfigModels'
import { NetworkSession, SessionPageResult } from '../main/ets/model/SessionModels'
import { PlatformTenantPageResult } from '../main/ets/model/TenantModels'
import { SaasPlanInput, TenantCreateInput } from '../main/ets/model/Hm2Models'
import {
  DemoHm4SecurityRepository,
  RealHm4SecurityRepository
} from '../main/ets/repository/Hm4SecurityRepository'
import {
  DemoHm5MemberRepository,
  RealHm5MemberRepository,
  mapHm5Entitlement,
  mapHm5Order,
  mapHm5Product,
  mapHm5Refund
} from '../main/ets/repository/Hm5MemberRepository'
import {
  DemoHm6LocationRepository,
  RealHm6LocationRepository,
  mapHm6Geofence,
  mapHm6GeofenceEvent,
  mapHm6Location
} from '../main/ets/repository/Hm6LocationRepository'
import {
  DemoHm7CapabilityRepository,
  RealHm7CapabilityRepository,
  realHm7CapabilityRoute
} from '../main/ets/repository/Hm7CapabilityRepository'
import { Hm7RequestContext } from '../main/ets/model/Hm7Models'
import { DemoAlertEventSource } from '../main/ets/preview/DemoAlertEventSource'
import { DemoTenantOpsRepository } from '../main/ets/repository/TenantOpsRepository'
import { DemoTenantDataRepository } from '../main/ets/repository/DemoTenantDataRepository'
import {
  MainRootRouteHandoff,
  MainRootRouteNotifier,
  mainRootRouteFromParams,
  resolveNoticeTargetRoute
} from '../main/ets/navigation/AppRouter'
import {
  executeWorkspaceTransition,
  isWorkspaceTransitionActive,
  WorkspaceTransitionPlan
} from '../main/ets/navigation/WorkspaceTransition'
import { extractRefreshCookie, parseApiResponse } from '../main/ets/network/ApiParser'
import { httpClient } from '../main/ets/network/HttpClient'
import { alertSocketClient } from '../main/ets/network/AlertSocketClient'
import { networkTransportFactory } from '../main/ets/network/TransportFactory'
import {
  previewAlertDetail,
  previewAlertPage,
  previewDeviceCommandPage,
  previewDeviceDetail,
  previewDevicePage,
  previewLatestWifiConfig,
  previewSessionPage,
  previewTenantPage
} from '../main/ets/preview/PreviewData'
import {
  PreviewSession,
  previewAccounts,
  previewCodeCredentialMatches,
  previewCredentialMatches
} from '../main/ets/preview/PreviewMode'
import {
  normalizeRuntimeMode,
  RuntimeMode,
  runtimeModeStore
} from '../main/ets/preview/RuntimeMode'
import { repositoryFactory } from '../main/ets/repository/RepositoryFactory'
import { publicAuthRepositoryFactory } from '../main/ets/repository/AuthRepository'
import {
  DemoPlatformAdminRepository,
  Hm2PreferenceStorage,
  PlatformAdminRepositoryFactory,
  PlatformAdminMutationTracker,
  platformAdminRepositoryFactory
} from '../main/ets/repository/PlatformAdminRepository'
import {
  DemoSessionPreferenceStorage,
  SessionStore
} from '../main/ets/session/SessionStore'
import { normalizeThemeMode } from '../main/ets/storage/ThemeStore'
import { normalizeLoginMode } from '../main/ets/storage/LoginPreferenceStore'
import {
  canReadAdminWorkspace,
  hasTenantWorkspace,
  isManagedTenantWorkspace,
  isPlatformWorkspace,
  MainRootRouteId,
  mainRootRouteId,
  mainTabIndexForRoute,
  mainTabKey,
  mainTabRenderKey,
  mainTabs,
  roleLabel,
  workspaceTitle
} from '../main/ets/ui/MainNavigation'

interface TestData {
  value: string
}

class StubMqttTransport {
  readonly channel: string = 'MQTT'
}

class FailingPutPreferenceStorage implements Hm2PreferenceStorage {
  value: string = ''
  compensationWrites: number = 0
  failNextPut: boolean = false

  async getString(_key: string, fallback: string = ''): Promise<string> {
    return this.value.length > 0 ? this.value : fallback
  }

  async putString(_key: string, value: string): Promise<void> {
    if (this.failNextPut) {
      this.failNextPut = false
      this.value = value
      throw new Error('flush failed')
    }
    this.value = value
    this.compensationWrites += 1
  }

  async remove(_key: string): Promise<void> {
    this.value = ''
  }
}

class FailingDemoSessionPreferenceStorage implements DemoSessionPreferenceStorage {
  value: string = ''
  putAttempts: number = 0
  failNextPut: boolean = false

  async getString(_key: string, fallback: string = ''): Promise<string> {
    return this.value.length > 0 ? this.value : fallback
  }

  async putString(_key: string, value: string): Promise<void> {
    this.putAttempts += 1
    if (this.failNextPut) {
      this.failNextPut = false
      throw new Error('flush failed')
    }
    this.value = value
  }

  async remove(_key: string): Promise<void> {
    this.value = ''
  }
}

interface PlatformTenantEnvelopeFixture {
  code: number
  message: string
  data: PlatformTenantPageResult
}

interface AuthEnvelopeFixture {
  code: number
  message: string
  data: AuthResult
}

export default function localUnitTest() {
  describe('wifiManagerContract', () => {
    it('parsesSuccessfulEnvelopeAndPrefersHeaderRequestId', 0, () => {
      const response = parseApiResponse<TestData>(
        '{"code":200,"message":"操作成功","data":{"value":"ok"},"requestId":"body_request_id_1234"}',
        200,
        '{"X-Request-Id":"header_request_id_1234"}',
        'wifi_refresh=rotated'
      )
      expect(response.data.value).assertEqual('ok')
      expect(response.requestId).assertEqual('header_request_id_1234')
      expect(response.refreshCookie).assertEqual('wifi_refresh=rotated')
    })

    it('keepsBackendErrorKeyAndRetryAfter', 0, () => {
      let captured: ApiError | null = null
      try {
        parseApiResponse<TestData>(
          '{"code":429,"message":"请求过于频繁","data":null,"errorKey":"RATE_LIMITED"}',
          429,
          '{"Retry-After":"15"}',
          ''
        )
      } catch (error) {
        if (error instanceof ApiError) {
          captured = error
        }
      }
      expect(captured === null ? 0 : captured.httpStatus).assertEqual(429)
      expect(captured === null ? '' : captured.errorKey).assertEqual('RATE_LIMITED')
      expect(captured === null ? '' : captured.retryAfter).assertEqual('15')
    })

    it('extractsOnlyRefreshCookie', 0, () => {
      const cookie = extractRefreshCookie('theme=dark; wifi_refresh=abc123; Path=/; HttpOnly')
      expect(cookie).assertEqual('wifi_refresh=abc123')
    })

    it('usesBusinessAuthenticationStatusOnHttpSuccess', 0, () => {
      let captured: ApiError | null = null
      try {
        parseApiResponse<TestData>(
          '{"code":401,"message":"登录状态已过期","data":null,"errorKey":"SESSION_EXPIRED"}',
          200,
          '{}',
          ''
        )
      } catch (error) {
        if (error instanceof ApiError) {
          captured = error
        }
      }
      expect(captured === null ? 0 : captured.httpStatus).assertEqual(401)
    })

    it('validatesAnonymousAccountInputs', 0, () => {
      expect(validateUsername('ab').length > 0).assertTrue()
      expect(validateUsername('alice')).assertEqual('')
      expect(validateAccountPassword('12345').length > 0).assertTrue()
      expect(validateAccountPassword('123456')).assertEqual('')
      expect(isEmailContact('alice@example.com')).assertTrue()
      expect(isEmailContact('alice')).assertFalse()
      expect(isPhoneContact('13800138000')).assertTrue()
      expect(isPhoneContact('12800138000')).assertFalse()
      expect(isValidVerifyCode('A1B2C3')).assertTrue()
    })

    it('parsesMockRegisterSuccessContract', 0, () => {
      const response = parseApiResponse<RegisterResult>(
        '{"code":200,"message":"注册成功","data":{' +
          '"status":"SUCCESS","message":"注册成功","conflictFields":null}}',
        200,
        '{"X-Request-Id":"register_request_1234"}',
        ''
      )
      expect(response.data.status).assertEqual('SUCCESS')
      expect(response.data.conflictFields === null).assertTrue()
      expect(response.requestId).assertEqual('register_request_1234')
    })

    it('acceptsNullResetPasswordResult', 0, () => {
      const response = parseApiResponse<Object | null>(
        '{"code":200,"message":"重置密码成功","data":null}',
        200,
        '{}',
        ''
      )
      expect(response.data === null).assertTrue()
    })

    it('mapsMalformedEnvelopeToProtocolError', 0, () => {
      let captured: ApiError | null = null
      try {
        parseApiResponse<TestData>('not-json', 200, '{}', '')
      } catch (error) {
        if (error instanceof ApiError) {
          captured = error
        }
      }
      expect(captured === null ? 0 : captured.httpStatus).assertEqual(502)
      expect(captured === null ? '' : captured.errorKey)
        .assertEqual('DEPENDENCY_PROTOCOL_INVALID')
    })

    it('rejectsJsonWithInvalidEnvelopeShape', 0, () => {
      let captured: ApiError | null = null
      try {
        parseApiResponse<TestData>('{"message":"操作成功","data":{"value":"ok"}}', 200, '{}', '')
      } catch (error) {
        if (error instanceof ApiError) {
          captured = error
        }
      }
      expect(captured === null ? 0 : captured.httpStatus).assertEqual(502)
      expect(captured === null ? '' : captured.errorKey)
        .assertEqual('DEPENDENCY_PROTOCOL_INVALID')
    })

    it('readsRequestIdFromArrayHeaderValue', 0, () => {
      const response = parseApiResponse<TestData>(
        '{"code":200,"message":"操作成功","data":{"value":"ok"}}',
        200,
        '{"x-request-id":["array_request_id_1234"]}',
        ''
      )
      expect(response.requestId).assertEqual('array_request_id_1234')
    })

    it('normalizesGatewayUrl', 0, () => {
      expect(normalizeGatewayUrl(' http://192.168.1.10:8080/ '))
        .assertEqual('http://192.168.1.10:8080')
    })

    it('resolvesGeneratedRealApiCatalogPaths', 0, () => {
      expect(configuredDefaultGatewayUrl()).assertEqual('http://10.0.2.2:8080')
      expect(realApiPath('entitlements.products')).assertEqual('/entitlements/products')
      expect(resolveRealApiPath(
        'devices.wifiTask',
        ['deviceCode', 'requestId'],
        ['EDGE/A', 'REQ 1']))
        .assertEqual('/admin/devices/EDGE%2FA/wifi-config/REQ%201')
    })

    it('rejectsUnknownOrIncompleteRealApiCatalogPaths', 0, () => {
      let unknown = ''
      try {
        realApiPath('unknown.path')
      } catch (error) {
        unknown = error instanceof Error ? error.message : ''
      }
      expect(unknown.includes('Unknown Real API key')).assertTrue()

      let incomplete = ''
      try {
        resolveRealApiPath('entitlements.orderDetail', [], [])
      } catch (error) {
        incomplete = error instanceof Error ? error.message : ''
      }
      expect(incomplete.includes('Unresolved Real API path')).assertTrue()
    })

    it('normalizesPersistedThemeMode', 0, () => {
      expect(normalizeThemeMode('dark')).assertEqual('dark')
      expect(normalizeThemeMode('invalid')).assertEqual('light')
    })

    it('validatesContactAndVerifyCodeContracts', 0, () => {
      expect(isValidContact('13800138000')).assertTrue()
      expect(isValidContact('demo@example.com')).assertTrue()
      expect(isValidContact('invalid-contact')).assertFalse()
      expect(isValidVerifyCode('A1b2C3')).assertTrue()
      expect(isValidVerifyCode('12345')).assertFalse()
    })

    it('normalizesRememberedLoginMode', 0, () => {
      expect(normalizeLoginMode('contact')).assertEqual('contact')
      expect(normalizeLoginMode('unknown')).assertEqual('username')
    })

    it('parsesMockSendLoginCodeContract', 0, () => {
      const responseText = JSON.stringify({
        code: 200,
        message: '验证码已发送',
        data: null,
        requestId: 'code_request_id_1234'
      })
      const response = parseApiResponse<Object | null>(
        responseText,
        200,
        '{}',
        ''
      )
      expect(response.data === null).assertTrue()
      expect(response.requestId).assertEqual('code_request_id_1234')
    })

    it('parsesMockLoginContractWithRotatedCookie', 0, () => {
      const response = parseApiResponse<AuthResult>(
        '{"code":200,"message":"登录成功","data":{"userId":"42","token":"access-token",' +
          '"username":"tenant-admin","role":1,"nickname":"租户管理员","avatar":"",' +
          '"accountState":"ACTIVE","context":{"contextType":"TENANT","tenantId":"7",' +
          '"tenantCode":"demo","tenantName":"演示租户","tenantRole":"TENANT_ADMIN",' +
          '"contextVersion":3,"memberContextVersion":2,"tenantStatus":"ACTIVE",' +
          '"writable":true,"authorities":["DEVICE_READ"]}},"requestId":"login_request_id_1234"}',
        200,
        '{"X-Request-Id":"login_header_id_1234"}',
        'wifi_refresh=mock-rotated'
      )
      expect(response.data.role).assertEqual(1)
      expect(response.data.context?.contextType ?? '').assertEqual('TENANT')
      expect(response.refreshCookie).assertEqual('wifi_refresh=mock-rotated')
      expect(response.requestId).assertEqual('login_header_id_1234')
    })

    it('parsesMockDevicePageContract', 0, () => {
      const response = parseApiResponse<DevicePageResult>(
        '{"code":200,"message":"操作成功","data":{"total":1,"current":1,"size":10,' +
          '"records":[{"nodeId":101,"deviceCode":"EDGE-101","name":"一层网关",' +
          '"location":"办公区","latitude":31.2,"longitude":121.5,"ip":"192.168.1.20",' +
          '"status":1,"firmwareVersion":"1.0.0","wifiStatus":"CONNECTED","maxClients":32,' +
          '"currentClients":6,"lastHeartbeat":"2026-08-17T17:00:00",' +
          '"rssiAtOneMeter":-42,"pathLossExponent":2.1,' +
          '"createTime":"2026-08-01T09:00:00","updateTime":"2026-08-17T17:00:00"}]}}',
        200,
        '{}',
        ''
      )
      expect(response.data.total).assertEqual(1)
      expect(response.data.records[0].deviceCode).assertEqual('EDGE-101')
      expect(response.data.records[0].currentClients).assertEqual(6)
    })

    it('parsesMockDeviceDetailWithNullableTimes', 0, () => {
      const response = parseApiResponse<DeviceNode>(
        '{"code":200,"message":"操作成功","data":{"nodeId":102,"deviceCode":"EDGE-102",' +
          '"name":"待接入网关","location":"","latitude":null,"longitude":null,"ip":"",' +
          '"status":0,"firmwareVersion":"","wifiStatus":"DISCONNECTED","maxClients":16,' +
          '"currentClients":0,"lastHeartbeat":null,"rssiAtOneMeter":null,' +
          '"pathLossExponent":null,"createTime":null,"updateTime":null}}',
        200,
        '{}',
        ''
      )
      expect(response.data.status).assertEqual(0)
      expect(response.data.lastHeartbeat === null).assertTrue()
      expect(response.data.updateTime === null).assertTrue()
    })

    it('parsesMockPlatformTenantPageContract', 0, () => {
      const fixture: PlatformTenantEnvelopeFixture = {
        code: 200,
        message: '操作成功',
        data: {
          total: 1,
          current: 1,
          size: 100,
          records: [{
            tenantId: '17',
            tenantCode: 'demo-team',
            name: '演示组织',
            status: 'ACTIVE',
            timezone: 'Asia/Shanghai',
            ownerUserId: '9',
            contextVersion: 4,
            version: 2,
            memberCount: 5,
            subscriptionStatus: 'ACTIVE',
            createTime: '2026-08-01T09:00:00',
            updateTime: null
          }]
        }
      }
      const responseText = JSON.stringify(fixture)
      const response = parseApiResponse<PlatformTenantPageResult>(responseText, 200, '{}', '')
      expect(response.data.records[0].tenantId).assertEqual('17')
      expect(response.data.records[0].status).assertEqual('ACTIVE')
      expect(response.data.records[0].memberCount).assertEqual(5)
    })

    it('parsesMockPlatformTenantContextResult', 0, () => {
      const fixture: AuthEnvelopeFixture = {
        code: 200,
        message: '已进入代管租户上下文',
        data: {
          userId: '1',
          token: 'new-context-access-token',
          username: 'root',
          role: 0,
          nickname: '平台管理员',
          avatar: '',
          accountState: 'ACTIVE',
          context: {
            contextType: 'PLATFORM_TENANT',
            tenantId: '17',
            tenantCode: 'demo-team',
            tenantName: '演示组织',
            tenantRole: 'PLATFORM_ADMIN',
            contextVersion: 4,
            memberContextVersion: 0,
            tenantStatus: 'ACTIVE',
            writable: true,
            authorities: ['DEVICE_READ']
          }
        }
      }
      const responseText = JSON.stringify(fixture)
      const response = parseApiResponse<AuthResult>(responseText, 200, '{}', '')
      expect(response.data.role).assertEqual(0)
      expect(response.data.context?.contextType ?? '').assertEqual('PLATFORM_TENANT')
      expect(response.data.context?.tenantId ?? '').assertEqual('17')
    })

    it('parsesMockSessionPageContract', 0, () => {
      const response = parseApiResponse<SessionPageResult>(
        '{"code":200,"message":"操作成功","data":{"total":1,"current":1,"size":10,' +
          '"records":[{"sessionId":31,"userId":9,"nodeId":101,"replacedSessionId":null,' +
          '"mac":"AA:BB:CC:DD:EE:FF","ip":"192.168.4.2","deviceInfo":"HarmonyOS",' +
          '"loginTime":"2026-08-17T19:00:00","expireTime":"2026-08-17T20:00:00",' +
          '"logoutTime":null,"status":1,"bytesUp":1024,"bytesDown":2048}]}}',
        200,
        '{}',
        ''
      )
      expect(response.data.records[0].sessionId).assertEqual(31)
      expect(response.data.records[0].status).assertEqual(1)
      expect(response.data.records[0].bytesDown).assertEqual(2048)
    })

    it('parsesMockClosedSessionResult', 0, () => {
      const response = parseApiResponse<NetworkSession>(
        '{"code":200,"message":"操作成功","data":{"sessionId":31,"userId":9,' +
          '"nodeId":101,"replacedSessionId":null,"mac":"AA:BB:CC:DD:EE:FF",' +
          '"ip":"192.168.4.2","deviceInfo":"HarmonyOS","loginTime":"2026-08-17T19:00:00",' +
          '"expireTime":"2026-08-17T20:00:00","logoutTime":"2026-08-17T19:30:00",' +
          '"status":0,"bytesUp":1024,"bytesDown":2048}}',
        200,
        '{}',
        ''
      )
      expect(response.data.status).assertEqual(0)
      expect(response.data.logoutTime ?? '').assertEqual('2026-08-17T19:30:00')
    })

    it('parsesMockAlertPageContract', 0, () => {
      const response = parseApiResponse<AlertPageResult>(
        '{"code":200,"message":"操作成功","data":{"total":1,"current":1,"size":10,' +
          '"records":[{"id":51,"level":3,"ruleCode":"BLOCKED_DOMAIN",' +
          '"title":"检测到受限访问","mac":"AA:BB:CC:DD:EE:FF","userId":9,' +
          '"detail":"访问命中安全规则","status":0,"handleUserId":null,"handleTime":null,' +
          '"createTime":"2026-08-17T19:20:00"}]}}',
        200,
        '{}',
        ''
      )
      expect(response.data.records[0].id).assertEqual(51)
      expect(response.data.records[0].level).assertEqual(3)
      expect(response.data.records[0].status).assertEqual(0)
    })

    it('parsesMockHandledAlertDetailContract', 0, () => {
      const response = parseApiResponse<AlertEvent>(
        '{"code":200,"message":"操作成功","data":{"id":51,"level":3,' +
          '"ruleCode":"BLOCKED_DOMAIN","title":"检测到受限访问",' +
          '"mac":"AA:BB:CC:DD:EE:FF","userId":9,"detail":"访问命中安全规则",' +
          '"status":1,"handleUserId":1,"handleTime":"2026-08-17T19:30:00",' +
          '"createTime":"2026-08-17T19:20:00"}}',
        200,
        '{}',
        ''
      )
      expect(response.data.status).assertEqual(1)
      expect(response.data.handleUserId ?? 0).assertEqual(1)
      expect(response.data.handleTime ?? '').assertEqual('2026-08-17T19:30:00')
    })

    it('buildsAlertWebSocketUrlFromGateway', 0, () => {
      expect(buildAlertWebSocketUrl('http://192.168.1.10:8080/'))
        .assertEqual('ws://192.168.1.10:8080/ws/alerts')
      expect(buildAlertWebSocketUrl('https://wifi.example.com'))
        .assertEqual('wss://wifi.example.com/ws/alerts')
    })

    it('parsesTenantBoundAlertSocketMessages', 0, () => {
      const ping = parseAlertSocketMessage('{"type":"PING","time":1}', '17')
      const alert = parseAlertSocketMessage(
        '{"type":"alert","alertId":51,"tenantId":17,"level":3,' +
          '"ruleCode":"BLOCKED_DOMAIN","title":"检测到受限访问",' +
          '"mac":"AA:BB:CC:DD:EE:FF","userId":9,"createTime":"2026-08-17T19:20:00"}',
        '17'
      )
      const foreign = parseAlertSocketMessage(
        '{"type":"alert","alertId":52,"tenantId":18}',
        '17'
      )
      expect(ping?.type ?? '').assertEqual('PING')
      expect(alert?.alert?.alertId ?? 0).assertEqual(51)
      expect(alert?.alert?.tenantId ?? '').assertEqual('17')
      expect(foreign === null).assertTrue()
    })

    it('backsOffAlertSocketReconnects', 0, () => {
      expect(alertReconnectDelay(0)).assertEqual(1000)
      expect(alertReconnectDelay(4)).assertEqual(16000)
      expect(alertReconnectDelay(9)).assertEqual(30000)
    })

    it('parsesMockDeviceCommandSubmitContract', 0, () => {
      const response = parseApiResponse<DeviceCommandResult>(
        '{"code":200,"message":"操作成功","data":{' +
          '"requestId":"3f315dc0-55c8-4d95-93cf-d80de85aa80c",' +
          '"topic":"wifi/device/EDGE-101/cmd/kick",' +
          '"payload":"{\\"requestId\\":\\"3f315dc0-55c8-4d95-93cf-d80de85aa80c\\"}"}}',
        200,
        '{"X-Request-Id":"trace_request_id_1234"}',
        ''
      )
      expect(response.data.requestId).assertEqual('3f315dc0-55c8-4d95-93cf-d80de85aa80c')
      expect(response.requestId).assertEqual('trace_request_id_1234')
      expect(isValidDeviceCommandRequestId(response.data.requestId)).assertTrue()
    })

    it('parsesMockDeviceCommandHistoryContract', 0, () => {
      const response = parseApiResponse<DeviceCommandPageResult>(
        '{"code":200,"message":"操作成功","data":{"total":1,"current":1,"size":20,' +
          '"records":[{"commandId":81,' +
          '"requestId":"3f315dc0-55c8-4d95-93cf-d80de85aa80c",' +
          '"nodeId":101,"deviceCode":"EDGE-101","commandType":"DISCONNECT_MAC",' +
          '"purpose":"MANUAL_DISCONNECT","sessionId":null,"mac":"AA:BB:CC:DD:EE:FF",' +
          '"alertId":null,"ttlSeconds":null,"topic":"wifi/device/EDGE-101/cmd/disconnect-mac",' +
          '"payload":"{}","status":1,"retryCount":0,"nextRetryTime":null,' +
          '"publishTime":"2026-08-17T21:10:00","deadlineTime":"2026-08-17T21:11:00",' +
          '"resultTime":null,"resultMessage":null,"createTime":"2026-08-17T21:09:59",' +
          '"updateTime":"2026-08-17T21:10:00"}]}}',
        200,
        '{}',
        ''
      )
      expect(response.data.records[0].commandId).assertEqual(81)
      expect(response.data.records[0].status).assertEqual(1)
      expect(response.data.records[0].mac ?? '').assertEqual('AA:BB:CC:DD:EE:FF')
      expect(isDeviceCommandTerminal(response.data.records[0].status)).assertFalse()
    })

    it('recognizesOnlyBackendDeviceCommandTerminalStates', 0, () => {
      expect(isDeviceCommandTerminal(0)).assertFalse()
      expect(isDeviceCommandTerminal(1)).assertFalse()
      expect(isDeviceCommandTerminal(2)).assertTrue()
      expect(isDeviceCommandTerminal(3)).assertTrue()
      expect(isDeviceCommandTerminal(4)).assertTrue()
      expect(isDeviceCommandTerminal(5)).assertTrue()
      expect(deviceCommandStatusLabel(5)).assertEqual('等待结果超时')
    })

    it('validatesManualDeviceCommandInputs', 0, () => {
      expect(isValidMacAddress('aa:bb:cc:dd:ee:ff')).assertTrue()
      expect(isValidMacAddress('AA-BB-CC-DD-EE-FF')).assertFalse()
      expect(isValidIpv4Address('192.168.4.1')).assertTrue()
      expect(isValidIpv4Address('256.168.4.1')).assertFalse()
      expect(isValidIpv4Address('192.168.04.1')).assertFalse()
      expect(isValidDeviceCommandRequestId('3f315dc0-55c8-4d95-93cf-d80de85aa80c')).assertTrue()
      expect(isValidDeviceCommandRequestId('invalid request id')).assertFalse()
    })

    it('parsesMockWifiConfigStageContractWithoutPassword', 0, () => {
      const response = parseApiResponse<WifiConfigTask>(
        '{"code":200,"message":"操作成功","data":{"wifiConfigId":91,"nodeId":101,' +
          '"deviceCode":"EDGE-101","requestId":"3f315dc0-55c8-4d95-93cf-d80de85aa80c",' +
          '"configVersion":7,"ssid":"Office-WiFi","passwordConfigured":true,' +
          '"status":0,"statusName":"DISPATCHING","stagedTime":null,"activatedTime":null,' +
          '"failureMessage":null,"createTime":"2026-08-18T11:30:00",' +
          '"updateTime":"2026-08-18T11:30:00"}}',
        200,
        '{}',
        ''
      )
      expect(response.data.configVersion).assertEqual(7)
      expect(response.data.passwordConfigured).assertTrue()
      expect(isValidWifiConfigRequestId(response.data.requestId)).assertTrue()
      expect(JSON.stringify(response.data).includes('"password"')).assertFalse()
    })

    it('acceptsEmptyLatestWifiConfigTask', 0, () => {
      const response = parseApiResponse<WifiConfigTask | null>(
        '{"code":200,"message":"操作成功","data":null}',
        200,
        '{}',
        ''
      )
      expect(response.data === null).assertTrue()
    })

    it('recognizesOnlyBackendWifiConfigTerminalStates', 0, () => {
      expect(isWifiConfigTerminal(0)).assertFalse()
      expect(isWifiConfigTerminal(1)).assertFalse()
      expect(isWifiConfigTerminal(2)).assertTrue()
      expect(isWifiConfigTerminal(3)).assertTrue()
      expect(isWifiConfigTerminal(4)).assertFalse()
      expect(isWifiConfigTerminal(5)).assertTrue()
      expect(wifiConfigStatusLabel(4)).assertEqual('结果未知')
    })

    it('validatesWifiCredentialUtf8Boundaries', 0, () => {
      expect(utf8ByteLength('办公室网络')).assertEqual(15)
      expect(validateWifiCredentials('Office-WiFi', '')).assertEqual('')
      expect(validateWifiCredentials('办公室网络', '12345678')).assertEqual('')
      expect(validateWifiCredentials('一二三四五六七八九十一', '12345678').length > 0).assertTrue()
      expect(validateWifiCredentials('Office-WiFi', '1234567').length > 0).assertTrue()
      expect(validateWifiCredentials('Office-WiFi', '密码密码密码')).assertEqual('')
      expect(isValidWifiConfigRequestId('invalid request id')).assertFalse()
    })

    it('enablesOnlyTheThreeExactDebugPreviewCredentials', 0, () => {
      expect(previewAccounts().length).assertEqual(3)
      expect(previewCredentialMatches('username', 'superadmin', '123456', true)).assertTrue()
      expect(previewCredentialMatches('username', 'tenantadmin', '123456', true)).assertTrue()
      expect(previewCredentialMatches('username', 'member', '123456', true)).assertTrue()
      expect(previewCredentialMatches('username', 'superadmin', 'wrong', true)).assertFalse()
      expect(previewCredentialMatches('username', 'unknown', '123456', true)).assertFalse()
      expect(previewCredentialMatches('contact', 'superadmin', '123456', true)).assertFalse()
      expect(previewCredentialMatches('username', 'superadmin', '123456', false)).assertFalse()
      expect(previewCodeCredentialMatches('13800138000', '123456', true)).assertTrue()
      expect(previewCodeCredentialMatches('demo@wifi.local', '123456', true)).assertTrue()
      expect(previewCodeCredentialMatches('13800138000', '000000', true)).assertFalse()
    })

    it('keepsSuperAdminPreviewSessionInPlatformWorkspace', 0, () => {
      const preview = new PreviewSession()
      const snapshot = preview.tryLogin({
        loginType: 'username',
        account: 'superadmin',
        password: '123456'
      })
      expect(snapshot?.authenticated ?? false).assertTrue()
      expect(snapshot?.role ?? -1).assertEqual(0)
      expect(snapshot?.context?.contextType ?? '').assertEqual('PLATFORM')
      const tenant = preview.enterTenant('preview-tenant-02')
      expect(tenant.context?.tenantId ?? '').assertEqual('preview-tenant-02')
      expect(tenant.context?.contextType ?? '').assertEqual('PLATFORM_TENANT')
      expect(tenant.context?.writable ?? false).assertTrue()
      const platform = preview.returnToPlatform()
      expect(platform.context?.contextType ?? '').assertEqual('PLATFORM')

      preview.clear()
      expect(preview.getSnapshot().authenticated).assertFalse()
    })

    it('keepsTenantAdminAndMemberInsideTenantWorkspace', 0, () => {
      const preview = new PreviewSession()
      const admin = preview.tryLogin({
        loginType: 'username',
        account: 'tenantadmin',
        password: '123456'
      })
      expect(admin?.role ?? -1).assertEqual(1)
      expect(admin?.context?.contextType ?? '').assertEqual('TENANT')
      expect(preview.enterTenant('preview-tenant-02').context?.tenantId ?? '')
        .assertEqual('preview-tenant-01')

      preview.clear()
      const member = preview.tryLogin({
        loginType: 'username',
        account: 'member',
        password: '123456'
      })
      expect(member?.role ?? -1).assertEqual(2)
      expect(member?.context?.tenantRole ?? '').assertEqual('MEMBER')
      expect(member?.context?.contextType ?? '').assertEqual('TENANT')
    })

    it('restoresPersistedPreviewSnapshotWithoutRealCredentials', 0, () => {
      const source = new PreviewSession()
      const snapshot = source.tryLogin({
        loginType: 'username',
        account: 'superadmin',
        password: '123456'
      })
      expect(snapshot === null).assertFalse()
      if (snapshot === null) return

      const restored = new PreviewSession()
      expect(restored.restore(snapshot)).assertTrue()
      expect(restored.getSnapshot().username).assertEqual('superadmin')
      expect(restored.getSnapshot().context?.contextType ?? '').assertEqual('PLATFORM')
    })

    it('providesPreviewDeviceListAndDetailWithoutBackendData', 0, () => {
      const page = previewDevicePage(1, 20, '上海')
      const detail = previewDeviceDetail('101')
      expect(page.total).assertEqual(1)
      expect(page.records[0].deviceCode).assertEqual('EDGE-SH-01')
      expect(detail?.name ?? '').assertEqual('上海办公室主网关')
      expect(previewDeviceDetail('999') === null).assertTrue()
    })

    it('providesReadOnlyPreviewDataForAllWorkspacePages', 0, () => {
      const sessions = previewSessionPage({
        current: 1,
        size: 20,
        mac: '',
        nodeId: '',
        userId: '',
        status: '1'
      })
      const memberSessions = previewSessionPage({
        current: 1,
        size: 20,
        mac: '',
        nodeId: '',
        userId: '',
        status: '1'
      }, false)
      const alerts = previewAlertPage({
        current: 1,
        size: 20,
        level: '',
        status: '0',
        mac: ''
      })
      const tenants = previewTenantPage(1, 20, '')
      const commands = previewDeviceCommandPage({
        current: 1,
        size: 20,
        requestId: '',
        deviceCode: 'EDGE-SH-01'
      })
      const wifiTask = previewLatestWifiConfig('EDGE-SH-01')

      expect(sessions.total).assertEqual(2)
      expect(memberSessions.total).assertEqual(1)
      expect(memberSessions.records[0].userId ?? 0).assertEqual(201)
      expect(alerts.total).assertEqual(2)
      expect(previewAlertDetail(alerts.records[0].id)?.status ?? -1).assertEqual(0)
      expect(tenants.total).assertEqual(2)
      expect(commands.total).assertEqual(2)
      expect(wifiTask?.status ?? -1).assertEqual(2)
    })

    it('resolvesMainNavigationForPlatformAndManagedTenantContexts', 0, () => {
      const preview = new PreviewSession()
      const platform = preview.tryLogin({
        loginType: 'username',
        account: 'superadmin',
        password: '123456'
      })
      expect(platform === null).assertFalse()
      if (platform === null) return
      expect(isPlatformWorkspace(platform)).assertTrue()
      expect(hasTenantWorkspace(platform)).assertFalse()
      expect(canReadAdminWorkspace(platform)).assertFalse()
      expect(workspaceTitle(platform)).assertEqual('系统管理')
      expect(mainTabs(platform).length).assertEqual(5)
      expect(mainTabKey(platform, 1)).assertEqual('ORGANIZATIONS')
      expect(mainTabKey(platform, 4)).assertEqual('ME')
      expect(mainRootRouteId(platform, 0)).assertEqual('platform/home')
      expect(mainTabIndexForRoute(platform, 'platform/accounts')).assertEqual(2)
      expect(mainRootRouteId(platform, 1)).assertEqual('platform/tenants')
      expect(mainRootRouteId(platform, 2)).assertEqual('platform/accounts')
      expect(mainRootRouteId(platform, 3)).assertEqual('platform/services')
      expect(mainRootRouteId(platform, 2) === mainRootRouteId(platform, 3)).assertFalse()
      expect(mainRootRouteId(platform, 3) === mainRootRouteId(platform, 2)).assertFalse()
      expect(mainRootRouteId(platform, 4)).assertEqual('me/home')
      expect(mainTabRenderKey(platform, mainTabs(platform)[3]))
        .assertEqual('0:PLATFORM:platform/services')
      expect(mainTabRenderKey(platform, mainTabs(platform)[4]))
        .assertEqual('0:PLATFORM:me/home')

      const tenant = preview.enterTenant('preview-tenant-01')
      expect(hasTenantWorkspace(tenant)).assertTrue()
      expect(canReadAdminWorkspace(tenant)).assertTrue()
      expect(isManagedTenantWorkspace(tenant)).assertTrue()
      expect(workspaceTitle(tenant)).assertEqual('边缘网络实验室')
      expect(mainTabs(tenant).length).assertEqual(5)
      expect(mainTabKey(tenant, 1)).assertEqual('DEVICES')
      expect(mainTabKey(tenant, 3)).assertEqual('SERVICES')
      expect(mainRootRouteId(tenant, 0)).assertEqual('tenant/home')
      expect(mainRootRouteId(tenant, 1)).assertEqual('tenant/devices')
      expect(mainRootRouteId(tenant, 2)).assertEqual('tenant/alerts')
      expect(mainRootRouteId(tenant, 3)).assertEqual('tenant/services')
      expect(mainRootRouteId(tenant, 4)).assertEqual('me/home')
    })

    it('providesHm2TenantPagingFilteringAndCreation', 0, async () => {
      const repository = new DemoPlatformAdminRepository()
      const first = await repository.listTenants(1, 2, '', '')
      const second = await repository.listTenants(2, 2, '', '')
      const disabled = await repository.listTenants(1, 20, '', 'DISABLED')
      const filtered = await repository.listTenants(1, 20, '分部', '')
      expect(first.total).assertEqual(4)
      expect(first.records.length).assertEqual(2)
      expect(second.records.length).assertEqual(2)
      expect(disabled.total).assertEqual(1)
      expect(filtered.records[0].tenantCode).assertEqual('branch-office')
      expect(filtered.records[0].name).assertEqual('分部办公网络')

      const input: TenantCreateInput = {
        tenantCode: 'south-office',
        name: '南区办公网络',
        timezone: 'Asia/Shanghai',
        ownerUsername: 'trial-user'
      }
      const created = await repository.createTenant(input)
      expect(created.tenantCode).assertEqual('south-office')
      expect((await repository.listTenants(1, 20, 'south-office', '')).total).assertEqual(1)
      const adminOwned = await repository.createTenant({
        tenantCode: 'admin-owned',
        name: '管理员负责组织',
        timezone: 'Asia/Shanghai',
        ownerUsername: 'lab-admin'
      })
      const ownerMembers = await repository.listTenantMembers(adminOwned.tenantId, '')
      expect(ownerMembers.length).assertEqual(1)
      expect(ownerMembers[0].role).assertEqual('TENANT_OWNER')

      let conflict = false
      try {
        await repository.createTenant(input)
      } catch (error) {
        conflict = error instanceof ApiError && error.httpStatus === 409
      }
      expect(conflict).assertTrue()
    })

    it('updatesHm2TenantAndKeepsManagedMembersReadOnly', 0, async () => {
      const repository = new DemoPlatformAdminRepository()
      const updated = await repository.updateTenant('preview-tenant-01', {
        name: '边缘网络联合实验室',
        timezone: 'Asia/Shanghai'
      })
      expect(updated.name).assertEqual('边缘网络联合实验室')
      expect(updated.version).assertEqual(6)
      const disabled = await repository.updateTenantStatus('preview-tenant-01', 'DISABLED')
      expect(disabled.status).assertEqual('DISABLED')
      const members = await repository.listTenantMembers('preview-tenant-01', '管理员')
      expect(members.length).assertEqual(1)
      expect(members[0].role).assertEqual('TENANT_ADMIN')
    })

    it('coordinatesHm2WorkspaceTransitionAndRollsBackRootFailure', 0, async () => {
      let context = 'PLATFORM'
      let cache = ''
      const successSteps = new WorkspaceTransitionPlan(
        async (): Promise<void> => {
          expect(isWorkspaceTransitionActive()).assertTrue()
          context = 'PLATFORM_TENANT'
        },
        async (): Promise<void> => {},
        async (): Promise<void> => {
          context = 'PLATFORM'
        },
        (): void => {
          cache = 'preview-tenant-01'
        },
        (): void => {
          cache = ''
        }
      )
      await executeWorkspaceTransition(successSteps)
      expect(context).assertEqual('PLATFORM_TENANT')
      expect(cache).assertEqual('preview-tenant-01')
      expect(isWorkspaceTransitionActive()).assertFalse()

      context = 'PLATFORM'
      cache = ''
      let failed = false
      try {
        const failureSteps = new WorkspaceTransitionPlan(
          async (): Promise<void> => {
            context = 'PLATFORM_TENANT'
          },
          async (): Promise<void> => {
            throw new Error('route failed')
          },
          async (): Promise<void> => {
            context = 'PLATFORM'
          },
          (): void => {
            cache = 'preview-tenant-01'
          },
          (): void => {
            cache = ''
          }
        )
        await executeWorkspaceTransition(failureSteps)
      } catch (_) {
        failed = true
      }
      expect(failed).assertTrue()
      expect(context).assertEqual('PLATFORM')
      expect(cache).assertEqual('')
      expect(isWorkspaceTransitionActive()).assertFalse()
    })

    it('keepsTransitionCacheAlignedWhenContextRollbackFails', 0, async () => {
      let context = 'PLATFORM'
      let cache = ''
      let rollbackFailed = false
      try {
        await executeWorkspaceTransition(new WorkspaceTransitionPlan(
          async (): Promise<void> => {
            context = 'PLATFORM_TENANT'
          },
          async (): Promise<void> => {
            throw new Error('route failed')
          },
          async (): Promise<void> => {
            context = 'PLATFORM'
            throw new Error('context rollback persistence failed')
          },
          (): void => {
            cache = 'preview-tenant-01'
          },
          (): void => {
            cache = ''
          }
        ))
      } catch (error) {
        rollbackFailed = error instanceof Error &&
          error.message === 'context rollback persistence failed'
      }
      expect(rollbackFailed).assertTrue()
      expect(context).assertEqual('PLATFORM')
      expect(cache).assertEqual('')
      expect(isWorkspaceTransitionActive()).assertFalse()
    })

    it('keepsManagedWorkspaceTransientAcrossColdStart', 0, async () => {
      runtimeModeStore.activateDemo()
      const source = new PreviewSession()
      const platformSnapshot = source.tryLogin({
        loginType: 'username',
        account: 'superadmin',
        password: '123456'
      })
      expect(platformSnapshot === null).assertFalse()
      if (platformSnapshot === null) return

      const storage = new FailingDemoSessionPreferenceStorage()
      storage.value = JSON.stringify(platformSnapshot)
      const activeStore = new SessionStore(storage)
      await activeStore.initialize()
      await activeStore.enterPlatformTenant('preview-tenant-01', '成功切换')
      expect(activeStore.getSnapshot().context?.contextType ?? '')
        .assertEqual('PLATFORM_TENANT')
      expect((JSON.parse(storage.value) as SessionSnapshot).context?.contextType ?? '')
        .assertEqual('PLATFORM')

      const coldStartStore = new SessionStore(storage)
      await coldStartStore.initialize()
      expect(coldStartStore.getSnapshot().context?.contextType ?? '')
        .assertEqual('PLATFORM')
    })

    it('migratesLegacyManagedWorkspacePersistenceBackToPlatform', 0, async () => {
      runtimeModeStore.activateDemo()
      const source = new PreviewSession()
      const platformSnapshot = source.tryLogin({
        loginType: 'username',
        account: 'superadmin',
        password: '123456'
      })
      expect(platformSnapshot === null).assertFalse()
      if (platformSnapshot === null) return
      const managedSnapshot = source.enterTenant('preview-tenant-01')

      const storage = new FailingDemoSessionPreferenceStorage()
      storage.value = JSON.stringify(managedSnapshot)
      const coldStartStore = new SessionStore(storage)
      await coldStartStore.initialize()
      expect(coldStartStore.getSnapshot().context?.contextType ?? '')
        .assertEqual('PLATFORM')
      expect((JSON.parse(storage.value) as SessionSnapshot).context?.contextType ?? '')
        .assertEqual('PLATFORM')
    })

    it('acceptsMainPageColdStartWithoutRouteParams', 0, () => {
      expect(mainRootRouteFromParams(undefined)).assertNull()
      expect(mainRootRouteFromParams(null)).assertNull()
      expect(mainRootRouteFromParams({ rootRouteId: 'platform/services' }))
        .assertEqual('platform/services')
      const handoff = new MainRootRouteHandoff()
      handoff.prepare('platform/tenants')
      expect(handoff.consume(undefined)).assertEqual('platform/tenants')
      expect(handoff.consume(undefined)).assertNull()
      handoff.prepare('platform/accounts')
      expect(handoff.consume({ rootRouteId: 'platform/services' }))
        .assertEqual('platform/services')
      expect(handoff.consume(undefined)).assertNull()
      const notifier = new MainRootRouteNotifier()
      let notifiedRoute = ''
      const listener = (routeId: MainRootRouteId): void => {
        notifiedRoute = routeId
      }
      notifier.add(listener)
      notifier.publish('platform/tenants')
      expect(notifiedRoute).assertEqual('platform/tenants')
      notifier.remove(listener)
      notifier.publish('platform/services')
      expect(notifiedRoute).assertEqual('platform/tenants')

      let deferredRoute = ''
      const deferred = new MainRootRouteNotifier()
      deferred.publish('platform/tenants')
      deferred.add((routeId: MainRootRouteId): void => {
        deferredRoute = routeId
      })
      expect(deferredRoute).assertEqual('platform/tenants')
    })

    it('restoresDynamicHm2ManagedTenantContext', 0, () => {
      const source = new PreviewSession()
      source.tryLogin({
        loginType: 'username',
        account: 'superadmin',
        password: '123456'
      })
      const managed = source.enterTenant('preview-tenant-05')
      const restored = new PreviewSession()
      expect(restored.restore(managed)).assertTrue()
      expect(restored.getSnapshot().context?.contextType ?? '').assertEqual('PLATFORM_TENANT')
      expect(restored.getSnapshot().context?.tenantId ?? '').assertEqual('preview-tenant-05')
    })

    it('updatesHm2AccountStatusWithoutAllowingSelfSuspension', 0, async () => {
      const repository = new DemoPlatformAdminRepository()
      const suspended = await repository.updateAccountStatus('2108', 'SUSPENDED')
      expect(suspended.status).assertEqual('SUSPENDED')
      expect((await repository.listAccounts(1, 20, '', 'SUSPENDED')).total).assertEqual(2)
      let forbidden = false
      try {
        await repository.updateAccountStatus('1000', 'SUSPENDED')
      } catch (error) {
        forbidden = error instanceof ApiError && error.errorKey === 'SELF_STATUS_FORBIDDEN'
      }
      expect(forbidden).assertTrue()
    })

    it('runsHm2DeleteReviewAsSingleDirectionStateMachine', 0, async () => {
      const repository = new DemoPlatformAdminRepository()
      const review = await repository.submitAccountDeletion('2108', '试用结束，清理账号。')
      expect(review.status).assertEqual('PENDING')
      const rejected = await repository.decideAccountReview(review.reviewId, false, '暂时保留')
      expect(rejected.status).assertEqual('REJECTED')
      expect((await repository.accountDetail('2108')).status).assertEqual('ACTIVE')

      let repeated = false
      try {
        await repository.decideAccountReview(review.reviewId, true, '')
      } catch (error) {
        repeated = error instanceof ApiError && error.errorKey === 'DELETE_REVIEW_FINISHED'
      }
      expect(repeated).assertTrue()

      const second = await repository.submitAccountDeletion('2108', '确认不再使用。')
      await repository.decideAccountReview(second.reviewId, true, '通过')
      expect((await repository.accountDetail('2108')).status).assertEqual('DELETED')
    })

    it('keepsHm2SaasPlansSearchableAndUsesOneEditableAggregate', 0, async () => {
      const repository = new DemoPlatformAdminRepository()
      const published = await repository.listSaasPlans(1, 20, '', 'PUBLISHED')
      const pro = await repository.listSaasPlans(1, 20, 'PRO', '')
      expect(published.total).assertEqual(2)
      expect(pro.total).assertEqual(1)
      const detail = await repository.saasPlanDetail(pro.records[0].planId)
      expect(detail.features.length).assertEqual(3)
      expect(detail.status).assertEqual('PUBLISHED')

      const edited = await repository.saveSaasPlan(detail.planId, {
        planCode: detail.planCode,
        name: '专业协作版',
        version: 'v3.1',
        status: 'PUBLISHED',
        priceLabel: '¥799 / 月',
        billingCycle: 'MONTHLY',
        deviceLimit: 160,
        memberLimit: 320,
        features: ['高级告警', '位置与围栏']
      })
      expect(edited.planId).assertEqual(detail.planId)
      expect((await repository.saasPlanDetail(detail.planId)).name).assertEqual('专业协作版')
      expect((await repository.listSaasPlans(1, 20, '协作', '')).total).assertEqual(1)

      const created = await repository.saveSaasPlan('', {
        planCode: 'TEAM',
        name: '团队版',
        version: 'v1.0',
        status: 'DRAFT',
        priceLabel: '¥399 / 月',
        billingCycle: 'MONTHLY',
        deviceLimit: 40,
        memberLimit: 80,
        features: ['设备管理']
      })
      expect((await repository.saasPlanDetail(created.planId)).planCode).assertEqual('TEAM')
      expect((await repository.listSaasPlans(1, 20, 'TEAM', '')).total).assertEqual(1)
    })

    it('rejectsUnknownHm2SaasPlanEditsWithoutCreatingRecords', 0, async () => {
      const repository = new DemoPlatformAdminRepository()
      const before = await repository.listSaasPlans(1, 20, '', '')
      let errorKey = ''
      try {
        await repository.saveSaasPlan('missing-plan', {
          planCode: 'MISSING',
          name: '不存在的套餐',
          version: 'v1.0',
          status: 'DRAFT',
          priceLabel: '¥1 / 月',
          billingCycle: 'MONTHLY',
          deviceLimit: 1,
          memberLimit: 1,
          features: ['测试']
        })
      } catch (error) {
        errorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(errorKey).assertEqual('SAAS_PLAN_NOT_FOUND')
      expect((await repository.listSaasPlans(1, 20, '', '')).total).assertEqual(before.total)

      let precedenceErrorKey = ''
      try {
        await repository.saveSaasPlan('missing-plan', {
          planCode: 'PRO',
          name: '',
          version: '',
          status: 'INVALID',
          priceLabel: '',
          billingCycle: 'INVALID',
          deviceLimit: 0,
          memberLimit: 0,
          features: []
        })
      } catch (error) {
        precedenceErrorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(precedenceErrorKey).assertEqual('SAAS_PLAN_NOT_FOUND')
    })

    it('resetsHm2SaasPlanStateAndSequenceDeterministically', 0, async () => {
      const repository = new DemoPlatformAdminRepository()
      const input: SaasPlanInput = {
        planCode: 'RESET',
        name: '重置验证套餐',
        version: 'v1.0',
        status: 'DRAFT',
        priceLabel: '¥99 / 月',
        billingCycle: 'MONTHLY',
        deviceLimit: 5,
        memberLimit: 10,
        features: ['重置验证']
      }
      const first = await repository.saveSaasPlan('', input)
      await repository.resetDemo()
      const second = await repository.saveSaasPlan('', input)
      await repository.resetDemo()
      const third = await repository.saveSaasPlan('', input)
      expect(second.planId).assertEqual(first.planId)
      expect(third.planId).assertEqual(first.planId)
    })

    it('resolvesPlatformAccountTenantsForExplicitEntitlementNavigation', 0, async () => {
      const repository = new DemoPlatformAdminRepository()
      const adminTenants = await repository.accountTenants('2011')
      expect(adminTenants.length).assertEqual(1)
      expect(adminTenants[0].tenantId).assertEqual('preview-tenant-01')
      expect(adminTenants[0].tenantCode).assertEqual('edge-lab')
      expect(adminTenants[0].name).assertEqual('边缘网络实验室')
      const account = await repository.accountDetail('2011')
      expect(account.username).assertEqual('lab-admin')
      expect(account.nickname).assertEqual('网络管理员')
      expect((await repository.accountTenants('2108')).length).assertEqual(0)

      let errorKey = ''
      try {
        await repository.accountTenants('missing-account')
      } catch (error) {
        errorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(errorKey).assertEqual('ACCOUNT_NOT_FOUND')
    })

    it('clearsHm2ManagedTenantCacheAndResetsState', 0, async () => {
      const repository = new DemoPlatformAdminRepository()
      repository.cacheManagedTenant('preview-tenant-02')
      expect(repository.managedTenantCacheId()).assertEqual('preview-tenant-02')
      repository.clearManagedTenantCache()
      expect(repository.managedTenantCacheId()).assertEqual('')
      await repository.updateTenantStatus('preview-tenant-01', 'DISABLED')
      await repository.resetDemo()
      expect((await repository.tenantDetail('preview-tenant-01')).status).assertEqual('ACTIVE')
    })

    it('compensatesHm2PreferencesWhenResetFlushFails', 0, async () => {
      const storage = new FailingPutPreferenceStorage()
      const repository = new DemoPlatformAdminRepository(true, storage)
      await repository.updateTenantStatus('preview-tenant-01', 'DISABLED')
      const beforeReset = storage.value
      storage.compensationWrites = 0
      storage.failNextPut = true
      let failed = false
      try {
        await repository.resetDemo()
      } catch (_) {
        failed = true
      }
      expect(failed).assertTrue()
      expect(storage.compensationWrites).assertEqual(1)
      expect(storage.value).assertEqual(beforeReset)
      expect((await repository.tenantDetail('preview-tenant-01')).status).assertEqual('DISABLED')
    })

    it('compensatesHm2PreferencesWhenMutationFlushFails', 0, async () => {
      const storage = new FailingPutPreferenceStorage()
      const repository = new DemoPlatformAdminRepository(true, storage)
      await repository.updateTenantStatus('preview-tenant-01', 'DISABLED')
      const beforeMutation = storage.value
      storage.compensationWrites = 0
      storage.failNextPut = true
      let failed = false
      try {
        await repository.updateTenantStatus('preview-tenant-01', 'ACTIVE')
      } catch (_) {
        failed = true
      }
      expect(failed).assertTrue()
      expect(storage.compensationWrites).assertEqual(1)
      expect(storage.value).assertEqual(beforeMutation)
      expect((await repository.tenantDetail('preview-tenant-01')).status).assertEqual('DISABLED')
    })

    it('tracksHm2MutationsAcrossPageHideAndShow', 0, () => {
      const tracker = new PlatformAdminMutationTracker()
      const hiddenRevision = tracker.current()
      tracker.mark()
      expect(hiddenRevision).assertEqual(0)
      expect(tracker.current()).assertEqual(1)
    })

    it('isolatesHm2DemoFactoryAndCoversFrozenScenarios', 0, async () => {
      runtimeModeStore.activateDemo()
      const factory = new PlatformAdminRepositoryFactory()
      expect(factory.realRepositoryCreatedForTest()).assertFalse()
      factory.current()
      expect(factory.realRepositoryCreatedForTest()).assertFalse()

      const repository = factory.demoForTest()
      repository.setDemoScenario('EMPTY')
      expect((await repository.summary()).tenantTotal).assertEqual(0)
      expect((await repository.listTenants(1, 20, '', '')).total).assertEqual(0)

      repository.setDemoScenario('FILTER_EMPTY')
      expect((await repository.listTenants(1, 20, '边缘', '')).total).assertEqual(0)
      expect((await repository.listTenants(1, 20, '', '')).total).assertEqual(4)

      repository.setDemoScenario('LOADING')
      let loadingCompleted = false
      const loadingTask = repository.summary().then((): void => {
        loadingCompleted = true
      })
      await Promise.resolve()
      expect(loadingCompleted).assertFalse()
      await loadingTask
      expect(loadingCompleted).assertTrue()

      repository.setDemoScenario('PARTIAL_FAILURE')
      expect((await repository.listTenants(1, 20, '', '')).total).assertEqual(4)
      let partialStatus = 0
      try {
        await repository.summary()
      } catch (error) {
        partialStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(partialStatus).assertEqual(502)

      repository.setDemoScenario('FORBIDDEN')
      let forbiddenStatus = 0
      try {
        await repository.listAccounts(1, 20, '', '')
      } catch (error) {
        forbiddenStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(forbiddenStatus).assertEqual(403)

      repository.setDemoScenario('CONFLICT')
      let conflictStatus = 0
      try {
        await repository.updateTenantStatus('preview-tenant-01', 'DISABLED')
      } catch (error) {
        conflictStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(conflictStatus).assertEqual(409)

      repository.setDemoScenario('RATE_LIMITED')
      let rateStatus = 0
      try {
        await repository.listSaasPlans(1, 20, '', '')
      } catch (error) {
        rateStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(rateStatus).assertEqual(429)

      repository.setDemoScenario('DEPENDENCY_DOWN')
      let dependencyStatus = 0
      try {
        await repository.accountDetail('2108')
      } catch (error) {
        dependencyStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(dependencyStatus).assertEqual(503)

      await repository.resetDemo()
      expect(repository.demoScenario()).assertEqual('NORMAL')
      runtimeModeStore.activateReal()
    })

    it('keepsCompleteHm2RepositoryJourneyOffline', 0, async () => {
      runtimeModeStore.activateDemo()
      runtimeModeStore.resetNetworkSentinel()
      networkTransportFactory.resetCounters()
      const repository = platformAdminRepositoryFactory.demoForTest()
      await repository.summary()
      await repository.listTenants(1, 2, '', '')
      await repository.tenantDetail('preview-tenant-01')
      await repository.listTenantMembers('preview-tenant-01', '')
      await repository.listAccounts(1, 3, '', '')
      await repository.accountDetail('2108')
      const review = await repository.submitAccountDeletion('2108', '离线演示审核')
      await repository.accountReviewDetail(review.reviewId)
      const rejectedReview = await repository.decideAccountReview(review.reviewId, false, '离线驳回')
      expect(rejectedReview.status).assertEqual('REJECTED')
      await repository.resetDemo()
      const approval = await repository.submitAccountDeletion('2108', '离线演示批准')
      const approvedReview = await repository.decideAccountReview(approval.reviewId, true, '离线批准')
      const deletedAccount = await repository.accountDetail('2108')
      expect(approvedReview.status).assertEqual('APPROVED')
      expect(deletedAccount.status).assertEqual('DELETED')
      await repository.listSaasPlans(1, 20, '', '')
      await repository.saasPlanDetail('plan-pro')
      expect(runtimeModeStore.getBlockedNetworkAttempts()).assertEqual(0)
      expect(networkTransportFactory.snapshot().http).assertEqual(0)
      expect(networkTransportFactory.snapshot().webSocket).assertEqual(0)
      expect(networkTransportFactory.snapshot().mqtt).assertEqual(0)
      runtimeModeStore.activateReal()
    })

    it('keepsHm3BlacklistTenantScopedAndValidatesMutations', 0, async () => {
      const repository = new DemoTenantOpsRepository()
      const initial = await repository.listBlacklist('preview-tenant-01', { keyword: '' })
      expect(initial.length).assertEqual(2)
      expect((await repository.listBlacklist('preview-tenant-02', { keyword: '' })).length)
        .assertEqual(0)

      const created = await repository.addBlacklist(
        'preview-tenant-01',
        'aa:bb:cc:77:88:99',
        'HM-3 offline audit'
      )
      expect(created.mac).assertEqual('AA:BB:CC:77:88:99')
      expect((await repository.listBlacklist('preview-tenant-01', { keyword: '77:88' })).length)
        .assertEqual(1)

      let duplicateStatus = 0
      try {
        await repository.addBlacklist(
          'preview-tenant-01',
          'AA:BB:CC:77:88:99',
          'duplicate'
        )
      } catch (error) {
        duplicateStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(duplicateStatus).assertEqual(409)

      await repository.removeBlacklist('preview-tenant-01', created.id)
      expect((await repository.listBlacklist('preview-tenant-01', { keyword: '77:88' })).length)
        .assertEqual(0)
      await repository.resetDemo()
      expect((await repository.listBlacklist('preview-tenant-01', { keyword: '' })).length)
        .assertEqual(2)
    })

    it('keepsMemberMainNavigationInsideTenantBoundaries', 0, () => {
      const member: SessionSnapshot = {
        authenticated: true,
        accountState: 'ACTIVE',
        userId: 'member-1',
        username: 'member',
        nickname: '普通成员',
        role: 2,
        context: {
          contextType: 'TENANT',
          tenantId: 'tenant-1',
          tenantCode: 'tenant-1',
          tenantName: '成员工作区',
          tenantRole: 'MEMBER',
          contextVersion: 1,
          memberContextVersion: 1,
          tenantStatus: 'ACTIVE',
          writable: true,
          authorities: ['SESSION_READ']
        }
      }
      expect(hasTenantWorkspace(member)).assertTrue()
      expect(canReadAdminWorkspace(member)).assertFalse()
      expect(isPlatformWorkspace(member)).assertFalse()
      expect(roleLabel(member.role)).assertEqual('成员')
      expect(workspaceTitle(member)).assertEqual('成员工作区')
      expect(mainTabs(member).length).assertEqual(4)
      expect(mainTabKey(member, 1)).assertEqual('CONNECTIONS')
      expect(mainTabKey(member, 3)).assertEqual('ME')
      expect(mainRootRouteId(member, 0)).assertEqual('member/home')
      expect(mainRootRouteId(member, 1)).assertEqual('member/connections')
      expect(mainRootRouteId(member, 2)).assertEqual('member/services')
      expect(mainRootRouteId(member, 3)).assertEqual('me/home')
      expect(mainRootRouteId(member, 1) === mainRootRouteId(member, 2)).assertFalse()
      expect(mainTabRenderKey(member, mainTabs(member)[2]))
        .assertEqual('2:TENANT:member/services')
      expect(mainTabRenderKey(member, mainTabs(member)[3]))
        .assertEqual('2:TENANT:me/home')
    })

    it('isolatesHm3DeviceDataByTenant', 0, () => {
      const repository = new DemoTenantDataRepository()
      const edgeLab = repository.listDevices('preview-tenant-01', 1, 20, '')
      const branch = repository.listDevices('preview-tenant-02', 1, 20, '')
      expect(edgeLab.total).assertEqual(3)
      expect(branch.total).assertEqual(2)
      expect(edgeLab.records[0].deviceCode === branch.records[0].deviceCode).assertFalse()

      let crossTenantStatus = 0
      try {
        repository.deviceDetail('preview-tenant-02', String(edgeLab.records[0].nodeId))
      } catch (error) {
        crossTenantStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(crossTenantStatus).assertEqual(404)
    })

    it('supportsHm3DeviceCrudAndConflictRecovery', 0, () => {
      const repository = new DemoTenantDataRepository()
      const created = repository.createDevice('preview-tenant-01', {
        deviceCode: 'EDGE-DEMO-99',
        name: '验收设备',
        location: '移动测试区',
        ip: '192.168.99.1',
        maxClients: 16
      })
      expect(created.status).assertEqual(0)
      const updated = repository.updateDevice('preview-tenant-01', String(created.nodeId), {
        deviceCode: 'EDGE-DEMO-99',
        name: '验收设备已更新',
        location: '移动测试区',
        ip: '192.168.99.2',
        maxClients: 24
      })
      expect(updated.maxClients).assertEqual(24)

      let duplicateStatus = 0
      try {
        repository.createDevice('preview-tenant-01', {
          deviceCode: 'EDGE-DEMO-99',
          name: '重复设备',
          location: '',
          ip: '',
          maxClients: 8
        })
      } catch (error) {
        duplicateStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(duplicateStatus).assertEqual(409)
      expect(repository.deleteDevice(
        'preview-tenant-01',
        String(created.nodeId)
      ).status).assertEqual(-1)
      expect(repository.restoreDevice(
        'preview-tenant-01',
        String(created.nodeId)
      ).status).assertEqual(0)
    })

    it('supportsHm3SessionRevokeAndDuplicateConflict', 0, () => {
      const repository = new DemoTenantDataRepository()
      const sessions = repository.listSessions('preview-tenant-02', {
        current: 1,
        size: 20,
        mac: '',
        nodeId: '',
        userId: '',
        status: ''
      }, true)
      expect(sessions.total).assertEqual(1)
      const closed = repository.closeSession('preview-tenant-02', sessions.records[0].sessionId)
      expect(closed.status).assertEqual(0)
      let duplicateStatus = 0
      try {
        repository.closeSession('preview-tenant-02', closed.sessionId)
      } catch (error) {
        duplicateStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(duplicateStatus).assertEqual(409)
    })

    it('tracksHm3CommandAndWifiToTerminalState', 0, () => {
      const repository = new DemoTenantDataRepository()
      const command = repository.submitCommand(
        'preview-tenant-02',
        'EDGE-BJ-01',
        'KICK',
        'MANUAL_RESTART',
        null
      )
      const firstCommand = repository.findCommand(
        'preview-tenant-02',
        'EDGE-BJ-01',
        command.requestId
      )
      const finalCommand = repository.findCommand(
        'preview-tenant-02',
        'EDGE-BJ-01',
        command.requestId
      )
      expect(firstCommand?.status ?? -1).assertEqual(1)
      expect(finalCommand?.status ?? -1).assertEqual(2)

      const task = repository.stageWifi(
        'preview-tenant-02',
        'EDGE-BJ-01',
        'Branch-Secure',
        '12345678'
      )
      expect(repository.findWifi(
        'preview-tenant-02',
        'EDGE-BJ-01',
        task.requestId
      ).status).assertEqual(1)
      expect(repository.findWifi(
        'preview-tenant-02',
        'EDGE-BJ-01',
        task.requestId
      ).status).assertEqual(2)
      expect(repository.listSignals('preview-tenant-02', '201').length).assertEqual(2)
      expect(repository.listTraffic('preview-tenant-02', '201').length).assertEqual(3)
    })

    it('coversHm3DemoScenarioMatrix', 0, () => {
      const repository = new DemoTenantDataRepository()
      repository.setDemoScenario('EMPTY')
      expect(repository.listDevices('preview-tenant-01', 1, 20, '').total).assertEqual(0)
      repository.setDemoScenario('FILTER_EMPTY')
      expect(repository.listDevices('preview-tenant-01', 1, 20, 'EDGE').total).assertEqual(0)

      const scenarios: string[] = ['FORBIDDEN', 'RATE_LIMITED', 'DEPENDENCY_DOWN']
      const statuses: number[] = [403, 429, 503]
      for (let index = 0; index < scenarios.length; index += 1) {
        repository.setDemoScenario(scenarios[index] as
          'FORBIDDEN' | 'RATE_LIMITED' | 'DEPENDENCY_DOWN')
        let status = 0
        try {
          repository.listDevices('preview-tenant-01', 1, 20, '')
        } catch (error) {
          status = error instanceof ApiError ? error.httpStatus : 0
        }
        expect(status).assertEqual(statuses[index])
      }

      repository.setDemoScenario('PARTIAL_FAILURE')
      let partialStatus = 0
      try {
        repository.listTraffic('preview-tenant-01', '101')
      } catch (error) {
        partialStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(partialStatus).assertEqual(502)

      repository.setDemoScenario('CONFLICT')
      let conflictStatus = 0
      try {
        repository.deleteDevice('preview-tenant-01', '101')
      } catch (error) {
        conflictStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(conflictStatus).assertEqual(409)
      repository.reset()
      expect(repository.demoScenario()).assertEqual('NORMAL')
    })

    it('normalizesPersistedRuntimeModeWithoutFallingBackToDemo', 0, () => {
      expect(normalizeRuntimeMode('DEMO')).assertEqual(RuntimeMode.DEMO)
      expect(normalizeRuntimeMode('REAL')).assertEqual(RuntimeMode.REAL)
      expect(normalizeRuntimeMode('invalid')).assertEqual(RuntimeMode.REAL)
    })

    it('keepsHm4SecurityDataTenantScopedAndReadOnlyAudits', 0, () => {
      const repository = new DemoHm4SecurityRepository()
      const tenantOne = repository.listAlerts('preview-tenant-01', {
        current: 1, size: 20, level: '', status: '', mac: ''
      })
      const tenantTwo = repository.listAlerts('preview-tenant-02', {
        current: 1, size: 20, level: '', status: '', mac: ''
      })
      expect(tenantOne.records[0].id === tenantTwo.records[0].id).assertFalse()
      expect(repository.listAudits('preview-tenant-01', '').length > 0).assertTrue()
      let missingAudit = 0
      try {
        repository.auditDetail('preview-tenant-02', tenantOne.records[0].id)
      } catch (error) {
        missingAudit = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(missingAudit).assertEqual(404)
    })

    it('rejectsHm4UnauthorizedDuplicateStaleAndScenarioAlertHandling', 0, () => {
      const repository = new DemoHm4SecurityRepository()
      const alertId = repository.listAlerts('preview-tenant-01', {
        current: 1, size: 20, level: '', status: '', mac: ''
      }).records[0].id
      let unauthorized = 0
      try {
        repository.handleAlert('preview-tenant-01', alertId, 'delegate', false, 0)
      } catch (error) {
        unauthorized = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(unauthorized).assertEqual(403)
      expect(repository.handleAlert('preview-tenant-01', alertId, 'tenantadmin', true, 0).version).assertEqual(1)
      let duplicate = 0
      try {
        repository.handleAlert('preview-tenant-01', alertId, 'tenantadmin', true, 1)
      } catch (error) {
        duplicate = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(duplicate).assertEqual(409)
      repository.setScenario('CONFLICT')
      let scenarioConflict = 0
      try {
        repository.handleAlert('preview-tenant-01', alertId, 'tenantadmin', true, 1)
      } catch (error) {
        scenarioConflict = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(scenarioConflict).assertEqual(409)
    })

    it('preventsOlderHm4EventFromOverwritingHandledAlert', 0, () => {
      const repository = new DemoHm4SecurityRepository()
      const alertId = repository.listAlerts('preview-tenant-01', {
        current: 1, size: 20, level: '', status: '', mac: ''
      }).records[0].id
      expect(repository.handleAlert('preview-tenant-01', alertId, 'tenantadmin', true, 0).version).assertEqual(1)
      expect(repository.applyEvent('preview-tenant-01', alertId, 1)).assertFalse()
      expect(repository.alertVersion('preview-tenant-01', alertId)).assertEqual(1)
      expect(repository.applyEvent('preview-tenant-01', alertId, 2)).assertTrue()
      expect(repository.alertVersion('preview-tenant-01', alertId)).assertEqual(2)
    })

    it('rebuildsHm4DemoEventSourceAndResetsScenarioDeterministically', 0, () => {
      const repository = new DemoHm4SecurityRepository()
      const source = new DemoAlertEventSource()
      let firstEvents = 0
      let secondEvents = 0
      source.start('preview-tenant-01', 'NORMAL', repository, () => firstEvents += 1)
      source.replay(repository)
      expect(firstEvents).assertEqual(5)
      source.start('preview-tenant-02', 'EMPTY', repository, () => secondEvents += 1)
      source.replay(repository)
      expect(secondEvents).assertEqual(5)
      repository.setScenario('EMPTY')
      expect(repository.listRules('preview-tenant-01', '').length).assertEqual(0)
      repository.reset()
      expect(repository.getScenario()).assertEqual('NORMAL')
      expect(repository.listRules('preview-tenant-01', '').length > 0).assertTrue()
    })

    it('restoresPreviewAuthoritiesFromFixedAccountDefinitions', 0, () => {
      const restored = new PreviewSession()
      expect(restored.restore({
        authenticated: true,
        accountState: 'ACTIVE',
        userId: 'forged',
        username: 'member',
        nickname: '普通成员',
        role: 0,
        context: {
          contextType: 'PLATFORM',
          tenantId: '',
          tenantCode: '',
          tenantName: '系统管理',
          tenantRole: 'SUPER_ADMIN',
          contextVersion: 99,
          memberContextVersion: 99,
          tenantStatus: 'ACTIVE',
          writable: true,
          authorities: ['PLATFORM_ADMIN']
        }
      })).assertTrue()
      const snapshot = restored.getSnapshot()
      expect(snapshot.role).assertEqual(2)
      expect(snapshot.context?.contextType ?? '').assertEqual('TENANT')
      expect(snapshot.context?.tenantRole ?? '').assertEqual('MEMBER')
    })

    it('allowsOnlyRegisteredAccountNoticeTargets', 0, () => {
      expect(resolveNoticeTargetRoute('pages/ProfilePage')).assertEqual('pages/ProfilePage')
      expect(resolveNoticeTargetRoute('pages/SecurityPage')).assertEqual('pages/SecurityPage')
      expect(resolveNoticeTargetRoute('pages/LoginPage')).assertEqual('pages/MainPage')
      expect(resolveNoticeTargetRoute('pages/UnknownPage')).assertEqual('pages/MainPage')
    })

    it('keepsAllThreePreviewAccountJourneysOffline', 0, async () => {
      runtimeModeStore.activateDemo()
      runtimeModeStore.resetNetworkSentinel()
      networkTransportFactory.resetCounters()

      for (const account of previewAccounts()) {
        const preview = new PreviewSession()
        const snapshot = preview.tryLogin({
          loginType: 'username',
          account: account.account,
          password: '123456'
        })
        expect(snapshot === null).assertFalse()
        if (snapshot === null) continue

        if (snapshot.role === 0) {
          await repositoryFactory.tenant().listPlatformTenants(1, 20, '')
          preview.enterTenant('preview-tenant-01')
          await repositoryFactory.device().list(1, 20, '')
          await repositoryFactory.alert().list({
            current: 1,
            size: 20,
            level: '',
            status: '',
            mac: ''
          })
          preview.returnToPlatform()
        } else if (snapshot.role === 1) {
          await repositoryFactory.device().list(1, 20, '')
          await repositoryFactory.session().list({
            current: 1,
            size: 20,
            mac: '',
            nodeId: '',
            userId: '',
            status: ''
          }, true)
        } else {
          await repositoryFactory.session().list({
            current: 1,
            size: 20,
            mac: '',
            nodeId: '',
            userId: '',
            status: ''
          }, false)
        }
        preview.clear()
        expect(preview.getSnapshot().authenticated).assertFalse()
      }

      expect(runtimeModeStore.getBlockedNetworkAttempts()).assertEqual(0)
      expect(networkTransportFactory.snapshot().http).assertEqual(0)
      expect(networkTransportFactory.snapshot().webSocket).assertEqual(0)
      expect(networkTransportFactory.snapshot().mqtt).assertEqual(0)
      runtimeModeStore.activateReal()
    })

    it('usesDemoRepositoryWithoutOutboundAttempts', 0, async () => {
      runtimeModeStore.activateDemo()
      runtimeModeStore.resetNetworkSentinel()
      networkTransportFactory.resetCounters()
      expect(runtimeModeStore.getMode()).assertEqual(RuntimeMode.DEMO)
      const devices = await repositoryFactory.device().list(1, 20, '')
      expect(devices.records.length > 0).assertTrue()
      const registration = await publicAuthRepositoryFactory.current().register({
        username: 'local-demo',
        password: '123456',
        nickname: '本地演示',
        email: 'local@wifi.local',
        phone: null,
        emailCode: '123456',
        phoneCode: null
      })
      expect(registration.data.status).assertEqual('SUCCESS')
      expect(runtimeModeStore.getBlockedNetworkAttempts()).assertEqual(0)
      expect(networkTransportFactory.snapshot().http).assertEqual(0)
      expect(networkTransportFactory.snapshot().webSocket).assertEqual(0)
      expect(networkTransportFactory.snapshot().mqtt).assertEqual(0)

      let httpBlocked = false
      try {
        await httpClient.request<Object | null>({
          method: http.RequestMethod.GET,
          path: '/must-not-leave-device'
        })
      } catch (error) {
        httpBlocked = error instanceof ApiError && error.errorKey === 'DEMO_NETWORK_BLOCKED'
      }
      expect(httpBlocked).assertTrue()
      expect(runtimeModeStore.getBlockedNetworkAttempts()).assertEqual(1)

      alertSocketClient.start((): void => {}, (): void => {})
      alertSocketClient.stop()
      expect(runtimeModeStore.getBlockedNetworkAttempts()).assertEqual(2)
      expect(runtimeModeStore.getBlockedChannels()[0]).assertEqual('HTTP')
      expect(runtimeModeStore.getBlockedChannels()[1]).assertEqual('WEBSOCKET')
      expect(networkTransportFactory.snapshot().http).assertEqual(0)
      expect(networkTransportFactory.snapshot().webSocket).assertEqual(0)

      let mqttFactoryCalled = false
      let mqttBlocked = false
      try {
        networkTransportFactory.createMqtt<StubMqttTransport>(() => {
          mqttFactoryCalled = true
          return new StubMqttTransport()
        })
      } catch (error) {
        mqttBlocked = error instanceof ApiError && error.errorKey === 'DEMO_NETWORK_BLOCKED'
      }
      expect(mqttBlocked).assertTrue()
      expect(mqttFactoryCalled).assertFalse()
      expect(runtimeModeStore.getBlockedNetworkAttempts()).assertEqual(3)
      expect(runtimeModeStore.getBlockedChannels()[2]).assertEqual('MQTT')
      expect(networkTransportFactory.snapshot().mqtt).assertEqual(0)

      runtimeModeStore.activateReal()
      expect(runtimeModeStore.getMode()).assertEqual(RuntimeMode.REAL)
      expect(runtimeModeStore.getBlockedNetworkAttempts()).assertEqual(0)
      const mqtt = networkTransportFactory.createMqtt<StubMqttTransport>(
        (): StubMqttTransport => new StubMqttTransport()
      )
      expect(mqtt.channel).assertEqual('MQTT')
      expect(networkTransportFactory.snapshot().mqtt).assertEqual(1)
      networkTransportFactory.resetCounters()
    })

    it('coversHm4RuleWriteLifecycleAndDelegateReadOnly', 0, () => {
      const repository = new DemoHm4SecurityRepository()
      const tenantId = 'preview-tenant-01'
      const initial = repository.listRules(tenantId, '')
      const created = repository.saveRule(tenantId, {
        code: 'RULE-HM4-AUDIT',
        name: 'HM4 Audit Rule',
        level: 3,
        condition: '测试规则条件'
      }, null, true)
      expect(repository.listRules(tenantId, '')[0].id).assertEqual(created.id)

      const edited = repository.saveRule(tenantId, {
        code: 'RULE-HM4-AUDIT',
        name: 'HM4 Audit Rule Updated',
        level: 2,
        condition: '更新后的测试规则条件'
      }, created.id, true)
      expect(edited.name).assertEqual('HM4 Audit Rule Updated')
      expect(repository.toggleRule(tenantId, created.id, true).enabled).assertFalse()
      repository.deleteRule(tenantId, created.id, true)
      expect(repository.listRules(tenantId, '').length).assertEqual(initial.length)

      const beforeDelegate = repository.listRules(tenantId, '')
      let delegateStatus = 0
      try {
        repository.saveRule(tenantId, {
          code: 'RULE-DELEGATE-DENIED',
          name: 'Delegate Denied',
          level: 1,
          condition: '平台代管只读'
        }, null, false)
      } catch (error) {
        delegateStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(delegateStatus).assertEqual(403)
      const afterDelegate = repository.listRules(tenantId, '')
      expect(afterDelegate.length).assertEqual(beforeDelegate.length)
      expect(afterDelegate[0].id).assertEqual(beforeDelegate[0].id)
    })

    it('coversHm4ScenarioMatrixAndDeterministicReset', 0, () => {
      const repository = new DemoHm4SecurityRepository()
      const tenantId = 'preview-tenant-01'
      const query: AlertQuery = { current: 1, size: 20, level: '', status: '', mac: '' }

      repository.setScenario('EMPTY')
      expect(repository.listAlerts(tenantId, query).total).assertEqual(0)
      expect(repository.listRules(tenantId, '').length).assertEqual(0)
      expect(repository.listAudits(tenantId, '').length).assertEqual(0)

      repository.setScenario('FILTER_EMPTY')
      expect(repository.listAlerts(tenantId, query).total).assertEqual(0)
      expect(repository.listRules(tenantId, 'RULE').length).assertEqual(0)
      expect(repository.listAudits(tenantId, 'ALERT').length).assertEqual(0)

      const unavailableScenarios: string[] = ['FORBIDDEN', 'RATE_LIMITED', 'DEPENDENCY_DOWN']
      const unavailableStatuses: number[] = [403, 429, 503]
      for (let index = 0; index < unavailableScenarios.length; index += 1) {
        repository.setScenario(unavailableScenarios[index] as 'FORBIDDEN' | 'RATE_LIMITED' | 'DEPENDENCY_DOWN')
        let status = 0
        try {
          repository.analytics(tenantId)
        } catch (error) {
          status = error instanceof ApiError ? error.httpStatus : 0
        }
        expect(status).assertEqual(unavailableStatuses[index])
      }

      repository.setScenario('CONFLICT')
      let conflictStatus = 0
      try {
        repository.saveRule(tenantId, {
          code: 'RULE-HM4-CONFLICT',
          name: 'HM4 Conflict Rule',
          level: 2,
          condition: '冲突场景'
        }, null, true)
      } catch (error) {
        conflictStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(conflictStatus).assertEqual(409)

      repository.setScenario('PARTIAL_FAILURE')
      let partialStatus = 0
      let partialErrorKey = ''
      try {
        repository.analytics(tenantId)
      } catch (error) {
        partialStatus = error instanceof ApiError ? error.httpStatus : 0
        partialErrorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(partialStatus).assertEqual(502)
      expect(partialErrorKey).assertEqual('PARTIAL_FAILURE')
      expect(repository.listAlerts(tenantId, query).total).assertEqual(2)
      expect(repository.listRules(tenantId, '').length).assertEqual(2)
      expect(repository.listAudits(tenantId, '').length > 0).assertTrue()

      repository.reset()
      expect(repository.getScenario()).assertEqual('NORMAL')
      expect(repository.listAlerts(tenantId, query).total).assertEqual(2)
      expect(repository.listRules(tenantId, '').length).assertEqual(2)
    })

    it('keepsHm4DemoRepositoryAndEventSourceTransportFree', 0, () => {
      runtimeModeStore.activateDemo()
      runtimeModeStore.resetNetworkSentinel()
      networkTransportFactory.resetCounters()
      const repository = new DemoHm4SecurityRepository()
      const source = new DemoAlertEventSource()
      let eventCount = 0
      source.start('preview-tenant-01', 'NORMAL', repository, () => eventCount += 1)
      source.replay(repository)
      repository.listAlerts('preview-tenant-01', {
        current: 1, size: 20, level: '', status: '', mac: ''
      })
      repository.listRules('preview-tenant-01', '')
      repository.listAudits('preview-tenant-01', '')
      repository.analytics('preview-tenant-01')
      expect(eventCount).assertEqual(5)
      expect(runtimeModeStore.getBlockedNetworkAttempts()).assertEqual(0)
      expect(networkTransportFactory.snapshot().http).assertEqual(0)
      expect(networkTransportFactory.snapshot().webSocket).assertEqual(0)
      expect(networkTransportFactory.snapshot().mqtt).assertEqual(0)
      source.dispose()
      runtimeModeStore.activateReal()
    })

    it('keepsHm4RealSelectionOutOfDemoFallback', 0, async () => {
      runtimeModeStore.activateReal()
      let factoryErrorKey = ''
      try {
        await repositoryFactory.hm4Security().listRules('')
      } catch (error) {
        factoryErrorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(factoryErrorKey).assertEqual('REAL_API_PENDING')

      let directErrorKey = ''
      try {
        await new RealHm4SecurityRepository().analytics()
      } catch (error) {
        directErrorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(directErrorKey).assertEqual('REAL_API_PENDING')
      runtimeModeStore.activateDemo()
    })

    it('runsHm5OrderPaymentAndRefundWithIndependentRequestIds', 0, () => {
      const repository = new DemoHm5MemberRepository()
      const memberKey = 'preview-tenant-01|preview-member'
      const order = repository.createOrder(memberKey, '603', true)
      expect(order.status).assertEqual('PENDING_PAYMENT')
      expect(order.orderRequestId).assertEqual('ORDER-DEMO-0003')

      const payment = repository.createPayment(memberKey, order.id, true)
      expect(payment.status).assertEqual('SUCCEEDED')
      expect(payment.paymentRequestId).assertEqual('PAYMENT-DEMO-0002')
      expect(payment.paymentRequestId === order.orderRequestId).assertFalse()
      expect(repository.orderDetail(memberKey, order.id).status).assertEqual('PAID')

      const refund = repository.applyRefund(memberKey, order.id, '购买计划发生变化', true)
      expect(refund.status).assertEqual('PENDING')
      expect(refund.refundRequestId).assertEqual('REFUND-DEMO-0002')
      expect(refund.refundRequestId === payment.paymentRequestId).assertFalse()
      expect(repository.orderDetail(memberKey, order.id).status).assertEqual('REFUNDING')
    })

    it('rejectsHm5DuplicateUnauthorizedAndInvalidStateMutations', 0, () => {
      const repository = new DemoHm5MemberRepository()
      const memberKey = 'preview-tenant-01|preview-member'
      let unauthorizedStatus = 0
      try {
        repository.createOrder(memberKey, '603', false)
      } catch (error) {
        unauthorizedStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(unauthorizedStatus).assertEqual(403)

      let duplicateStatus = 0
      try {
        repository.createOrder(memberKey, '601', true)
      } catch (error) {
        duplicateStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(duplicateStatus).assertEqual(409)

      let paymentConflict = 0
      try {
        repository.createPayment(memberKey, '901', true)
      } catch (error) {
        paymentConflict = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(paymentConflict).assertEqual(409)

      const before = repository.locationPermission(memberKey)
      expect(before.granted).assertFalse()
      expect(repository.setLocationPermission(memberKey, true, true).granted).assertTrue()
      repository.clearLocationHistory(memberKey, true)
      expect(repository.locationHistory(memberKey).length).assertEqual(0)
    })

    it('keepsHm5TenantRefundReviewIsolatedAndStateful', 0, () => {
      const repository = new DemoHm5MemberRepository()
      const tenantOne = repository.tenantRefunds('preview-tenant-01')
      const tenantTwo = repository.tenantRefunds('preview-tenant-02')
      expect(tenantOne.length).assertEqual(1)
      expect(tenantTwo.length).assertEqual(1)

      const approved = repository.reviewTenantRefund(
        'preview-tenant-01', tenantOne[0].id, true, '材料完整，同意退款', true)
      expect(approved.status).assertEqual('APPROVED')
      expect(repository.tenantRefundDetail('preview-tenant-01', tenantOne[0].id).status)
        .assertEqual('APPROVED')
      expect(repository.tenantRefundDetail('preview-tenant-02', tenantTwo[0].id).status)
        .assertEqual('PENDING')

      let delegateDenied = 0
      try {
        repository.reviewTenantRefund(
          'preview-tenant-02', tenantTwo[0].id, false, '无审核权限', false)
      } catch (error) {
        delegateDenied = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(delegateDenied).assertEqual(403)
    })

    it('coversHm5ScenarioMatrixAndDeterministicReset', 0, () => {
      const repository = new DemoHm5MemberRepository()
      const memberKey = 'preview-tenant-01|preview-member'

      repository.setScenario('EMPTY')
      expect(repository.summary(memberKey).activeConnections).assertEqual(0)
      expect(repository.orders(memberKey).length).assertEqual(0)
      let activeSessionRequired = ''
      try {
        repository.createOrder(memberKey, '603', true)
      } catch (error) {
        activeSessionRequired = error instanceof ApiError ? error.errorKey : ''
      }
      expect(activeSessionRequired).assertEqual('ACTIVE_SESSION_REQUIRED')

      repository.setScenario('PARTIAL_FAILURE')
      let partialStatus = 0
      try {
        repository.purchases(memberKey)
      } catch (error) {
        partialStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(partialStatus).assertEqual(502)
      expect(repository.orders(memberKey).length).assertEqual(2)
      expect(repository.entitlement(memberKey).status).assertEqual('ACTIVE')

      repository.setScenario('FORBIDDEN')
      let forbiddenStatus = 0
      try {
        repository.summary(memberKey)
      } catch (error) {
        forbiddenStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(forbiddenStatus).assertEqual(403)

      repository.reset()
      expect(repository.getScenario()).assertEqual('NORMAL')
      const resetOrder = repository.createOrder(memberKey, '603', true)
      expect(resetOrder.id).assertEqual('910')
      expect(resetOrder.orderRequestId).assertEqual('ORDER-DEMO-0003')
    })

    it('keepsHm5DemoTransportFreeAndRealMethodsExplicit', 0, async () => {
      runtimeModeStore.activateDemo()
      runtimeModeStore.resetNetworkSentinel()
      networkTransportFactory.resetCounters()
      const repository = new DemoHm5MemberRepository()
      const memberKey = 'preview-tenant-01|preview-member'
      repository.summary(memberKey)
      repository.products(memberKey, '')
      repository.orders(memberKey)
      repository.refunds(memberKey)
      repository.locationHistory(memberKey)
      expect(runtimeModeStore.getBlockedNetworkAttempts()).assertEqual(0)
      expect(networkTransportFactory.snapshot().http).assertEqual(0)
      expect(networkTransportFactory.snapshot().webSocket).assertEqual(0)
      expect(networkTransportFactory.snapshot().mqtt).assertEqual(0)

      let realErrorKey = ''
      try {
        await new RealHm5MemberRepository().reviewRefund('REFUND-1', true, '')
      } catch (error) {
        realErrorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(realErrorKey).assertEqual('REAL_API_PENDING')
      runtimeModeStore.activateReal()
      let factoryErrorKey = ''
      try {
        await repositoryFactory.hm5Member().summary()
      } catch (error) {
        factoryErrorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(factoryErrorKey).assertEqual('AUTHENTICATION_REQUIRED')
      runtimeModeStore.activateDemo()
    })

    it('mapsHm5BusinessIdentifiersWithoutSyntheticNumericIds', 0, () => {
      const product = mapHm5Product({
        productCode: 'DURATION-30D',
        name: '30 天时长包',
        entitlementMode: 'DURATION',
        grantSeconds: 2592000,
        amountCents: 3990
      })
      expect(product.id).assertEqual('DURATION-30D')
      expect(product.quotaLabel).assertEqual('30.0 天')
      expect(product.price).assertEqual(39.9)

      const order = mapHm5Order({
        orderNo: 'ORDER-20260901-001',
        productCode: 'DURATION-30D',
        entitlementMode: 'DURATION',
        amountCents: 3990,
        status: 'PAID',
        createTime: '2026-09-01T10:00:00'
      }, product.name)
      expect(order.id).assertEqual('ORDER-20260901-001')
      expect(order.productId).assertEqual('DURATION-30D')
      expect(order.status).assertEqual('PAID')
    })

    it('mapsHm5EntitlementAndRefundWireSemantics', 0, () => {
      const entitlement = mapHm5Entitlement({
        entitlementId: 88,
        mode: 'DURATION',
        remainingSeconds: 5400,
        subscriptionEndTime: '2026-09-30T23:59:59',
        status: 1
      })
      expect(entitlement.remainingLabel).assertEqual('1.5 小时')
      expect(entitlement.status).assertEqual('ACTIVE')

      const refund = mapHm5Refund({
        refundNo: 'REFUND-001',
        orderNo: 'ORDER-001',
        purchaseId: 'PURCHASE-001',
        requestId: 'REQ-001',
        status: 'SUCCEEDED',
        reason: '计划变更',
        requestedAmountCents: 3990,
        refundAmountCents: 3990,
        reviewComment: '通过',
        createTime: '2026-09-01T11:00:00'
      }, '30 天时长包')
      expect(refund.id).assertEqual('REFUND-001')
      expect(refund.orderId).assertEqual('ORDER-001')
      expect(refund.status).assertEqual('APPROVED')
    })

    it('coversHm6MapStatesAndAnalyticsPartialFailure', 0, () => {
      const repository = new DemoHm6LocationRepository()
      const tenantId = 'preview-tenant-01'
      const ready = repository.gis(tenantId)
      expect(ready.state).assertEqual('READY')
      expect(ready.track.length).assertEqual(3)
      expect(ready.stays.length).assertEqual(2)
      expect(ready.heat.length).assertEqual(3)
      expect(ready.coverage.length).assertEqual(2)
      expect(repository.analytics(tenantId).signals.length).assertEqual(3)

      repository.setScenario('PARTIAL_FAILURE')
      const lowAccuracy = repository.gis(tenantId)
      expect(lowAccuracy.state).assertEqual('LOW_ACCURACY')
      expect(lowAccuracy.accuracyMeters).assertEqual(120)
      let partialStatus = 0
      try {
        repository.analytics(tenantId)
      } catch (error) {
        partialStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(partialStatus).assertEqual(502)

      repository.setScenario('EMPTY')
      expect(repository.gis(tenantId).state).assertEqual('NO_DATA')
      repository.setScenario('FORBIDDEN')
      expect(repository.gis(tenantId).state).assertEqual('PERMISSION_DENIED')
    })

    it('validatesAndMutatesHm6GeofencesWithAuthorization', 0, () => {
      const repository = new DemoHm6LocationRepository()
      const tenantId = 'preview-tenant-01'
      let invalidErrorKey = ''
      try {
        repository.saveGeofence(tenantId, {
          code: 'x', name: 'x', shape: 'CIRCLE', centerLatitude: 91,
          centerLongitude: 121.4737, radiusMeters: 10, vertexCount: 0
        }, null, true)
      } catch (error) {
        invalidErrorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(invalidErrorKey).assertEqual('GEOFENCE_INPUT_INVALID')

      let forbiddenStatus = 0
      try {
        repository.toggleGeofence(tenantId, 1700, false)
      } catch (error) {
        forbiddenStatus = error instanceof ApiError ? error.httpStatus : 0
      }
      expect(forbiddenStatus).assertEqual(403)

      const created = repository.saveGeofence(tenantId, {
        code: 'GEOFENCE-LAB', name: '实验室区域', shape: 'CIRCLE',
        centerLatitude: 31.2305, centerLongitude: 121.4738,
        radiusMeters: 120, vertexCount: 0
      }, null, true)
      expect(created.id).assertEqual(1750)
      expect(created.enabled).assertTrue()
      expect(repository.toggleGeofence(tenantId, created.id, true).enabled).assertFalse()
      repository.deleteGeofence(tenantId, created.id, true)
      expect(repository.geofences(tenantId, 'GEOFENCE-LAB').length).assertEqual(0)
    })

    it('isolatesAndDeterministicallyResetsHm6TenantData', 0, () => {
      const repository = new DemoHm6LocationRepository()
      const tenantOne = 'preview-tenant-01'
      const tenantTwo = 'preview-tenant-02'
      const created = repository.saveGeofence(tenantOne, {
        code: 'GEOFENCE-HM6', name: 'HM6 演示区域', shape: 'POLYGON',
        centerLatitude: 31.2306, centerLongitude: 121.4736,
        radiusMeters: 0, vertexCount: 5
      }, null, true)
      expect(created.id).assertEqual(1750)
      expect(repository.geofences(tenantOne, 'GEOFENCE-HM6').length).assertEqual(1)
      expect(repository.geofences(tenantTwo, 'GEOFENCE-HM6').length).assertEqual(0)
      expect(repository.locations(tenantOne, '')[0].subjectId)
        .assertEqual('MEMBER-A-01')
      expect(repository.locations(tenantTwo, '')[0].subjectId)
        .assertEqual('MEMBER-B-01')

      repository.reset()
      expect(repository.getScenario()).assertEqual('NORMAL')
      expect(repository.geofences(tenantOne, 'GEOFENCE-HM6').length).assertEqual(0)
      const resetCreated = repository.saveGeofence(tenantOne, {
        code: 'GEOFENCE-HM6', name: 'HM6 演示区域', shape: 'POLYGON',
        centerLatitude: 31.2306, centerLongitude: 121.4736,
        radiusMeters: 0, vertexCount: 5
      }, null, true)
      expect(resetCreated.id).assertEqual(1750)
    })

    it('keepsHm6DemoTransportFreeAndUnsafeRealMethodsPending', 0, async () => {
      runtimeModeStore.activateDemo()
      runtimeModeStore.resetNetworkSentinel()
      networkTransportFactory.resetCounters()
      const repository = new DemoHm6LocationRepository()
      repository.locations('preview-tenant-01', '')
      repository.gis('preview-tenant-01')
      repository.geofences('preview-tenant-01', '')
      repository.geofenceEvents('preview-tenant-01', 1700, '')
      repository.analytics('preview-tenant-01')
      expect(runtimeModeStore.getBlockedNetworkAttempts()).assertEqual(0)
      expect(networkTransportFactory.snapshot().http).assertEqual(0)
      expect(networkTransportFactory.snapshot().webSocket).assertEqual(0)
      expect(networkTransportFactory.snapshot().mqtt).assertEqual(0)

      let realErrorKey = ''
      try {
        await new RealHm6LocationRepository().analytics()
      } catch (error) {
        realErrorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(realErrorKey).assertEqual('REAL_API_PENDING')
      runtimeModeStore.activateReal()
      let factoryErrorKey = ''
      try {
        await repositoryFactory.hm6Location().locations('')
      } catch (error) {
        factoryErrorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(factoryErrorKey).assertEqual('AUTHENTICATION_REQUIRED')
      runtimeModeStore.activateDemo()
    })

    it('mapsHm6LocationAndGeofenceWireContracts', 0, () => {
      const location = mapHm6Location({
        id: 51,
        userId: 7,
        sessionId: 19,
        deviceCode: 'EDGE-01',
        latitude: 31.2304,
        longitude: 121.4737,
        accuracy: 8.5,
        reportTime: '2026-09-01T12:00:00'
      })
      expect(location.id).assertEqual(51)
      expect(location.subjectId).assertEqual('USER-7')
      expect(location.subjectType).assertEqual('MEMBER')
      expect(location.accuracyMeters).assertEqual(8.5)

      const geofence = mapHm6Geofence({
        fenceId: 71,
        name: '办公区',
        centerLatitude: 31.23,
        centerLongitude: 121.47,
        radiusMeters: 120,
        enabled: 1,
        updateTime: '2026-09-01T12:05:00'
      })
      expect(geofence.id).assertEqual(71)
      expect(geofence.shape).assertEqual('CIRCLE')
      expect(geofence.enabled).assertTrue()
    })

    it('mapsHm6GeofenceEventWithoutLeakingWireFields', 0, () => {
      const event = mapHm6GeofenceEvent({
        eventId: 81,
        fenceId: 71,
        fenceName: '办公区',
        deviceCode: 'EDGE-01',
        mac: 'AA:BB:CC:DD:EE:FF',
        eventType: 'EXIT',
        eventTime: '2026-09-01T12:10:00'
      })
      expect(event.id).assertEqual(81)
      expect(event.geofenceId).assertEqual(71)
      expect(event.eventType).assertEqual('EXIT')
      expect(event.subjectName).assertEqual('EDGE-01')
    })

    it('coversHm7PlatformCapabilitiesFiltersAndActions', 0, async () => {
      const repository = new DemoHm7CapabilityRepository()
      const context: Hm7RequestContext = {
        scope: 'PLATFORM', role: 0, userId: '1', tenantId: '',
        tenantRole: 'PLATFORM_ADMIN', contextType: 'PLATFORM'
      }
      expect((await repository.list(context, 'SAAS', '', '')).length).assertEqual(2)
      expect((await repository.list(context, 'MARKETPLACE', '访客', '')).length).assertEqual(1)
      expect((await repository.list(context, 'AI_REVIEW', '', 'MANUAL')).length).assertEqual(1)
      const failedJob = (await repository.list(context, 'RUNTIME', '', 'FAILED'))[0]
      const recovered = await repository.act(context, 'RUNTIME', failedJob.id, '人工恢复')
      expect(recovered.record.status).assertEqual('RECOVERED')
      expect(recovered.requestId).assertEqual('HM7-0001')
      expect((await repository.list(context, 'AUDIT', '', '')).length).assertEqual(2)
    })

    it('isolatesHm7TenantsAndKeepsPlatformDelegateReadOnly', 0, async () => {
      const repository = new DemoHm7CapabilityRepository()
      const tenantOne: Hm7RequestContext = {
        scope: 'TENANT', role: 1, userId: '2', tenantId: 'preview-tenant-01',
        tenantRole: 'TENANT_ADMIN', contextType: 'TENANT'
      }
      const tenantTwo: Hm7RequestContext = {
        scope: 'TENANT', role: 1, userId: '2', tenantId: 'preview-tenant-02',
        tenantRole: 'TENANT_ADMIN', contextType: 'TENANT'
      }
      const secondAdmin: Hm7RequestContext = {
        scope: 'TENANT', role: 1, userId: '4', tenantId: 'preview-tenant-01',
        tenantRole: 'TENANT_ADMIN', contextType: 'TENANT'
      }
      const saved = await repository.save(tenantOne, 'CONTENT', 0, {
        title: 'HM7 组织公告', subtitle: '仅组织一可见', detail: '租户隔离验证'
      })
      expect((await repository.list(tenantOne, 'CONTENT', 'HM7', '')).length).assertEqual(1)
      expect((await repository.list(secondAdmin, 'CONTENT', 'HM7', '')).length).assertEqual(1)
      expect((await repository.list(tenantTwo, 'CONTENT', 'HM7', '')).length).assertEqual(0)
      expect(saved.requestId).assertEqual('HM7-0001')

      const delegate: Hm7RequestContext = {
        scope: 'TENANT', role: 0, userId: '1', tenantId: 'preview-tenant-01',
        subjectUserId: '2001', tenantRole: 'PLATFORM_ADMIN', contextType: 'PLATFORM_TENANT'
      }
      expect((await repository.list(delegate, 'CONTENT', 'HM7', '')).length).assertEqual(1)
      let errorKey = ''
      try {
        await repository.act(delegate, 'CONTENT', saved.record.id, '撤回')
      } catch (error) {
        errorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(errorKey).assertEqual('PLATFORM_DELEGATE_READ_ONLY')
      const entitlements = await repository.list(delegate, 'ENTITLEMENT', '', '')
      expect(entitlements.filter((item): boolean => item.status === 'ACTIVE').length).assertEqual(1)
      const entitlement = entitlements[0]
      const adjusted = await repository.act(delegate, 'ENTITLEMENT', entitlement.id, '调整权益')
      expect(adjusted.record.status).assertEqual('ACTIVE')
      expect(adjusted.requestId).assertEqual('HM7-0002')

      const sameAccountOtherAdmin: Hm7RequestContext = {
        scope: 'TENANT', role: 0, userId: 'other-platform-admin',
        tenantId: 'preview-tenant-01', subjectUserId: '2001',
        tenantRole: 'PLATFORM_ADMIN', contextType: 'PLATFORM_TENANT'
      }
      await repository.save(delegate, 'ENTITLEMENT', entitlement.id, {
        title: '负责人专属权益', subtitle: entitlement.subtitle, detail: entitlement.detail
      })
      expect((await repository.detail(
        sameAccountOtherAdmin, 'ENTITLEMENT', entitlement.id)).title)
        .assertEqual('负责人专属权益')

      const otherAccount: Hm7RequestContext = {
        scope: 'TENANT', role: 0, userId: '1', tenantId: 'preview-tenant-01',
        subjectUserId: '2011', tenantRole: 'PLATFORM_ADMIN', contextType: 'PLATFORM_TENANT'
      }
      expect((await repository.list(otherAccount, 'ENTITLEMENT', '负责人专属', '')).length)
        .assertEqual(0)

      const missingAccount: Hm7RequestContext = {
        scope: 'TENANT', role: 0, userId: '1', tenantId: 'preview-tenant-01',
        tenantRole: 'PLATFORM_ADMIN', contextType: 'PLATFORM_TENANT'
      }
      let accountError = ''
      try {
        await repository.list(missingAccount, 'ENTITLEMENT', '', '')
      } catch (error) {
        accountError = error instanceof ApiError ? error.errorKey : ''
      }
      expect(accountError).assertEqual('ACCOUNT_CONTEXT_REQUIRED')
    })

    it('rejectsUnknownHm7IdentifiersAndAmbiguousCommandsWithoutMutation', 0, async () => {
      const repository = new DemoHm7CapabilityRepository()
      const context: Hm7RequestContext = {
        scope: 'TENANT', role: 1, userId: '2', tenantId: 'preview-tenant-01',
        tenantRole: 'TENANT_ADMIN', contextType: 'TENANT'
      }
      const initial = await repository.list(context, 'CONTENT', '', '')
      const target = initial[0]
      let detailError = ''
      let actionError = ''
      let updateError = ''
      let commandError = ''
      try {
        await repository.detail(context, 'CONTENT', 999999)
      } catch (error) {
        detailError = error instanceof ApiError ? error.errorKey : ''
      }
      try {
        await repository.act(context, 'CONTENT', 999999, '发布')
      } catch (error) {
        actionError = error instanceof ApiError ? error.errorKey : ''
      }
      try {
        await repository.save(context, 'CONTENT', 999999, {
          title: '未知记录', subtitle: '不得创建', detail: '不得改变集合'
        })
      } catch (error) {
        updateError = error instanceof ApiError ? error.errorKey : ''
      }
      let negativeUpdateError = ''
      try {
        await repository.save(context, 'CONTENT', -47, {
          title: '负数未知记录', subtitle: '不得创建', detail: '不得改变集合'
        })
      } catch (error) {
        negativeUpdateError = error instanceof ApiError ? error.errorKey : ''
      }
      try {
        await repository.act(context, 'CONTENT', target.id, '发布并撤回')
      } catch (error) {
        commandError = error instanceof ApiError ? error.errorKey : ''
      }
      const after = await repository.list(context, 'CONTENT', '', '')
      expect(detailError).assertEqual('HM7_RECORD_NOT_FOUND')
      expect(actionError).assertEqual('HM7_RECORD_NOT_FOUND')
      expect(updateError).assertEqual('HM7_RECORD_NOT_FOUND')
      expect(negativeUpdateError).assertEqual('HM7_RECORD_NOT_FOUND')
      expect(commandError).assertEqual('HM7_ACTION_INVALID')
      expect(after.length).assertEqual(initial.length)
      expect(after[0].status).assertEqual(target.status)
      expect(after[0].title).assertEqual(target.title)

      let precedenceError = ''
      try {
        await repository.save(context, 'CONTENT', 999999, {
          title: '',
          subtitle: '',
          detail: ''
        })
      } catch (error) {
        precedenceError = error instanceof ApiError ? error.errorKey : ''
      }
      expect(precedenceError).assertEqual('HM7_RECORD_NOT_FOUND')
    })

    it('keepsHm7SeedIdentityStableAcrossPageVisitOrder', 0, async () => {
      const tenant: Hm7RequestContext = {
        scope: 'TENANT', role: 1, userId: '2', tenantId: 'preview-tenant-01',
        tenantRole: 'TENANT_ADMIN', contextType: 'TENANT'
      }
      const platform: Hm7RequestContext = {
        scope: 'PLATFORM', role: 0, userId: '1', tenantId: '',
        tenantRole: 'PLATFORM_ADMIN', contextType: 'PLATFORM'
      }
      const direct = new DemoHm7CapabilityRepository()
      const reordered = new DemoHm7CapabilityRepository()
      const directContent = await direct.list(tenant, 'CONTENT', '', '')
      await reordered.list(platform, 'SAAS', '', '')
      await reordered.list(tenant, 'SUPPORT', '', '')
      const reorderedContent = await reordered.list(tenant, 'CONTENT', '', '')
      expect(reorderedContent[0].id).assertEqual(directContent[0].id)
      expect(reorderedContent[1].id).assertEqual(directContent[1].id)
    })

    it('isolatesHm7MemberPrivateRecordsByTenantAndOwner', 0, async () => {
      const repository = new DemoHm7CapabilityRepository()
      const first: Hm7RequestContext = {
        scope: 'MEMBER', role: 2, userId: 'member-a', tenantId: 'preview-tenant-01',
        tenantRole: 'MEMBER', contextType: 'TENANT'
      }
      const second: Hm7RequestContext = {
        scope: 'MEMBER', role: 2, userId: 'member-b', tenantId: 'preview-tenant-01',
        tenantRole: 'MEMBER', contextType: 'TENANT'
      }
      const otherTenant: Hm7RequestContext = {
        scope: 'MEMBER', role: 2, userId: 'member-a', tenantId: 'preview-tenant-02',
        tenantRole: 'MEMBER', contextType: 'TENANT'
      }
      await repository.save(first, 'SUPPORT', 0, {
        title: '成员 A 工单', subtitle: '私有', detail: '仅本人可见'
      })
      expect((await repository.list(first, 'SUPPORT', '成员 A', '')).length).assertEqual(1)
      expect((await repository.list(second, 'SUPPORT', '成员 A', '')).length).assertEqual(0)
      expect((await repository.list(otherTenant, 'SUPPORT', '成员 A', '')).length).assertEqual(0)
    })

    it('rechecksHm7OwnershipAndCommandsWithAlternateIdentities', 0, async () => {
      const repository = new DemoHm7CapabilityRepository()
      const tenantTwoAdminA: Hm7RequestContext = {
        scope: 'TENANT', role: 1, userId: 'admin-a',
        tenantId: 'preview-tenant-02', tenantRole: 'TENANT_ADMIN', contextType: 'TENANT'
      }
      const tenantTwoAdminB: Hm7RequestContext = {
        scope: 'TENANT', role: 1, userId: 'admin-b',
        tenantId: 'preview-tenant-02', tenantRole: 'TENANT_OWNER', contextType: 'TENANT'
      }
      const tenantThreeAdmin: Hm7RequestContext = {
        scope: 'TENANT', role: 1, userId: 'admin-a',
        tenantId: 'preview-tenant-03', tenantRole: 'TENANT_ADMIN', contextType: 'TENANT'
      }
      const announcement = await repository.save(tenantTwoAdminA, 'CONTENT', 0, {
        title: '第二组织公告', subtitle: '共享聚合复审', detail: '不同管理员读取同一记录'
      })
      expect((await repository.detail(
        tenantTwoAdminB, 'CONTENT', announcement.record.id)).title)
        .assertEqual('第二组织公告')
      expect((await repository.list(
        tenantThreeAdmin, 'CONTENT', '第二组织公告', '')).length).assertEqual(0)

      const support = (await repository.list(tenantTwoAdminA, 'SUPPORT', '', ''))[0]
      const assigned = await repository.act(
        tenantTwoAdminA, 'SUPPORT', support.id, '回复并分派')
      expect(assigned.record.status).assertEqual('ASSIGNED')
      let invalidCommand = ''
      try {
        await repository.act(
          tenantTwoAdminA, 'SUPPORT', support.id, '回复并分派后关闭')
      } catch (error) {
        invalidCommand = error instanceof ApiError ? error.errorKey : ''
      }
      expect(invalidCommand).assertEqual('HM7_ACTION_INVALID')
      expect((await repository.detail(
        tenantTwoAdminB, 'SUPPORT', support.id)).status).assertEqual('ASSIGNED')

      let missingError = ''
      try {
        await repository.detail(tenantTwoAdminA, 'CONTENT', 456789)
      } catch (error) {
        missingError = error instanceof ApiError ? error.errorKey : ''
      }
      expect(missingError).assertEqual('HM7_RECORD_NOT_FOUND')
    })

    it('supportsHm7MemberWorkflowsAndDeterministicReset', 0, async () => {
      const repository = new DemoHm7CapabilityRepository()
      const member: Hm7RequestContext = {
        scope: 'MEMBER', role: 2, userId: '3', tenantId: 'preview-tenant-01',
        tenantRole: 'MEMBER', contextType: 'TENANT'
      }
      const support = await repository.save(member, 'SUPPORT', 0, {
        title: '成员新工单', subtitle: '连接问题', detail: '会议区连接不稳定'
      })
      expect(support.record.status).assertEqual('DRAFT')
      expect(support.requestId).assertEqual('HM7-0001')
      const message = (await repository.list(member, 'NOTICE', '', 'UNREAD'))[0]
      const read = await repository.act(member, 'NOTICE', message.id, '标记已读')
      expect(read.record.status).assertEqual('READ')
      expect(read.requestId).assertEqual('HM7-0002')

      repository.setScenario('FILTER_EMPTY')
      expect((await repository.list(member, 'SUPPORT', '不存在', '')).length).assertEqual(0)
      repository.reset()
      const resetSupport = await repository.save(member, 'SUPPORT', 0, {
        title: '成员新工单', subtitle: '连接问题', detail: '确定性重置'
      })
      expect(resetSupport.record.id).assertEqual(9000)
      expect(resetSupport.requestId).assertEqual('HM7-0001')
      repository.reset()
      const secondReset = await repository.save(member, 'SUPPORT', 0, {
        title: '成员新工单', subtitle: '连接问题', detail: '确定性重置'
      })
      expect(secondReset.record.id).assertEqual(resetSupport.record.id)
      expect(secondReset.requestId).assertEqual(resetSupport.requestId)
    })

    it('keepsHm7DemoTransportFreeAndRealPending', 0, async () => {
      runtimeModeStore.activateDemo()
      runtimeModeStore.resetNetworkSentinel()
      networkTransportFactory.resetCounters()
      const context: Hm7RequestContext = {
        scope: 'PLATFORM', role: 0, userId: '1', tenantId: '',
        tenantRole: 'PLATFORM_ADMIN', contextType: 'PLATFORM'
      }
      const repository = new DemoHm7CapabilityRepository()
      await repository.list(context, 'SAAS', '', '')
      await repository.list(context, 'MARKETPLACE', '', '')
      await repository.list(context, 'RUNTIME', '', '')
      expect(runtimeModeStore.getBlockedNetworkAttempts()).assertEqual(0)
      expect(networkTransportFactory.snapshot().http).assertEqual(0)
      expect(networkTransportFactory.snapshot().webSocket).assertEqual(0)
      expect(networkTransportFactory.snapshot().mqtt).assertEqual(0)

      let realErrorKey = ''
      try {
        await new RealHm7CapabilityRepository().list(context, 'SAAS', '', '')
      } catch (error) {
        realErrorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(realErrorKey).assertEqual('REAL_API_PENDING')
      runtimeModeStore.activateReal()
      let factoryErrorKey = ''
      try {
        await repositoryFactory.hm7Capability().list(context, 'SAAS', '', '')
      } catch (error) {
        factoryErrorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(factoryErrorKey).assertEqual('REAL_API_PENDING')
      runtimeModeStore.activateDemo()
    })

    it('routesHm7RealCapabilitiesByConcreteBackendReadiness', 0, () => {
      const entitlement = realHm7CapabilityRoute('ENTITLEMENT')
      expect(entitlement.state).assertEqual('DELEGATED')
      expect(entitlement.pathPrefix).assertEqual('/entitlements')

      const marketplace = realHm7CapabilityRoute('MARKETPLACE')
      expect(marketplace.state).assertEqual('PUBLIC_API_PENDING')
      expect(marketplace.owner).assertEqual('marketplace-service')

      const audit = realHm7CapabilityRoute('AUDIT')
      expect(audit.state).assertEqual('TENANT_BOUNDARY_PENDING')
      expect(audit.pathPrefix).assertEqual('/admin/audits')
    })

    it('keepsHm7PartialFailureLocalToAiReview', 0, async () => {
      const repository = new DemoHm7CapabilityRepository()
      const context: Hm7RequestContext = {
        scope: 'PLATFORM', role: 0, userId: '1', tenantId: '',
        tenantRole: 'PLATFORM_ADMIN', contextType: 'PLATFORM'
      }
      repository.setScenario('PARTIAL_FAILURE')
      expect((await repository.list(context, 'MARKETPLACE', '', '')).length).assertEqual(3)
      let status = 0
      let errorKey = ''
      try {
        await repository.list(context, 'AI_REVIEW', '', '')
      } catch (error) {
        status = error instanceof ApiError ? error.httpStatus : 0
        errorKey = error instanceof ApiError ? error.errorKey : ''
      }
      expect(status).assertEqual(502)
      expect(errorKey).assertEqual('HM7_AI_PARTIAL_FAILURE')
      repository.reset()
      expect((await repository.list(context, 'AI_REVIEW', '', '')).length).assertEqual(2)
    })
  })
}
