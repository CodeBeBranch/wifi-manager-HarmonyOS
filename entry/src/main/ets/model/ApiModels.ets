export interface ApiEnvelope<T> {
  code: number
  message: string
  data: T
  errorKey?: string
  requestId?: string
}

export interface ApiSuccess<T> {
  data: T
  refreshCookie: string
  requestId: string
}

export class ApiError extends Error {
  readonly httpStatus: number
  readonly code: number
  readonly errorKey: string
  readonly requestId: string
  readonly retryAfter: string
  readonly retryable: boolean

  constructor(
    message: string,
    httpStatus: number = 0,
    code: number = 0,
    errorKey: string = '',
    requestId: string = '',
    retryAfter: string = '',
    retryable: boolean = false
  ) {
    super(message)
    this.name = 'ApiError'
    this.httpStatus = httpStatus
    this.code = code
    this.errorKey = errorKey
    this.requestId = requestId
    this.retryAfter = retryAfter
    this.retryable = retryable
  }
}

export interface PublicRequestHeaders {
  'Accept': string
  'Content-Type': string
  'X-Client-Instance-Id': string
  'X-Request-Id': string
}

export interface AccessRequestHeaders extends PublicRequestHeaders {
  'Authorization': string
}

export interface CookieRequestHeaders extends PublicRequestHeaders {
  'Cookie': string
}
