export type Hm5OrderStatus = 'PENDING_PAYMENT' | 'PAID' | 'CANCELLED' | 'REFUNDING' | 'REFUNDED'
export type Hm5PaymentStatus = 'PROCESSING' | 'SUCCEEDED' | 'FAILED'
export type Hm5RefundStatus = 'PENDING' | 'APPROVED' | 'REJECTED'

export interface MemberSummary {
  entitlementName: string
  remainingGb: number
  remainingLabel: string
  activeConnections: number
  pendingOrders: number
  unreadNotices: number
}

export interface MemberEntitlement {
  id: number
  name: string
  mode: string
  remainingGb: number
  remainingLabel: string
  expiresAt: string
  status: string
}

export interface MemberProduct {
  id: string
  name: string
  description: string
  mode: string
  quotaGb: number
  quotaLabel: string
  validityDays: number
  price: number
}

export interface MemberPurchase {
  id: string
  orderId: string
  productName: string
  amount: number
  purchasedAt: string
  requestId: string
}

export interface MemberUsageRecord {
  id: number
  connectionName: string
  trafficMb: number
  durationMinutes: number
  usedAt: string
}

export interface MemberOrder {
  id: string
  productId: string
  productName: string
  amount: number
  status: Hm5OrderStatus
  orderRequestId: string
  createdAt: string
}

export interface MemberPayment {
  id: string
  orderId: string
  amount: number
  status: Hm5PaymentStatus
  paymentRequestId: string
  createdAt: string
}

export interface MemberRefund {
  id: string
  orderId: string
  productName: string
  amount: number
  reason: string
  status: Hm5RefundStatus
  refundRequestId: string
  createdAt: string
  reviewNote: string
}

export interface MemberLocationPermission {
  granted: boolean
  precision: string
  updatedAt: string
}

export interface MemberLocationRecord {
  id: number
  place: string
  accuracyMeters: number
  recordedAt: string
}
