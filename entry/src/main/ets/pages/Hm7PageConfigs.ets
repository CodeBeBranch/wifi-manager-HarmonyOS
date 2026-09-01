import {
  Hm7Capability,
  Hm7PageConfig,
  Hm7PageMode,
  Hm7Scope
} from '../model/Hm7Models'

function config(pageId: string, title: string, eyebrow: string,
  capability: Hm7Capability, scope: Hm7Scope,
  mode: Hm7PageMode, emptyText: string, detailRoute: string,
  editorRoute: string, primaryAction: string, secondaryAction: string,
  readOnly: boolean): Hm7PageConfig {
  return {
    pageId: pageId, title: title, eyebrow: eyebrow, capability: capability,
    scope: scope, mode: mode, emptyText: emptyText, detailRoute: detailRoute,
    editorRoute: editorRoute, primaryAction: primaryAction,
    secondaryAction: secondaryAction, readOnly: readOnly
  }
}

export function hm7PageConfig(pageId: string): Hm7PageConfig {
  if (pageId === 'P108') return config(pageId, '账号权益', '平台代管', 'ENTITLEMENT', 'TENANT',
    'DETAIL', '账号权益暂不可用', '', '', '调整权益', '创建奖励订单', false)
  if (pageId === 'P111') return config(pageId, '订阅管理', '平台服务', 'SAAS', 'PLATFORM',
    'LIST', '没有订阅记录', 'pages/PlatformSubscriptionDetailPage', '', '', '', false)
  if (pageId === 'P112') return config(pageId, '平台配额', '订阅管理', 'SAAS', 'PLATFORM',
    'DETAIL', '配额暂不可用', '', '', '调整配额', '', false)
  if (pageId === 'P113') return config(pageId, 'Marketplace 商品', '平台服务', 'MARKETPLACE',
    'PLATFORM', 'LIST', '没有商品', 'pages/PlatformMarketplaceProductDetailPage',
    'pages/PlatformMarketplaceProductEditorPage', '', '', false)
  if (pageId === 'P114') return config(pageId, 'Marketplace 订单', '平台服务', 'MARKETPLACE',
    'PLATFORM', 'LIST', '没有订单', 'pages/PlatformMarketplaceOrderDetailPage', '', '', '', false)
  if (pageId === 'P115') return config(pageId, '公告治理', '平台内容', 'CONTENT', 'PLATFORM',
    'LIST', '没有公告', 'pages/PlatformAnnouncementDetailPage',
    'pages/PlatformAnnouncementEditorPage', '', '', false)
  if (pageId === 'P116') return config(pageId, '公告编辑', '平台内容', 'CONTENT', 'PLATFORM',
    'EDITOR', '公告暂不可用', '', '', '', '', false)
  if (pageId === 'P117') return config(pageId, 'AI 人工复核', '平台治理', 'AI_REVIEW', 'PLATFORM',
    'LIST', '没有待复核项目', 'pages/PlatformAiReviewDetailPage', '', '', '', false)
  if (pageId === 'P118') return config(pageId, 'Support 工单', '平台服务', 'SUPPORT', 'PLATFORM',
    'LIST', '没有工单', 'pages/PlatformSupportDetailPage', '', '', '', false)
  if (pageId === 'P119') return config(pageId, '运行状态', '平台运维', 'RUNTIME', 'PLATFORM',
    'LIST', '没有运行任务', 'pages/PlatformRuntimeJobDetailPage', '', '', '', false)
  if (pageId === 'P120') return config(pageId, '平台审计', '平台治理', 'AUDIT', 'PLATFORM',
    'LIST', '没有审计记录', 'pages/PlatformAuditDetailPage', '', '', '', true)
  if (pageId === 'P122') return config(pageId, 'SaaS 套餐编辑', '平台服务', 'SAAS', 'PLATFORM',
    'EDITOR', '套餐暂不可用', '', '', '', '', false)
  if (pageId === 'P123') return config(pageId, '订阅详情', '订阅管理', 'SAAS', 'PLATFORM',
    'DETAIL', '订阅不存在', '', '', '续期', '停用', false)
  if (pageId === 'P124') return config(pageId, '商品详情', 'Marketplace', 'MARKETPLACE', 'PLATFORM',
    'DETAIL', '商品不存在', '', 'pages/PlatformMarketplaceProductEditorPage', '上架', '下架', false)
  if (pageId === 'P125') return config(pageId, '商品编辑', 'Marketplace', 'MARKETPLACE', 'PLATFORM',
    'EDITOR', '商品暂不可用', '', '', '', '', false)
  if (pageId === 'P126') return config(pageId, '订单详情', 'Marketplace', 'MARKETPLACE', 'PLATFORM',
    'DETAIL', '订单不存在', '', '', '处理异常', '', false)
  if (pageId === 'P127') return config(pageId, '公告详情', '平台内容', 'CONTENT', 'PLATFORM',
    'DETAIL', '公告不存在', '', 'pages/PlatformAnnouncementEditorPage', '发布', '撤回', false)
  if (pageId === 'P128') return config(pageId, '工单详情', '平台 Support', 'SUPPORT', 'PLATFORM',
    'DETAIL', '工单不存在', '', '', '分派工单', '解决工单', false)
  if (pageId === 'P129') return config(pageId, '异常任务', '平台运行', 'RUNTIME', 'PLATFORM',
    'LIST', '没有异常任务', 'pages/PlatformRuntimeJobDetailPage', '', '', '', false)
  if (pageId === 'P130') return config(pageId, '任务详情', '平台运行', 'RUNTIME', 'PLATFORM',
    'DETAIL', '任务不存在', '', '', '人工恢复', '', false)
  if (pageId === 'P131') return config(pageId, '审计详情', '平台治理', 'AUDIT', 'PLATFORM',
    'DETAIL', '审计记录不存在', '', '', '', '', true)
  if (pageId === 'P133') return config(pageId, '复核详情', 'AI 人工复核', 'AI_REVIEW', 'PLATFORM',
    'DETAIL', '复核项目不存在', '', '', '通过复核', '驳回并转人工', false)

  if (pageId === 'P213') return config(pageId, '组织资料', '租户组织', 'ORGANIZATION', 'TENANT',
    'EDITOR', '组织资料暂不可用', '', '', '', '', false)
  if (pageId === 'P214') return config(pageId, '组织成员', '租户组织', 'MEMBER', 'TENANT',
    'LIST', '没有成员', 'pages/TenantMemberDetailPage', '', '', '', false)
  if (pageId === 'P215') return config(pageId, '成员邀请', '租户组织', 'MEMBER', 'TENANT',
    'LIST', '没有邀请记录', 'pages/TenantMemberDetailPage', '', '', '', false)
  if (pageId === 'P216') return config(pageId, '所有权转移', '租户组织', 'MEMBER', 'TENANT',
    'DETAIL', '没有可转移成员', '', '', '发起转移', '取消转移', false)
  if (pageId === 'P217') return config(pageId, '当前订阅', '租户服务', 'SAAS', 'TENANT',
    'DETAIL', '订阅暂不可用', '', '', '', '', true)
  if (pageId === 'P218') return config(pageId, '配额与用量', '租户服务', 'SAAS', 'TENANT',
    'DETAIL', '配额暂不可用', '', '', '', '', true)
  if (pageId === 'P220') return config(pageId, 'Marketplace 商品', '租户服务', 'MARKETPLACE',
    'TENANT', 'LIST', '没有商品', 'pages/TenantMarketplaceProductDetailPage', '', '', '', true)
  if (pageId === 'P221') return config(pageId, '组织公告', '租户内容', 'CONTENT', 'TENANT',
    'LIST', '没有公告', 'pages/TenantAnnouncementDetailPage',
    'pages/TenantAnnouncementEditorPage', '', '', false)
  if (pageId === 'P222') return config(pageId, 'Support 工单', '租户服务', 'SUPPORT', 'TENANT',
    'LIST', '没有工单', 'pages/TenantSupportDetailPage', 'pages/TenantSupportEditorPage', '', '', false)
  if (pageId === 'P233') return config(pageId, '成员详情', '租户组织', 'MEMBER', 'TENANT',
    'DETAIL', '成员不存在', '', '', '调整角色', '移除成员', false)
  if (pageId === 'P235') return config(pageId, '商品详情', '租户 Marketplace', 'MARKETPLACE',
    'TENANT', 'DETAIL', '商品不存在', '', '', '', '', true)
  if (pageId === 'P236') return config(pageId, 'Marketplace 订单', '租户服务', 'MARKETPLACE',
    'TENANT', 'LIST', '没有订单', 'pages/TenantMarketplaceOrderDetailPage', '', '', '', true)
  if (pageId === 'P237') return config(pageId, '订单详情', '租户 Marketplace', 'MARKETPLACE',
    'TENANT', 'DETAIL', '订单不存在', '', '', '', '', true)
  if (pageId === 'P238') return config(pageId, '公告详情', '租户内容', 'CONTENT', 'TENANT',
    'DETAIL', '公告不存在', '', 'pages/TenantAnnouncementEditorPage', '发布', '撤回', false)
  if (pageId === 'P239') return config(pageId, '公告编辑', '租户内容', 'CONTENT', 'TENANT',
    'EDITOR', '公告暂不可用', '', '', '', '', false)
  if (pageId === 'P240') return config(pageId, '创建工单', '租户 Support', 'SUPPORT', 'TENANT',
    'EDITOR', '工单暂不可用', '', '', '', '', false)
  if (pageId === 'P241') return config(pageId, '工单详情', '租户 Support', 'SUPPORT', 'TENANT',
    'DETAIL', '工单不存在', '', '', '回复并分派', '解决工单', false)

  if (pageId === 'P310') return config(pageId, 'Marketplace 商品', '成员服务', 'MARKETPLACE',
    'MEMBER', 'LIST', '没有商品', 'pages/MemberMarketplaceProductDetailPage', '', '', '', true)
  if (pageId === 'P311') return config(pageId, '公告', '成员服务', 'CONTENT', 'MEMBER',
    'LIST', '没有公告', 'pages/MemberAnnouncementDetailPage', '', '', '', true)
  if (pageId === 'P312') return config(pageId, '我的工单', '成员服务', 'SUPPORT', 'MEMBER',
    'LIST', '没有工单', 'pages/MemberSupportDetailPage', 'pages/MemberSupportEditorPage', '', '', false)
  if (pageId === 'P313') return config(pageId, '消息', '成员服务', 'NOTICE', 'MEMBER',
    'LIST', '没有消息', 'pages/MemberMessageDetailPage', '', '', '', false)
  if (pageId === 'P320') return config(pageId, '商品详情', '成员 Marketplace', 'MARKETPLACE',
    'MEMBER', 'DETAIL', '商品不存在', '', '', '购买', '', false)
  if (pageId === 'P321') return config(pageId, 'Marketplace 订单', '成员服务', 'MARKETPLACE',
    'MEMBER', 'LIST', '没有订单', 'pages/MemberMarketplaceOrderDetailPage', '', '', '', true)
  if (pageId === 'P322') return config(pageId, '订单详情', '成员 Marketplace', 'MARKETPLACE',
    'MEMBER', 'DETAIL', '订单不存在', '', '', '', '', true)
  if (pageId === 'P323') return config(pageId, '公告详情', '成员内容', 'CONTENT', 'MEMBER',
    'DETAIL', '公告不存在', '', '', '发表评论', '', false)
  if (pageId === 'P324') return config(pageId, '创建工单', '成员 Support', 'SUPPORT', 'MEMBER',
    'EDITOR', '工单暂不可用', '', '', '', '', false)
  if (pageId === 'P325') return config(pageId, '工单详情', '成员 Support', 'SUPPORT', 'MEMBER',
    'DETAIL', '工单不存在', '', '', '回复', '关闭工单', false)
  if (pageId === 'P326') return config(pageId, '消息详情', '成员服务', 'NOTICE', 'MEMBER',
    'DETAIL', '消息不存在', '', '', '标记已读', '', false)

  return config(pageId, '计划能力', 'WiFi Manager', 'SAAS', 'PLATFORM',
    'LIST', '没有数据', '', '', '', '', true)
}
