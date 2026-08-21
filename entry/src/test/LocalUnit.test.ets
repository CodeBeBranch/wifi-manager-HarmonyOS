import { describe, it, expect } from '@ohos/hypium'
import http from '@ohos.net.http'
import {
  buildAlertWebSocketUrl,
  normalizeGatewayUrl
} from '../main/ets/config/RuntimeConfig'
import { ApiError } from '../main/ets/model/ApiModels'
import {
  AlertEvent,
  AlertPageResult,
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
import { TenantCreateInput } from '../main/ets/model/Hm2Models'
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

    it('keepsHm2SaasPlansReadOnlyAndSearchable', 0, async () => {
      const repository = new DemoPlatformAdminRepository()
      const published = await repository.listSaasPlans(1, 20, '', 'PUBLISHED')
      const pro = await repository.listSaasPlans(1, 20, 'PRO', '')
      expect(published.total).assertEqual(2)
      expect(pro.total).assertEqual(1)
      const detail = await repository.saasPlanDetail(pro.records[0].planId)
      expect(detail.features.length).assertEqual(3)
      expect(detail.status).assertEqual('PUBLISHED')
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
  })
}
