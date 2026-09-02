# Stage 2: organization and commerce domains

## Goal

Replace generic records for organization, membership, SaaS, Marketplace,
entitlement, order, payment, and refund workflows with domain-specific models,
repositories, commands, and page contracts.

## Page scope

Organization and membership:

- P101 platform tenant list
- P102 platform tenant create
- P103 platform tenant detail
- P104 platform tenant members
- P213 organization
- P214 member list
- P215 invitation list
- P216 owner transfer
- P233 member detail
- P300 member home summary projection
- P315 member service catalog projection

SaaS and entitlement:

- P108 account entitlement
- P109/P110 existing SaaS plan list/detail
- P111 subscriptions
- P112 platform quota
- P122 SaaS plan editor
- P123 subscription detail
- P217 tenant subscription
- P218 tenant quota

Marketplace:

- P113/P124/P125 platform products
- P114/P126 platform orders
- P220/P235 tenant products
- P236/P237 tenant orders
- P310/P320 member products
- P321/P322 member orders

Existing member commerce pages P303/P304/P305/P306/P307/P308/P309 and
P316/P317/P318/P319 are included for shared contract alignment, not visual
redesign.

## Canonical aggregate ownership

| Aggregate | Canonical key | Writers | Required projections |
| --- | --- | --- | --- |
| Organization | `tenantId` | platform tenant management, tenant owner/admin profile update | P101/P102/P103/P104 and P213 |
| Organization member | `tenantId + memberId` | tenant owner/admin according to action matrix | P104, P214, P233, P300/P315 summaries |
| Invitation | `tenantId + invitationId` | tenant owner/admin | P215 and member-count summaries |
| Owner transfer | `tenantId + transferId` | current tenant owner | P216 and resulting P104/P214/P233 roles |
| SaaS plan | `planId` | platform SaaS administration | P109, P110, P122 |
| Subscription | `tenantId + subscriptionId` | platform subscription administration | P111, P123, P217 |
| Quota | `tenantId + subscriptionId` | authorized platform adjustment | P112, P218 and member summaries |
| Marketplace product | `productCode` | platform Marketplace administration | P113/P124/P125, P220/P235, P310/P320 |
| Marketplace order | `tenantId + orderNo` | member purchase and authorized fulfillment | P114/P126, P236/P237, P321/P322 |
| Entitlement/purchase/usage | `tenantId + userId + businessId` | purchase and usage flows | P108/P303/P304/P305/P316 |
| Order | `tenantId + userId + orderNo` | member order flow | P306/P307/P317 and tenant/platform projections where registered |
| Payment | `tenantId + userId + paymentNo` | member payment flow | P307/P308 |
| Refund | `tenantId + userId + refundNo` | member application and authorized review | P234, P309/P318/P319 |

Marketplace and entitlement orders remain distinct aggregate types. A P320
purchase creates one Marketplace order that is immediately visible, subject to
authorization, in P321/P322, P236/P237, and P114/P126. It must not appear in
the entitlement order list P306 unless an explicit conversion contract exists.

## Required domain contracts

Create or consolidate explicit types for:

- `Organization`, `OrganizationUpdate`;
- `OrganizationMember`, `MemberRoleChange`;
- `Invitation`, `InvitationCreate`, `InvitationCommand`;
- `OwnerTransfer`, `OwnerTransferCommand`;
- `SaasPlan`, `Subscription`, `QuotaSnapshot`, `QuotaAdjustment`;
- `MarketplaceProduct`, `MarketplaceSku`, `ProductCommand`;
- `MarketplaceOrder`, `Fulfillment`, `OrderCommand`;
- `Entitlement`, `Purchase`, `UsageRecord`;
- `Payment`, `PaymentChannel`, `PaymentCommand`;
- `Refund`, `RefundReviewCommand`.

Product and order collections must be separate. Member and invitation
collections must be separate. Owner transfer must be a state machine, not a
member status string.

## Required implementation

1. Replace generic capability selection for all page IDs in this plan with
   domain repositories and page-specific view models.
   Domain repositories expose role-specific queries over the canonical
   aggregates above; pages do not own role-specific copies.
2. Use stable string business identifiers where backend contracts use codes or
   numbers such as productCode, orderNo, paymentNo, refundNo, and purchaseId.
3. Implement typed status transitions with role checks:
   - platform product create/edit/publish/unpublish;
   - order fulfillment and exception handling;
   - tenant invitation create/resend/revoke;
   - member role update and removal;
   - owner transfer start/confirm/cancel;
   - subscription assignment/renew/disable and quota adjustment;
   - member purchase, payment, refund application, and refund review.
4. Preserve the action matrix:
   - platform delegate is read-only except explicitly frozen delegated actions;
   - tenant admin cannot transfer ownership;
   - member can only operate the member's own orders, payments, and refunds.
5. Marketplace remains Demo-only while the API catalog marks it PLANNED.
   Real mode must hide its entry points and must not throw a pending error from
   a visible page.
6. Reconcile P122 with P109/P110 using the same SaaS repository.
7. Keep established member commerce Real mappings; split mixed repositories
   where necessary without losing current wire-schema behavior.
8. Keep P101/P102/P103/P104 and P213/P214/P215/P216/P233 on the same
   organization and membership aggregates. Platform delegation changes the
   projection and permissions, not the stored organization.
9. Derive P300 and P315 counts and summaries from the same entitlement, order,
   notice, and member aggregates used by their destination pages.

## Tests

Add page/domain contracts for every listed page ID, including:

- distinct product and order lists;
- distinct member and invitation lists;
- one member Marketplace purchase appears in authorized member, tenant, and
  platform order projections with the same `orderNo`;
- member-created refunds and tenant/platform review observe one refund state;
- organization and role changes propagate across P101/P102/P103/P104 and
  P213/P214/P215/P216/P233;
- owner-transfer authorization and transition matrix;
- tenant isolation and shared administrator visibility;
- unknown identifiers and stale transitions;
- platform delegate read-only behavior;
- string business identifier preservation;
- member ownership checks;
- Demo Marketplace visibility and Real Marketplace hiding;
- P109/P110/P122 persistence consistency.

## Audit A

Trace each page ID to a domain model, repository method, command, and state
owner. Review role and tenant boundaries. Run focused organization and commerce
tests and inspect list-to-detail-to-action-to-list behavior.

Any remaining generic `MARKETPLACE`, `MEMBER`, `SAAS`, or `ENTITLEMENT` record
collection serving multiple entities is a finding. Separate role-owned copies
of the same aggregate are also a finding.

## Audit B

Review from the page registry instead of from changed files. For each page,
prove its declared actions, scope, roles, Demo visibility, and Real visibility.
Use fresh tenant/member identities and repeat cross-page persistence checks.

The stage passes only after two consecutive zero-finding audits.
