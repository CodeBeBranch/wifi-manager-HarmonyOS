export type Hm7Capability =
  'ENTITLEMENT' | 'SAAS' | 'MARKETPLACE' | 'CONTENT' | 'SUPPORT' |
  'AI_REVIEW' | 'RUNTIME' | 'AUDIT' | 'ORGANIZATION' | 'MEMBER' | 'NOTICE'

export type Hm7Scope = 'PLATFORM' | 'TENANT' | 'MEMBER'
export type Hm7PageMode = 'LIST' | 'DETAIL' | 'EDITOR'

export interface Hm7RequestContext {
  scope: Hm7Scope
  role: number
  userId: string
  tenantId: string
  tenantRole: string
  contextType: string
}

export interface Hm7Record {
  id: number
  capability: Hm7Capability
  tenantId: string
  ownerId: string
  title: string
  subtitle: string
  status: string
  summary: string
  detail: string
  metricLabel: string
  metricValue: string
  updatedAt: string
}

export interface Hm7RecordInput {
  title: string
  subtitle: string
  detail: string
}

export interface Hm7ActionResult {
  record: Hm7Record
  requestId: string
  message: string
}

export interface Hm7PageConfig {
  pageId: string
  title: string
  eyebrow: string
  capability: Hm7Capability
  scope: Hm7Scope
  mode: Hm7PageMode
  emptyText: string
  detailRoute: string
  editorRoute: string
  primaryAction: string
  secondaryAction: string
  readOnly: boolean
}
