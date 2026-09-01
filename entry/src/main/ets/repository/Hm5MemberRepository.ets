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
    expiresAt: value.expiresAt, status: value.status }
}

function cloneProduct(value: MemberProduct): MemberProduct {
  return { id: value.id, name: value.name, description: value.description, mode: value.mode,
    quotaGb: value.quotaGb, validityDays: value.validityDays, price: value.price }
}

function clonePurchase(value: MemberPurchase): MemberPurchase {
  return { id: value.id, productName: value.productName, amount: value.amount,
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
      expiresAt: '2026-09-30 23:59', status: 'ACTIVE'
    },
    products: [
      { id: 601, name: '轻量流量包', description: '适合临时办公和移动接入',
        mode: '按流量', quotaGb: 10, validityDays: 30, price: 19.9 },
      { id: 602, name: '畅连月包', description: '适合日常办公的月度权益',
        mode: '按流量', quotaGb: 30, validityDays: 30, price: 39.9 },
      { id: 603, name: '不限量体验', description: '本地演示的限时不限量权益',
        mode: '不限量', quotaGb: 0, validityDays: 7, price: 9.9 }
    ],
    purchases: [
      { id: 701, productName: '畅连月包', amount: 39.9,
        purchasedAt: '2026-08-20 10:30', requestId: 'PURCHASE-DEMO-0001' }
    ],
    usage: [
      { id: 801, connectionName: '办公笔记本', trafficMb: 840,
        durationMinutes: 95, usedAt: '2026-08-31 16:20' },
      { id: 802, connectionName: '个人手机', trafficMb: 320,
        durationMinutes: 48, usedAt: '2026-08-30 09:15' }
    ],
    orders: [
      { id: 901, productId: 602, productName: '畅连月包', amount: 39.9,
        status: 'REFUNDING', orderRequestId: 'ORDER-DEMO-0001', createdAt: '2026-08-20 10:29' },
      { id: 902, productId: 601, productName: '轻量流量包', amount: 19.9,
        status: 'PENDING_PAYMENT', orderRequestId: 'ORDER-DEMO-0002', createdAt: '2026-08-31 18:00' }
    ],
    payments: [
      { id: 1001, orderId: 901, amount: 39.9, status: 'SUCCEEDED',
        paymentRequestId: 'PAYMENT-DEMO-0001', createdAt: '2026-08-20 10:30' }
    ],
    refunds: [
      { id: 1101, orderId: 901, productName: '畅连月包', amount: 39.9,
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

  orderDetail(userId: string, id: number): MemberOrder {
    this.guard()
    const order = this.data(userId).orders.find((item: MemberOrder): boolean => item.id === id)
    if (order === undefined) throw new ApiError('没有找到当前成员的订单', 404, 404, 'ORDER_NOT_FOUND')
    return cloneOrder(order)
  }

  createOrder(userId: string, productId: number, authorized: boolean): MemberOrder {
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
      id: this.nextOrderId++, productId: product.id, productName: product.name, amount: product.price,
      status: 'PENDING_PAYMENT', orderRequestId: `ORDER-DEMO-${String(this.orderSequence++).padStart(4, '0')}`,
      createdAt: '2026-09-01 11:30'
    }
    data.orders.unshift(order)
    return cloneOrder(order)
  }

  cancelOrder(userId: string, id: number, authorized: boolean): MemberOrder {
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

  paymentForOrder(userId: string, orderId: number): MemberPayment | null {
    this.guard()
    const payment = this.data(userId).payments.find((item: MemberPayment): boolean => item.orderId === orderId)
    return payment === undefined ? null : clonePayment(payment)
  }

  createPayment(userId: string, orderId: number, authorized: boolean): MemberPayment {
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
      id: this.nextPaymentId++, orderId: order.id, amount: order.amount, status: 'SUCCEEDED',
      paymentRequestId: `PAYMENT-DEMO-${String(this.paymentSequence++).padStart(4, '0')}`,
      createdAt: '2026-09-01 11:31'
    }
    data.payments.unshift(payment)
    order.status = 'PAID'
    data.purchases.unshift({
      id: 700 + payment.id, productName: order.productName, amount: order.amount,
      purchasedAt: payment.createdAt, requestId: `PURCHASE-${payment.paymentRequestId}`
    })
    return clonePayment(payment)
  }

  refunds(userId: string): MemberRefund[] {
    this.guard()
    if (this.scenario === 'EMPTY') return []
    return this.data(userId).refunds.map(cloneRefund)
  }

  refundDetail(userId: string, id: number): MemberRefund {
    this.guard()
    const refund = this.data(userId).refunds.find((item: MemberRefund): boolean => item.id === id)
    if (refund === undefined) throw new ApiError('没有找到当前退款申请', 404, 404, 'REFUND_NOT_FOUND')
    return cloneRefund(refund)
  }

  applyRefund(userId: string, orderId: number, reason: string, authorized: boolean): MemberRefund {
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
      id: this.nextRefundId++, orderId: order.id, productName: order.productName,
      amount: order.amount, reason: normalizedReason, status: 'PENDING',
      refundRequestId: `REFUND-DEMO-${String(this.refundSequence++).padStart(4, '0')}`,
      createdAt: '2026-09-01 11:32', reviewNote: ''
    }
    data.refunds.unshift(refund)
    order.status = 'REFUNDING'
    return cloneRefund(refund)
  }

  reviewRefund(userId: string, id: number, approved: boolean, note: string,
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

  tenantRefundDetail(tenantId: string, id: number): MemberRefund {
    this.guard()
    const refund = this.data(`${tenantId}|preview-member`).refunds
      .find((item: MemberRefund): boolean => item.id === id)
    if (refund === undefined) throw new ApiError('没有找到当前组织的退款申请', 404, 404, 'REFUND_NOT_FOUND')
    return cloneRefund(refund)
  }

  reviewTenantRefund(tenantId: string, id: number, approved: boolean, note: string,
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

export class RealHm5MemberRepository {
  private pending(): ApiError {
    return new ApiError('真实成员消费与位置接口等待公开契约', 503, 503, 'REAL_API_PENDING')
  }

  async summary(): Promise<MemberSummary> { throw this.pending() }
  async entitlement(): Promise<MemberEntitlement> { throw this.pending() }
  async products(_keyword: string): Promise<MemberProduct[]> { throw this.pending() }
  async purchases(): Promise<MemberPurchase[]> { throw this.pending() }
  async usage(): Promise<MemberUsageRecord[]> { throw this.pending() }
  async orders(): Promise<MemberOrder[]> { throw this.pending() }
  async orderDetail(_id: number): Promise<MemberOrder> { throw this.pending() }
  async createOrder(_productId: number): Promise<MemberOrder> { throw this.pending() }
  async cancelOrder(_id: number): Promise<MemberOrder> { throw this.pending() }
  async paymentForOrder(_orderId: number): Promise<MemberPayment | null> { throw this.pending() }
  async createPayment(_orderId: number): Promise<MemberPayment> { throw this.pending() }
  async refunds(): Promise<MemberRefund[]> { throw this.pending() }
  async refundDetail(_id: number): Promise<MemberRefund> { throw this.pending() }
  async applyRefund(_orderId: number, _reason: string): Promise<MemberRefund> { throw this.pending() }
  async reviewRefund(_id: number, _approved: boolean, _note: string): Promise<MemberRefund> {
    throw this.pending()
  }
  async tenantRefunds(): Promise<MemberRefund[]> { throw this.pending() }
  async tenantRefundDetail(_id: number): Promise<MemberRefund> { throw this.pending() }
  async reviewTenantRefund(_id: number, _approved: boolean, _note: string): Promise<MemberRefund> {
    throw this.pending()
  }
  async locationPermission(): Promise<MemberLocationPermission> { throw this.pending() }
  async setLocationPermission(_granted: boolean): Promise<MemberLocationPermission> { throw this.pending() }
  async locationHistory(): Promise<MemberLocationRecord[]> { throw this.pending() }
  async clearLocationHistory(): Promise<void> { throw this.pending() }
}
