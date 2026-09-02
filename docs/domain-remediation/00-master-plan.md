# HarmonyOS Demo domain remediation master plan

## 1. Objective

Correct the HarmonyOS Demo before backend integration and publication.
Production code must be organized by stable business domains rather than
delivery phases. The result must preserve the frozen page scope in the 07/08
plans while making every exposed Demo workflow truthful, deterministic, and
domain-specific.

This plan does not authorize commit or push. It does not require a separate
worktree, CONTROL gate, frozen hash, or independent acceptance role.

## 2. Baseline

- Repository: `D:\HarmonyOS\WiFiEdgeManager`
- Branch at planning time: `main`
- HEAD at planning time: `3a3196ab36aec04f98e3c34b3aa37edc74fee5e6`
- Existing uncommitted API-catalog and repository work must be preserved.
- Product scope remains the 07 phased plan and 08 page registry.
- Real API truth comes from
  `F:\MyProject\summary\wifi-manager-HarmonyOS\15-harmony-real-api-catalog.json`.
- Historical HM labels may remain in plans and audit history. They must not
  define production model, repository, error, or page contracts.

## 3. Delivery stages

| Stage | Plan | Main outcome |
| --- | --- | --- |
| 1 | `01-integrity-and-navigation.md` | Remove unsafe fallback, ownership, navigation, and persistence behavior |
| 2 | `02-organization-and-commerce.md` | Replace generic organization, SaaS, Marketplace, entitlement, order, payment, and refund behavior with domain contracts |
| 3 | `03-content-and-operations.md` | Replace generic content, support, notice, AI review, runtime, and audit behavior with domain contracts |
| 4 | `04-production-domain-naming.md` | Remove phase identifiers from production source and shared contracts |
| 5 | `05-real-mode-and-api-coverage.md` | Make Real mode truthful and connect all source-proven CURRENT APIs |
| 6 | `06-final-system-validation.md` | Prove page coverage, domain behavior, architecture, build, signing, and physical-device journeys |

Stages run in order. A later stage may prepare code needed by an earlier stage,
but no stage is marked complete until its own audit protocol passes.

## 4. Domain boundaries

Production code must converge on these boundaries:

- account
- organization
- entitlement
- order
- payment
- refund
- device
- session
- security
- location
- marketplace
- content
- support
- AI review
- runtime and audit

Cross-domain composition belongs in pages or application services. A generic
record type must not erase domain identity, status transitions, authorization,
or data ownership.

## 5. Aggregate ownership and projections

Every mutable Demo business object has exactly one canonical aggregate store.
Platform, delegated-tenant, tenant-admin, and member pages are projections over
that store; they are not separate copies keyed by the viewing role.

- Shared tenant state is keyed by `tenantId` plus its domain identifier.
- Member-private state is keyed by `tenantId`, owner `userId`, and its domain
  identifier.
- Platform-global state is keyed by its domain identifier.
- A command mutates the canonical aggregate once. All authorized projections
  must observe the result.
- Query filtering enforces visibility; it must not redefine ownership.
- Reset recreates aggregates once and then derives every projection.

Each domain stage must include a table naming its aggregate owner, key, writers,
and page projections. Cross-role continuity is an acceptance requirement.

## 6. Audit protocol for every stage

Each stage uses a consecutive-clean-review rule:

1. Implement the bounded stage.
2. Run Audit A against the working tree and the stage acceptance matrix.
3. If Audit A finds any defect, record it, repair it, and restart at step 2.
   The clean-review count returns to zero.
4. If Audit A has zero findings, run Audit B as a fresh review of the current
   files and evidence. Audit B must not merely quote Audit A.
5. If Audit B finds any defect, repair it and restart at step 2.
6. The stage passes only when Audit A and the immediately following Audit B
   both report zero findings.

An environment failure is evidence to diagnose, not a reason to abandon the
stage. Continue other available implementation and static-review work, repair
the environment when possible, and clearly record anything that genuinely
cannot be verified.

## 7. Required audit record

For each audit attempt, record:

- stage and attempt number;
- files and page IDs reviewed;
- behavior and architecture checks performed;
- tests, build, signing, and device evidence actually run;
- findings with file references;
- repairs made after findings;
- unresolved external dependencies;
- consecutive clean-review count.

Audit reports describe evidence. They do not become a second implementation
project and do not block useful work because of formatting, hashing, or report
packaging defects.

## 8. Global constraints

- Preserve all user-authored and existing uncommitted changes.
- Do not reset, clean, checkout over, or bulk-normalize the worktree.
- Do not stage, commit, or push without explicit user authorization.
- Do not read or change phone system settings.
- Device work is application-scoped: build, verify, install, launch, navigate,
  inspect app output, and collect app-scoped logs only.
- Demo mode must not instantiate Real repositories or perform HTTP, WebSocket,
  or MQTT requests.
- Real mode must never fall back to Demo data.
- `CURRENT`, `PARTIAL`, and `PREDICTED` capability labels must remain truthful.
- Unknown identifiers must never resolve to or mutate a different record.
- Tenant-owned state must not be partitioned by the current administrator.
- A role-specific page must not own a duplicate copy of a shared aggregate.

## 9. Completion definition

The remediation is complete when all six stages have two consecutive clean
audits, the 07/08 page scope is represented truthfully, production source has
domain-based boundaries, all usable CURRENT APIs are connected or have a
documented source-level reason not to be exposed, and the final application
evidence is current.
