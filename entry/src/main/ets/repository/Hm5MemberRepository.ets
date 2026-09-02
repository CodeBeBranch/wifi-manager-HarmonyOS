import http from '@ohos.net.http'
import util from '@ohos.util'
import { realApiPath, resolveRealApiPath } from '../config/RealApiCatalog'
import { ApiError } from '../model/ApiModels'
import { Hm3DemoScenario } from '../model/Hm3Models'
import {
  MemberEntitlement,
  MemberLocationPermission,
  MemberLocationRecord,
  MemberOrder,
  MemberPayment,
  MemberProduct,
  MemberPurchase,
  MemberRefund,
  MemberSummary,
  MemberUsageRecord
} from '../model/Hm5Models'
import { sessionStore } from '../session/SessionStore'

interface MemberData {
  entitlement: MemberEntitlement
  products: MemberProduct[]
  purchases: MemberPurchase[]
  usage: MemberUsageRecord[]
  orders: MemberOrder[]
  payments: MemberPayment[]
  refunds: MemberRefund[]
  locationPermission: MemberLocationPermission
  locations: MemberLocationRecord[]
}

function cloneEntitlement(value: MemberEntitlement): MemberEntitlement {
  return { id: value.id, name: value.name, mode: value.mode, remainingGb: value.remainingGb,
    remainingLabel: value.remainingLabel, expiresAt: value.expiresAt, status: value.status }
}

function cloneProduct(value: MemberProduct): MemberProduct {
  return { id: value.id, name: value.name, description: value.description, mode: value.mode,
    quotaGb: value.quotaGb, quotaLabel: value.quotaLabel,
    validityDays: value.validityDays, price: value.price }
}

function clonePurchase(value: MemberPurchase): MemberPurchase {
  return { id: value.id, orderId: value.orderId, productName: value.productName, amount: value.amount,
    purchasedAt: value.purchasedAt, requestId: value.requestId }
}

function cloneUsage(value: MemberUsageRecord): MemberUsageRecord {
  return { id: value.id, connectionName: value.connectionName, trafficMb: value.trafficMb,
    durationMinutes: value.durationMinutes, usedAt: value.usedAt }
}

function cloneOrder(value: MemberOrder): MemberOrder {
  return { id: value.id, productId: value.productId, productName: value.productName,
    amount: value.amount, status: value.status, orderRequestId: value.orderRequestId,
    createdAt: value.createdAt }
}

function clonePayment(value: MemberPayment): MemberPayment {
  return { id: value.id, orderId: value.orderId, amount: value.amount, status: value.status,
    paymentRequestId: value.paymentRequestId, createdAt: value.createdAt }
}

function cloneRefund(value: MemberRefund): MemberRefund {
  return { id: value.id, orderId: value.orderId, productName: value.productName,
    amount: value.amount, reason: value.reason, status: value.status,
    refundRequestId: value.refundRequestId, createdAt: value.createdAt, reviewNote: value.reviewNote }
}

function cloneLocation(value: MemberLocationRecord): MemberLocationRecord {
  return { id: value.id, place: value.place, accuracyMeters: value.accuracyMeters,
    recordedAt: value.recordedAt }
}

function createMemberData(): MemberData {
  return {
    entitlement: {
      id: 501, name: '畅连月包', mode: '按流量', remainingGb: 18.6,
      remainingLabel: '18.6 GB',
      expiresAt: '2026-09-30 23:59', status: 'ACTIVE'
    },
    products: [
      { id: '601', name: '轻量流量包', description: '适合临时办公和移动接入',
        mode: '按流量', quotaGb: 10, quotaLabel: '10 GB', validityDays: 30, price: 19.9 },
      { id: '602', name: '畅连月包', description: '适合日常办公的月度权益',
        mode: '按流量', quotaGb: 30, quotaLabel: '30 GB', validityDays: 30, price: 39.9 },
      { id: '603', name: '不限量体验', description: '本地演示的限时不限量权益',
        mode: '不限量', quotaGb: 0, quotaLabel: '不限量', validityDays: 7, price: 9.9 }
    ],
    purchases: [
      { id: '701', orderId: '901', productName: '畅连月包', amount: 39.9,
        purchasedAt: '2026-08-20 10:30', requestId: 'PURCHASE-DEMO-0001' }
    ],
    usage: [
      { id: 801, connectionName: '办公笔记本', trafficMb: 840,
        durationMinutes: 95, usedAt: '2026-08-31 16:20' },
      { id: 802, connectionName: '个人手机', trafficMb: 320,
        durationMinutes: 48, usedAt: '2026-08-30 09:15' }
    ],
    orders: [
      { id: '901', productId: '602', productName: '畅连月包', amount: 39.9,
        status: 'REFUNDING', orderRequestId: 'ORDER-DEMO-0001', createdAt: '2026-08-20 10:29' },
      { id: '902', productId: '601', productName: '轻量流量包', amount: 19.9,
        status: 'PENDING_PAYMENT', orderRequestId: 'ORDER-DEMO-0002', createdAt: '2026-08-31 18:00' }
    ],
    payments: [
      { id: '1001', orderId: '901', amount: 39.9, status: 'SUCCEEDED',
        paymentRequestId: 'PAYMENT-DEMO-0001', createdAt: '2026-08-20 10:30' }
    ],
    refunds: [
      { id: '1101', orderId: '901', productName: '畅连月包', amount: 39.9,
        reason: '出差计划调整，暂不需要本月权益', status: 'PENDING',
        refundRequestId: 'REFUND-DEMO-0001', createdAt: '2026-08-31 19:10', reviewNote: '' }
    ],
    locationPermission: { granted: false, precision: '未授权', updatedAt: '2026-08-20 09:00' },
    locations: [
      { id: 1201, place: 'A 栋共享办公区', accuracyMeters: 12, recordedAt: '2026-08-31 16:20' },
      { id: 1202, place: '一层访客区', accuracyMeters: 18, recordedAt: '2026-08-30 09:15' }
    ]
  }
}

export class DemoHm5MemberRepository {
  private scenario: Hm3DemoScenario = 'NORMAL'
  private readonly members: Map<string, MemberData> = new Map<string, MemberData>()
  private nextOrderId: number = 910
  private nextPaymentId: number = 1010
  private nextRefundId: number = 1110
  private orderSequence: number = 3
  private paymentSequence: number = 2
  private refundSequence: number = 2

  private data(userId: string): MemberData {
    const key = userId.trim()
    if (key.length === 0) throw new ApiError('当前成员上下文无效', 409, 409, 'MEMBER_CONTEXT_REQUIRED')
    const current = this.members.get(key)
    if (current !== undefined) return current
    const created = createMemberData()
    this.members.set(key, created)
    return created
  }

  private guard(): void {
    if (this.scenario === 'FORBIDDEN') {
      throw new ApiError('当前场景拒绝成员消费数据访问', 403, 403, 'HM5_SCENARIO_FORBIDDEN')
    }
    if (this.scenario === 'RATE_LIMITED') {
      throw new ApiError('成员消费请求过于频繁', 429, 429, 'HM5_SCENARIO_RATE_LIMITED', '', '3', true)
    }
    if (this.scenario === 'DEPENDENCY_DOWN') {
      throw new ApiError('成员消费依赖暂不可用', 503, 503, 'HM5_SCENARIO_DEPENDENCY_DOWN', '', '', true)
    }
  }

  private requireWrite(authorized: boolean): void {
    if (!authorized) throw new ApiError('当前账号没有执行该操作的权限', 403, 403, 'HM5_WRITE_FORBIDDEN')
    if (this.scenario === 'CONFLICT') {
      throw new ApiError('当前状态已变化，请刷新后重试', 409, 409, 'HM5_SCENARIO_CONFLICT')
    }
  }

  setScenario(scenario: Hm3DemoScenario): void { this.scenario = scenario }
  getScenario(): Hm3DemoScenario { return this.scenario }

  reset(): void {
    this.scenario = 'NORMAL'
    this.members.clear()
    this.nextOrderId = 910
    this.nextPaymentId = 1010
    this.nextRefundId = 1110
    this.orderSequence = 3
    this.paymentSequence = 2
    this.refundSequence = 2
  }

  summary(userId: string): MemberSummary {
    this.guard()
    const data = this.data(userId)
    return {
      entitlementName: data.entitlement.name,
      remainingGb: data.entitlement.remainingGb,
      remainingLabel: data.entitlement.remainingLabel,
      activeConnections: this.scenario === 'EMPTY' ? 0 : 1,
      pendingOrders: data.orders.filter((item: MemberOrder): boolean => item.status === 'PENDING_PAYMENT').length,
      unreadNotices: 2
    }
  }

  entitlement(userId: string): MemberEntitlement {
    this.guard()
    return cloneEntitlement(this.data(userId).entitlement)
  }

  products(userId: string, keyword: string): MemberProduct[] {
    this.guard()
    if (this.scenario === 'EMPTY' || this.scenario === 'FILTER_EMPTY') return []
    const normalized = keyword.trim().toUpperCase()
    return this.data(userId).products.filter((item: MemberProduct): boolean =>
      normalized.length === 0 || item.name.toUpperCase().includes(normalized) ||
      item.mode.toUpperCase().includes(normalized)).map(cloneProduct)
  }

  purchases(userId: string): MemberPurchase[] {
    this.guard()
    if (this.scenario === 'EMPTY') return []
    if (this.scenario === 'PARTIAL_FAILURE') {
      throw new ApiError('购买记录暂不可用，权益和订单仍可查看', 502, 502, 'PURCHASE_PARTIAL_FAILURE')
    }
    return this.data(userId).purchases.map(clonePurchase)
  }

  usage(userId: string): MemberUsageRecord[] {
    this.guard()
    if (this.scenario === 'EMPTY') return []
    return this.data(userId).usage.map(cloneUsage)
  }

  orders(userId: string): MemberOrder[] {
    this.guard()
    if (this.scenario === 'EMPTY') return []
    return this.data(userId).orders.map(cloneOrder)
  }

  orderDetail(userId: string, id: string): MemberOrder {
    this.guard()
    const order = this.data(userId).orders.find((item: MemberOrder): boolean => item.id === id)
    if (order === undefined) throw new ApiError('没有找到当前成员的订单', 404, 404, 'ORDER_NOT_FOUND')
    return cloneOrder(order)
  }

  createOrder(userId: string, productId: string, authorized: boolean): MemberOrder {
    this.guard()
    this.requireWrite(authorized)
    if (this.scenario === 'EMPTY') {
      throw new ApiError('当前没有 ACTIVE Session，无法创建订单', 409, 409, 'ACTIVE_SESSION_REQUIRED')
    }
    const data = this.data(userId)
    const product = data.products.find((item: MemberProduct): boolean => item.id === productId)
    if (product === undefined) throw new ApiError('没有找到所选产品', 404, 404, 'PRODUCT_NOT_FOUND')
    if (data.orders.some((item: MemberOrder): boolean =>
      item.productId === productId && item.status === 'PENDING_PAYMENT')) {
      throw new ApiError('该产品已有待支付订单', 409, 409, 'ORDER_DUPLICATE_PENDING')
    }
    const order: MemberOrder = {
      id: String(this.nextOrderId++), productId: product.id, productName: product.name, amount: product.price,
      status: 'PENDING_PAYMENT', orderRequestId: `ORDER-DEMO-${String(this.orderSequence++).padStart(4, '0')}`,
      createdAt: '2026-09-01 11:30'
    }
    data.orders.unshift(order)
    return cloneOrder(order)
  }

  cancelOrder(userId: string, id: string, authorized: boolean): MemberOrder {
    this.guard()
    this.requireWrite(authorized)
    const order = this.data(userId).orders.find((item: MemberOrder): boolean => item.id === id)
    if (order === undefined) throw new ApiError('没有找到当前成员的订单', 404, 404, 'ORDER_NOT_FOUND')
    if (order.status !== 'PENDING_PAYMENT') {
      throw new ApiError('当前订单状态不允许取消', 409, 409, 'ORDER_CANCEL_CONFLICT')
    }
    order.status = 'CANCELLED'
    return cloneOrder(order)
  }

  paymentForOrder(userId: string, orderId: string): MemberPayment | null {
    this.guard()
    const payment = this.data(userId).payments.find((item: MemberPayment): boolean => item.orderId === orderId)
    return payment === undefined ? null : clonePayment(payment)
  }

  createPayment(userId: string, orderId: string, authorized: boolean): MemberPayment {
    this.guard()
    this.requireWrite(authorized)
    const data = this.data(userId)
    const order = data.orders.find((item: MemberOrder): boolean => item.id === orderId)
    if (order === undefined) throw new ApiError('没有找到当前成员的订单', 404, 404, 'ORDER_NOT_FOUND')
    if (order.status !== 'PENDING_PAYMENT') {
      throw new ApiError('当前订单不可支付', 409, 409, 'PAYMENT_ORDER_CONFLICT')
    }
    if (data.payments.some((item: MemberPayment): boolean => item.orderId === orderId)) {
      throw new ApiError('该订单已有支付请求', 409, 409, 'PAYMENT_DUPLICATE')
    }
    const payment: MemberPayment = {
      id: String(this.nextPaymentId++), orderId: order.id, amount: order.amount, status: 'SUCCEEDED',
      paymentRequestId: `PAYMENT-DEMO-${String(this.paymentSequence++).padStart(4, '0')}`,
      createdAt: '2026-09-01 11:31'
    }
    data.payments.unshift(payment)
    order.status = 'PAID'
    data.purchases.unshift({
      id: String(700 + Number(payment.id)), orderId: order.id,
      productName: order.productName, amount: order.amount,
      purchasedAt: payment.createdAt, requestId: `PURCHASE-${payment.paymentRequestId}`
    })
    return clonePayment(payment)
  }

  refunds(userId: string): MemberRefund[] {
    this.guard()
    if (this.scenario === 'EMPTY') return []
    return this.data(userId).refunds.map(cloneRefund)
  }

  refundDetail(userId: string, id: string): MemberRefund {
    this.guard()
    const refund = this.data(userId).refunds.find((item: MemberRefund): boolean => item.id === id)
    if (refund === undefined) throw new ApiError('没有找到当前退款申请', 404, 404, 'REFUND_NOT_FOUND')
    return cloneRefund(refund)
  }

  applyRefund(userId: string, orderId: string, reason: string, authorized: boolean): MemberRefund {
    this.guard()
    this.requireWrite(authorized)
    const normalizedReason = reason.trim()
    if (normalizedReason.length < 4 || normalizedReason.length > 120) {
      throw new ApiError('退款原因需要 4 到 120 个字符', 400, 400, 'REFUND_REASON_INVALID')
    }
    const data = this.data(userId)
    const order = data.orders.find((item: MemberOrder): boolean => item.id === orderId)
    if (order === undefined) throw new ApiError('没有找到当前成员的订单', 404, 404, 'ORDER_NOT_FOUND')
    if (order.status !== 'PAID') {
      throw new ApiError('当前订单状态不允许退款', 409, 409, 'REFUND_ORDER_CONFLICT')
    }
    if (data.refunds.some((item: MemberRefund): boolean =>
      item.orderId === orderId && item.status === 'PENDING')) {
      throw new ApiError('该订单已有待处理退款', 409, 409, 'REFUND_DUPLICATE_PENDING')
    }
    const refund: MemberRefund = {
      id: String(this.nextRefundId++), orderId: order.id, productName: order.productName,
      amount: order.amount, reason: normalizedReason, status: 'PENDING',
      refundRequestId: `REFUND-DEMO-${String(this.refundSequence++).padStart(4, '0')}`,
      createdAt: '2026-09-01 11:32', reviewNote: ''
    }
    data.refunds.unshift(refund)
    order.status = 'REFUNDING'
    return cloneRefund(refund)
  }

  reviewRefund(userId: string, id: string, approved: boolean, note: string,
    authorized: boolean): MemberRefund {
    this.guard()
    this.requireWrite(authorized)
    const data = this.data(userId)
    const refund = data.refunds.find((item: MemberRefund): boolean => item.id === id)
    if (refund === undefined) throw new ApiError('没有找到当前退款申请', 404, 404, 'REFUND_NOT_FOUND')
    if (refund.status !== 'PENDING') {
      throw new ApiError('退款申请已处理', 409, 409, 'REFUND_REVIEW_CONFLICT')
    }
    refund.status = approved ? 'APPROVED' : 'REJECTED'
    refund.reviewNote = note.trim()
    const order = data.orders.find((item: MemberOrder): boolean => item.id === refund.orderId)
    if (order !== undefined) order.status = approved ? 'REFUNDED' : 'PAID'
    return cloneRefund(refund)
  }

  tenantRefunds(tenantId: string): MemberRefund[] {
    this.guard()
    if (this.scenario === 'EMPTY') return []
    return this.data(`${tenantId}|preview-member`).refunds.map(cloneRefund)
  }

  tenantRefundDetail(tenantId: string, id: string): MemberRefund {
    this.guard()
    const refund = this.data(`${tenantId}|preview-member`).refunds
      .find((item: MemberRefund): boolean => item.id === id)
    if (refund === undefined) throw new ApiError('没有找到当前组织的退款申请', 404, 404, 'REFUND_NOT_FOUND')
    return cloneRefund(refund)
  }

  reviewTenantRefund(tenantId: string, id: string, approved: boolean, note: string,
    authorized: boolean): MemberRefund {
    return this.reviewRefund(`${tenantId}|preview-member`, id, approved, note, authorized)
  }

  locationPermission(userId: string): MemberLocationPermission {
    this.guard()
    const value = this.data(userId).locationPermission
    return { granted: value.granted, precision: value.precision, updatedAt: value.updatedAt }
  }

  setLocationPermission(userId: string, granted: boolean, authorized: boolean): MemberLocationPermission {
    this.guard()
    this.requireWrite(authorized)
    const value = this.data(userId).locationPermission
    value.granted = granted
    value.precision = granted ? '约 10 米' : '未授权'
    value.updatedAt = '2026-09-01 11:33'
    return { granted: value.granted, precision: value.precision, updatedAt: value.updatedAt }
  }

  locationHistory(userId: string): MemberLocationRecord[] {
    this.guard()
    if (this.scenario === 'EMPTY') return []
    return this.data(userId).locations.map(cloneLocation)
  }

  clearLocationHistory(userId: string, authorized: boolean): void {
    this.guard()
    this.requireWrite(authorized)
    this.data(userId).locations = []
  }
}

export interface Hm5PageWire<T> {
  total: number
  current: number
  size: number
  records: T[]
}

export interface EntitlementWire {
  entitlementId: number
  mode: string
  subscriptionEndTime?: string
  remainingSeconds?: number
  status: number
}

export interface ProductWire {
  productCode: string
  name: string
  entitlementMode: string
  grantSeconds?: number
  grantMonths?: number
  amountCents: number
}

export interface PurchaseWire {
  purchaseId: string
  orderNo: string
  purchasedSeconds: number
  remainingSeconds: number
  paidAmountCents: number
  createTime: string
}

export interface UsageWire {
  id: number
  requestId: string
  sessionId?: number
  changeSeconds: number
  reason: string
  createTime: string
}

export interface OrderWire {
  orderNo: string
  productCode: string
  entitlementMode: string
  amountCents: number
  status: string
  createTime: string
}

export interface PaymentWire {
  paymentNo: string
  orderNo: string
  amountCents: number
  paidAmountCents: number
  status: string
  createTime: string
}

export interface RefundWire {
  refundNo: string
  orderNo: string
  purchaseId: string
  requestId: string
  status: string
  reason: string
  requestedAmountCents: number
  refundAmountCents: number
  reviewComment?: string
  createTime: string
}

export interface LocationAuthorizationWire {
  enabled: number
  consentTime?: string
  revokedTime?: string
  lastReportTime?: string
}

export interface LocationWire {
  id: number
  mac?: string
  deviceCode?: string
  accuracy: number
  reportTime: string
}

interface OrderCreateBody {
  clientRequestId: string
  productCode: string
}

interface PaymentCreateBody {
  requestId: string
  channel: string
}

interface RefundApplyBody {
  requestId: string
  purchaseId: string
  reason: string
}

interface RefundReviewBody {
  decision: string
  comment: string
}

function money(cents: number): number {
  return Math.round(cents) / 100
}

function durationLabel(seconds: number): string {
  if (seconds <= 0) return '0 小时'
  const hours = seconds / 3600
  if (hours < 24) return `${hours.toFixed(1)} 小时`
  return `${(hours / 24).toFixed(1)} 天`
}

function orderStatus(status: string): 'PENDING_PAYMENT' | 'PAID' | 'CANCELLED' | 'REFUNDING' | 'REFUNDED' {
  if (status === 'PAID' || status === 'FULFILLED') return 'PAID'
  if (status === 'REFUNDING') return 'REFUNDING'
  if (status === 'REFUNDED') return 'REFUNDED'
  if (status === 'CANCELLED' || status === 'CLOSED') return 'CANCELLED'
  return 'PENDING_PAYMENT'
}

function paymentStatus(status: string): 'PROCESSING' | 'SUCCEEDED' | 'FAILED' {
  if (status === 'SUCCEEDED' || status === 'PAID') return 'SUCCEEDED'
  if (status === 'FAILED' || status === 'CLOSED') return 'FAILED'
  return 'PROCESSING'
}

function refundStatus(status: string): 'PENDING' | 'APPROVED' | 'REJECTED' {
  if (status === 'APPROVED' || status === 'SUCCEEDED' || status === 'COMPLETED') return 'APPROVED'
  if (status === 'REJECTED' || status === 'FAILED' || status === 'CANCELLED') return 'REJECTED'
  return 'PENDING'
}

export function mapHm5Entitlement(value: EntitlementWire): MemberEntitlement {
  const seconds = value.remainingSeconds ?? 0
  return {
    id: value.entitlementId,
    name: value.mode === 'SUBSCRIPTION' ? '订阅权益' : '时长权益',
    mode: value.mode,
    remainingGb: seconds / 3600,
    remainingLabel: durationLabel(seconds),
    expiresAt: value.subscriptionEndTime ?? '',
    status: value.status === 1 ? 'ACTIVE' : 'INACTIVE'
  }
}

export function mapHm5Product(value: ProductWire): MemberProduct {
  const seconds = value.grantSeconds ?? 0
  const months = value.grantMonths ?? 0
  const validityDays = months > 0 ? months * 30 : Math.ceil(seconds / 86400)
  const quotaLabel = months > 0 ? `${months} 个月` : durationLabel(seconds)
  return {
    id: value.productCode,
    name: value.name,
    description: `${value.entitlementMode} 权益`,
    mode: value.entitlementMode,
    quotaGb: seconds / 3600,
    quotaLabel: quotaLabel,
    validityDays: validityDays,
    price: money(value.amountCents)
  }
}

export function mapHm5Purchase(value: PurchaseWire): MemberPurchase {
  return {
    id: value.purchaseId,
    orderId: value.orderNo,
    productName: `权益时长 ${durationLabel(value.purchasedSeconds)}`,
    amount: money(value.paidAmountCents),
    purchasedAt: value.createTime,
    requestId: value.orderNo
  }
}

export function mapHm5Usage(value: UsageWire): MemberUsageRecord {
  return {
    id: value.id,
    connectionName: value.sessionId === undefined ? value.reason : `会话 ${value.sessionId}`,
    trafficMb: 0,
    durationMinutes: Math.round(Math.abs(value.changeSeconds) / 60),
    usedAt: value.createTime
  }
}

export function mapHm5Order(value: OrderWire, productName: string): MemberOrder {
  return {
    id: value.orderNo,
    productId: value.productCode,
    productName: productName.length > 0 ? productName : value.productCode,
    amount: money(value.amountCents),
    status: orderStatus(value.status),
    orderRequestId: value.orderNo,
    createdAt: value.createTime
  }
}

export function mapHm5Payment(value: PaymentWire): MemberPayment {
  return {
    id: value.paymentNo,
    orderId: value.orderNo,
    amount: money(value.paidAmountCents > 0 ? value.paidAmountCents : value.amountCents),
    status: paymentStatus(value.status),
    paymentRequestId: value.paymentNo,
    createdAt: value.createTime
  }
}

export function mapHm5Refund(value: RefundWire, productName: string): MemberRefund {
  const amount = value.refundAmountCents > 0 ? value.refundAmountCents : value.requestedAmountCents
  return {
    id: value.refundNo,
    orderId: value.orderNo,
    productName: productName.length > 0 ? productName : '权益订单',
    amount: money(amount),
    reason: value.reason,
    status: refundStatus(value.status),
    refundRequestId: value.requestId,
    createdAt: value.createTime,
    reviewNote: value.reviewComment ?? ''
  }
}

export function mapHm5LocationPermission(value: LocationAuthorizationWire): MemberLocationPermission {
  const granted = value.enabled === 1
  return {
    granted: granted,
    precision: granted ? '由设备定位精度决定' : '未授权',
    updatedAt: granted ? value.consentTime ?? '' : value.revokedTime ?? ''
  }
}

export function mapHm5Location(value: LocationWire): MemberLocationRecord {
  const subject = value.deviceCode ?? value.mac ?? '已授权设备'
  return {
    id: value.id,
    place: subject,
    accuracyMeters: value.accuracy,
    recordedAt: value.reportTime
  }
}

export class RealHm5MemberRepository {
  private readonly productNames: Map<string, string> = new Map<string, string>()
  private readonly paymentsByOrder: Map<string, MemberPayment> = new Map<string, MemberPayment>()

  private pending(message: string): ApiError {
    return new ApiError(message, 503, 503, 'REAL_API_PENDING')
  }

  private async productName(productCode: string): Promise<string> {
    if (!this.productNames.has(productCode)) await this.products('')
    return this.productNames.get(productCode) ?? productCode
  }

  private async mapOrder(value: OrderWire): Promise<MemberOrder> {
    return mapHm5Order(value, await this.productName(value.productCode))
  }

  async summary(): Promise<MemberSummary> {
    const entitlement = await this.entitlement()
    const orders = await this.orders()
    return {
      entitlementName: entitlement.name,
      remainingGb: entitlement.remainingGb,
      remainingLabel: entitlement.remainingLabel,
      activeConnections: 0,
      pendingOrders: orders.filter((item: MemberOrder): boolean =>
        item.status === 'PENDING_PAYMENT').length,
      unreadNotices: 0
    }
  }

  async entitlement(): Promise<MemberEntitlement> {
    const response = await sessionStore.authorizedRequest<EntitlementWire>(
      http.RequestMethod.GET, realApiPath('entitlements.mine'))
    return mapHm5Entitlement(response.data)
  }

  async products(keyword: string): Promise<MemberProduct[]> {
    const response = await sessionStore.authorizedRequest<ProductWire[]>(
      http.RequestMethod.GET, realApiPath('entitlements.products'))
    const normalized = keyword.trim().toLowerCase()
    const products = response.data.map((item: ProductWire): MemberProduct => mapHm5Product(item))
    for (const item of products) this.productNames.set(item.id, item.name)
    return normalized.length === 0
      ? products
      : products.filter((item: MemberProduct): boolean =>
        item.name.toLowerCase().includes(normalized) ||
        item.description.toLowerCase().includes(normalized))
  }

  async purchases(): Promise<MemberPurchase[]> {
    const response = await sessionStore.authorizedRequest<Hm5PageWire<PurchaseWire>>(
      http.RequestMethod.GET, `${realApiPath('entitlements.purchases')}?current=1&size=100`)
    return response.data.records.map((item: PurchaseWire): MemberPurchase => mapHm5Purchase(item))
  }

  async usage(): Promise<MemberUsageRecord[]> {
    const response = await sessionStore.authorizedRequest<Hm5PageWire<UsageWire>>(
      http.RequestMethod.GET, `${realApiPath('entitlements.usageLogs')}?current=1&size=100`)
    return response.data.records.map((item: UsageWire): MemberUsageRecord => mapHm5Usage(item))
  }

  async orders(): Promise<MemberOrder[]> {
    const response = await sessionStore.authorizedRequest<Hm5PageWire<OrderWire>>(
      http.RequestMethod.GET, `${realApiPath('entitlements.orders')}?current=1&size=100`)
    const result: MemberOrder[] = []
    for (const item of response.data.records) result.push(await this.mapOrder(item))
    return result
  }

  async orderDetail(id: string): Promise<MemberOrder> {
    const response = await sessionStore.authorizedRequest<OrderWire>(
      http.RequestMethod.GET, resolveRealApiPath(
        'entitlements.orderDetail', ['orderNo'], [id]))
    return this.mapOrder(response.data)
  }

  async createOrder(productId: string): Promise<MemberOrder> {
    const body: OrderCreateBody = {
      clientRequestId: util.generateRandomUUID(),
      productCode: productId
    }
    const response = await sessionStore.authorizedRequest<OrderWire>(
      http.RequestMethod.POST, realApiPath('entitlements.orders'), JSON.stringify(body))
    return this.mapOrder(response.data)
  }

  async cancelOrder(id: string): Promise<MemberOrder> {
    const response = await sessionStore.authorizedRequest<OrderWire>(
      http.RequestMethod.POST, resolveRealApiPath(
        'entitlements.orderCancel', ['orderNo'], [id]))
    return this.mapOrder(response.data)
  }

  async paymentForOrder(orderId: string): Promise<MemberPayment | null> {
    return this.paymentsByOrder.get(orderId) ?? null
  }

  async createPayment(orderId: string): Promise<MemberPayment> {
    const body: PaymentCreateBody = {
      requestId: util.generateRandomUUID(),
      channel: 'LOCAL_DEMO'
    }
    const response = await sessionStore.authorizedRequest<PaymentWire>(
      http.RequestMethod.POST,
      resolveRealApiPath('entitlements.orderPayments', ['orderNo'], [orderId]),
      JSON.stringify(body))
    const payment = mapHm5Payment(response.data)
    this.paymentsByOrder.set(orderId, payment)
    return payment
  }

  async refunds(): Promise<MemberRefund[]> {
    const response = await sessionStore.authorizedRequest<Hm5PageWire<RefundWire>>(
      http.RequestMethod.GET, `${realApiPath('entitlements.refunds')}?current=1&size=100`)
    return response.data.records.map((item: RefundWire): MemberRefund => mapHm5Refund(item, ''))
  }

  async refundDetail(id: string): Promise<MemberRefund> {
    const response = await sessionStore.authorizedRequest<RefundWire>(
      http.RequestMethod.GET, resolveRealApiPath(
        'entitlements.refundDetail', ['refundNo'], [id]))
    const order = await this.orderDetail(response.data.orderNo)
    return mapHm5Refund(response.data, order.productName)
  }

  async applyRefund(orderId: string, reason: string): Promise<MemberRefund> {
    const purchases = await this.purchases()
    const purchase = purchases.find((item: MemberPurchase): boolean => item.orderId === orderId)
    if (purchase === undefined) {
      throw new ApiError('该订单没有可退款的权益记录', 409, 409, 'REFUND_PURCHASE_NOT_FOUND')
    }
    const body: RefundApplyBody = {
      requestId: util.generateRandomUUID(),
      purchaseId: purchase.id,
      reason: reason
    }
    const response = await sessionStore.authorizedRequest<RefundWire>(
      http.RequestMethod.POST, realApiPath('entitlements.refunds'), JSON.stringify(body))
    const order = await this.orderDetail(orderId)
    return mapHm5Refund(response.data, order.productName)
  }

  async reviewRefund(_id: string, _approved: boolean, _note: string): Promise<MemberRefund> {
    throw this.pending('成员端不能审核真实退款')
  }

  async tenantRefunds(): Promise<MemberRefund[]> {
    const response = await sessionStore.authorizedRequest<Hm5PageWire<RefundWire>>(
      http.RequestMethod.GET, `${realApiPath('admin.refunds')}?current=1&size=100`)
    return response.data.records.map((item: RefundWire): MemberRefund => mapHm5Refund(item, ''))
  }

  async tenantRefundDetail(id: string): Promise<MemberRefund> {
    const response = await sessionStore.authorizedRequest<RefundWire>(
      http.RequestMethod.GET, resolveRealApiPath(
        'admin.refundDetail', ['refundNo'], [id]))
    return mapHm5Refund(response.data, '')
  }

  async reviewTenantRefund(id: string, approved: boolean, note: string): Promise<MemberRefund> {
    const body: RefundReviewBody = {
      decision: approved ? 'APPROVE' : 'REJECT',
      comment: note
    }
    const response = await sessionStore.authorizedRequest<RefundWire>(
      http.RequestMethod.PUT,
      resolveRealApiPath('admin.refundReview', ['refundNo'], [id]),
      JSON.stringify(body))
    return mapHm5Refund(response.data, '')
  }

  async locationPermission(): Promise<MemberLocationPermission> {
    const response = await sessionStore.authorizedRequest<LocationAuthorizationWire>(
      http.RequestMethod.GET, realApiPath('locations.consent'))
    return mapHm5LocationPermission(response.data)
  }

  async setLocationPermission(granted: boolean): Promise<MemberLocationPermission> {
    const response = await sessionStore.authorizedRequest<LocationAuthorizationWire>(
      granted ? http.RequestMethod.POST : http.RequestMethod.DELETE,
      realApiPath('locations.consent'))
    return mapHm5LocationPermission(response.data)
  }

  async locationHistory(): Promise<MemberLocationRecord[]> {
    const response = await sessionStore.authorizedRequest<Hm5PageWire<LocationWire>>(
      http.RequestMethod.GET, `${realApiPath('locations.mine')}?current=1&size=100`)
    return response.data.records.map((item: LocationWire): MemberLocationRecord => mapHm5Location(item))
  }

  async clearLocationHistory(): Promise<void> {
    await sessionStore.authorizedRequest<number>(
      http.RequestMethod.DELETE, realApiPath('locations.history'))
  }
}
