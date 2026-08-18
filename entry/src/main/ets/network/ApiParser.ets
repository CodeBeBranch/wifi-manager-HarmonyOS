import { ApiEnvelope, ApiError, ApiSuccess } from '../model/ApiModels'

const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]{16,64}$/
const ERROR_KEY_PATTERN = /^[A-Z][A-Z0-9_]{2,63}$/
const UNSAFE_MESSAGE_PATTERN =
  /(?:bearer\s+\S+|authorization|cookie|set-cookie|password|secret|token|exception|error\b)/i

function readHeader(headersJson: string, name: string): string {
  const pattern = name === 'x-request-id'
    ? /"x-request-id"\s*:\s*(?:"([^"]*)"|\[\s*"([^"]*)")/i
    : /"retry-after"\s*:\s*(?:"([^"]*)"|\[\s*"([^"]*)")/i
  const match = pattern.exec(headersJson)
  return match === null ? '' : (match[1] || match[2] || '')
}

function safeRequestId(value: string | undefined): string {
  const normalized = value === undefined ? '' : value.trim()
  return REQUEST_ID_PATTERN.test(normalized) ? normalized : ''
}

function safeErrorKey(value: string | undefined): string {
  const normalized = value === undefined ? '' : value.trim()
  return ERROR_KEY_PATTERN.test(normalized) ? normalized : ''
}

function safeMessage(value: string | undefined, fallback: string): string {
  const normalized = value === undefined ? '' : value.trim()
  if (normalized.length === 0 || normalized.length > 300 || UNSAFE_MESSAGE_PATTERN.test(normalized)) {
    return fallback
  }
  return normalized
}

function fallbackMessage(status: number): string {
  if (status === 400) return '请求参数不正确'
  if (status === 401) return '登录状态无效，请重新登录'
  if (status === 403) return '当前账号没有权限执行该操作'
  if (status === 404) return '请求的内容不存在'
  if (status === 409) return '当前状态发生冲突，请刷新后重试'
  if (status === 429) return '请求过于频繁'
  if (status === 502) return '相关功能返回了无效响应'
  if (status === 503 || status === 504) return '相关服务暂时不可用'
  if (status >= 500) return '服务器处理失败，请稍后重试'
  return '请求失败'
}

function isRetryable(status: number): boolean {
  return status === 409 || status === 429 || status === 502 ||
    status === 503 || status === 504 || status >= 500
}

function protocolError(httpStatus: number, headersJson: string): ApiError {
  const protocolStatus = httpStatus >= 500 ? httpStatus : 502
  return new ApiError(
    '相关服务返回了无效响应',
    protocolStatus,
    protocolStatus,
    'DEPENDENCY_PROTOCOL_INVALID',
    safeRequestId(readHeader(headersJson, 'x-request-id')),
    '',
    true
  )
}

export function parseApiResponse<T>(
  responseText: string,
  httpStatus: number,
  headersJson: string,
  refreshCookie: string
): ApiSuccess<T> {
  let envelope: ApiEnvelope<T> | null = null
  try {
    envelope = JSON.parse(responseText) as ApiEnvelope<T>
    if (envelope === null || typeof envelope !== 'object' || Array.isArray(envelope) ||
      typeof envelope.code !== 'number' || envelope.code % 1 !== 0 ||
      typeof envelope.message !== 'string' || !Object.keys(envelope).includes('data')) {
      throw new Error('Invalid API envelope')
    }
  } catch (_) {
    throw protocolError(httpStatus, headersJson)
  }

  const envelopeCode = envelope.code
  const status = httpStatus >= 200 && httpStatus < 300 && envelopeCode !== 200
    ? envelopeCode
    : httpStatus
  const requestId = safeRequestId(readHeader(headersJson, 'x-request-id')) ||
    safeRequestId(envelope.requestId)
  if (httpStatus < 200 || httpStatus >= 300 || envelopeCode !== 200) {
    const retryAfter = /^\d+$/.test(readHeader(headersJson, 'retry-after'))
      ? readHeader(headersJson, 'retry-after')
      : ''
    const fallback = fallbackMessage(status)
    const message = safeMessage(envelope.message, fallback)
    throw new ApiError(
      status === 429 && retryAfter.length > 0 ? `${message}，请在 ${retryAfter} 秒后重试` : message,
      status,
      envelopeCode,
      safeErrorKey(envelope.errorKey),
      requestId,
      retryAfter,
      isRetryable(status)
    )
  }

  return {
    data: envelope.data,
    refreshCookie: refreshCookie,
    requestId: requestId
  }
}

export function extractRefreshCookie(rawCookies: string): string {
  const match = /(?:^|[,;\s])wifi_refresh=([^;,\s]+)/.exec(rawCookies)
  return match === null ? '' : `wifi_refresh=${match[1]}`
}
