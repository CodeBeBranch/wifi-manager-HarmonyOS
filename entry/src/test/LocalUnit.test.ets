import { describe, it, expect } from '@ohos/hypium'
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
  isValidContact,
  isValidVerifyCode
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
import { NetworkSession, SessionPageResult } from '../main/ets/model/SessionModels'
import { PlatformTenantPageResult } from '../main/ets/model/TenantModels'
import { extractRefreshCookie, parseApiResponse } from '../main/ets/network/ApiParser'
import { normalizeThemeMode } from '../main/ets/storage/ThemeStore'
import { normalizeLoginMode } from '../main/ets/storage/LoginPreferenceStore'

interface TestData {
  value: string
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
  })
}
