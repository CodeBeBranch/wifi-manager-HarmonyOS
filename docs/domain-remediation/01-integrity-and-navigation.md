# Stage 1: integrity and navigation correction

## Goal

Remove behaviors that can display or mutate the wrong record, leak or hide
tenant-owned state, or lose edits across page boundaries. This stage creates a
safe base for later domain extraction.

## Scope

- Generic capability repository and page adapter currently implemented by
  `Hm7CapabilityRepository`, `Hm7FeaturePage`, and `Hm7PageConfigs`.
- P108 platform account entitlement transition.
- P122 SaaS plan editor and its list/detail return path.
- Tenant, platform-delegated tenant, and member context construction.
- Focused unit tests for identity, ownership, and navigation.

## Required implementation

1. Unknown identifiers:
   - `detail(id)` returns a domain-appropriate 404 when `id` is absent.
   - `act(id, command)` returns 404 when `id` is absent.
   - update operations return 404 for an unknown non-create ID.
   - no method may use `source[0]` as an identifier fallback.
2. Ownership:
   - tenant-shared records are keyed by tenant and domain, not by administrator
     `userId`;
   - member-private records are keyed by tenant, owner, and domain identifier;
   - role-specific pages query projections and never create duplicate stores;
   - platform data is platform-owned and cannot collide with tenant data.
3. Temporary command safety:
   - remove all `action.includes(...)` and other substring dispatch;
   - use a minimal exact-match legacy adapter only until stages 2 and 3 replace
     the affected pages;
   - do not introduce public HM-7 command types, a reusable transition engine,
     or another generic command architecture;
   - reject unknown commands with 400;
   - explicitly map composite labels so one label cannot select the wrong
     branch;
   - stages 2 and 3 own the final typed commands and transition validation.
4. P122 consistency:
   - list, detail, and editor use one SaaS-plan source of truth;
   - a created or edited plan remains visible after returning to P109/P110;
   - an unknown edit target returns 404 instead of creating a different plan.
5. P108 identity:
   - navigation carries the selected account and tenant identity explicitly;
   - the destination validates both identities against the active delegated
     workspace;
   - returning restores the originating platform account page.
6. State reset:
   - scenario reset restores deterministic domain state and sequences;
   - reset must not contaminate Real repositories or session state.

## Tests

Add focused contracts for:

- unknown detail and action IDs return 404 and leave all records unchanged;
- two tenant administrators see the same tenant-owned mutation;
- two tenants do not see each other's state;
- member-private records remain isolated by owner;
- role projections do not duplicate canonical records;
- substring and ambiguous composite actions cannot execute;
- unknown legacy actions fail without mutation;
- P122 edit survives list/detail navigation;
- P108 receives and validates the intended account and tenant;
- reset restores the same deterministic state twice.

## Audit A

Review every changed branch for identifier lookup, state key construction,
command dispatch, and route parameter handling. Run focused tests and inspect
the affected page journeys in Demo mode.

Audit A has a finding if any fallback-to-first behavior, user-keyed shared
tenant state, substring-derived command, role-owned duplicate store,
cross-repository edit, or implicit P108 identity remains. The temporary adapter
must remain a small compatibility boundary scheduled for deletion, not a new
HM-7 architecture.

## Audit B

Re-read the resulting repository and pages without relying on Audit A notes.
Use different test data for unknown IDs, two administrators, and two tenants.
Trace P108 and P122 from their source page through return navigation.

The stage passes only when Audit A and the immediately following Audit B both
have zero findings.

## Out of scope

- Full replacement of every generic page.
- Production API wiring.
- Phase-name removal outside files that must change for these corrections.
