# Stage 3: content and operations domains

## Goal

Replace the remaining generic page behavior with domain-specific contracts for
announcements, comments, support, notices, AI review, runtime jobs, and audit
records.

## Page scope

Content:

- P115/P116/P127 platform announcements
- P221/P238/P239 tenant announcements
- P311/P323 member announcements and comments

Support:

- P118/P128 platform support
- P222/P240/P241 tenant support
- P312/P324/P325 member support

AI review, runtime, audit, and notice:

- P117/P133 AI review
- P119/P129/P130 runtime jobs
- P120/P131 platform audit
- P212 tenant audit list
- P232 tenant audit detail
- P007/P008 account notice list/detail and safe deep links
- P313/P326 member notices

## Canonical aggregate ownership

| Aggregate | Canonical key | Writers | Required projections |
| --- | --- | --- | --- |
| Announcement | `publisherScope + tenantId + announcementId` | authorized platform or tenant editor | platform P115/P116/P127, tenant P221/P238/P239, member P311/P323 according to visibility |
| Announcement comment | `announcementId + commentId` | authorized member/tenant moderation | P238 and P323 |
| Support ticket | `tenantId + ticketNo` | member/tenant creation and authorized support commands | P118/P128, P222/P240/P241, P312/P324/P325 |
| Support message | `ticketNo + messageId` | authorized ticket participants | every support detail projection |
| User notice | `workspaceScope + optional tenantId + userId + noticeId` | domain event/demo seed; user read command | P007/P008 and P313/P326 |
| AI review task | `reviewId` | platform reviewer | P117/P133 |
| Runtime job | `jobId` | runtime system and authorized recovery | P119/P129/P130 |
| Audit record | `scope + tenantId + auditId` | append-only domain event projection | P120/P131 and P212/P232 |

Platform-wide announcements use an empty tenant component and may project to
all authorized tenants/members. Tenant announcements remain tenant-owned.
Member-created support tickets and replies must be visible in the authorized
tenant and platform views with the same ticket/message identifiers and state.
P007/P008 query notices for the active workspace and use the typed notice
target to change workspace when a deep link requires it. P313/P326 are the
member-workspace projection of the same user-owned notices.

## Required domain contracts

Use separate models and repositories for:

- `Announcement`, `AnnouncementDraft`, `AnnouncementCommand`;
- `AnnouncementComment`, `CommentCommand`;
- `SupportTicket`, `SupportMessage`, `TicketCommand`;
- `UserNotice`, `NoticeTarget`, `NoticeCommand`;
- `AiReviewTask`, `AiEvidence`, `AiReviewCommand`;
- `RuntimeHealth`, `RuntimeJob`, `RuntimeJobCommand`;
- `AuditRecord` and immutable audit detail.

Do not use one title/subtitle/detail/metric record for these domains.

## Required implementation

1. Give every page a page-specific query and command contract.
   Each query is a projection over the canonical aggregate table above; it is
   not a role-specific data store.
2. Keep comments separate from announcement records. Comment count is derived
   from comment state and must not be parsed from display text.
3. Keep support messages separate from tickets. Assignment, reply, resolve, and
   member-close are distinct commands with role checks.
4. Notice deep links use a typed target and validate route availability and
   current workspace before navigation.
5. AI review uses explicit approve, reject, and transfer-to-manual commands.
   A composite label must never select a command by substring order.
6. Runtime recovery requires the defined confirmation state and only applies to
   recoverable failed jobs.
7. Audit records are immutable. Tenant audit remains hidden in Real mode while
   the backend query lacks a tenant boundary.
8. Marketplace, content, support, and AI pages whose public APIs remain
   PLANNED/PREDICTED stay fully functional in Demo mode and hidden in Real mode.
9. Demo partial failure remains capability-local and cannot disable unrelated
   domains.
10. P007/P008 and P313/P326 use one notice repository and read state. Their
    different navigation surfaces must not duplicate a user's notice.
11. P212 and P232 use one tenant-audit query contract; list and detail enforce
    the same tenant boundary.

## Tests

Add focused contracts for:

- announcement draft, publish, withdraw, and comment behavior;
- tenant and member content visibility;
- a published platform/tenant announcement appears only in its authorized
  projections and preserves one announcement ID;
- ticket create, reply, assign, resolve, and close permissions;
- message ordering and ticket persistence;
- a member-created ticket and subsequent replies propagate through member,
  tenant, and platform projections;
- safe notice deep links and mark-read behavior;
- notice read state is consistent between P007/P008 and P313/P326;
- each AI review command and partial failure isolation;
- runtime job filtering, confirmation, recovery, and invalid transition;
- audit immutability and tenant Real-mode hiding;
- unknown identifiers and tenant isolation in every domain.

## Audit A

Review domain schemas, repository ownership, typed commands, page actions,
visibility rules, and failure isolation. Run the focused tests and inspect each
list/detail/editor journey.

Any command inferred from display text, mutable audit record, shared generic
record collection, role-owned duplicate aggregate, or visible unsupported Real
page is a finding.

## Audit B

Start from the 08 registry and independently trace every page ID in this plan.
Repeat command and isolation checks using alternate records and scenarios.
Verify that no stage-2 domain regressed.

The stage passes only after two consecutive zero-finding audits.
