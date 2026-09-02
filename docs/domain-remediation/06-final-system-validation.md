# Stage 6: final system validation

## Goal

Validate the corrected Demo as one application after all domain remediation.
This stage verifies behavior and evidence; it does not reintroduce delivery
phase architecture.

## Static coverage

Verify:

- every 08-registry page has exactly one registration and an existing file;
- every static route target is registered;
- every leaf page maps to one stable business domain;
- home, service-catalog, and dashboard pages declare themselves as composition
  surfaces and obtain each section from its owning domain projection;
- every declared page action has a typed command or is explicitly read-only;
- role, workspace, tenant, and owner boundaries match the registry;
- unsupported Real pages are hidden;
- Demo repositories cannot perform network operations;
- Real repositories cannot fall back to Demo;
- production ArkTS has no phase-based contracts;
- `git diff --check` passes apart from understood line-ending warnings.

## Automated tests

Run the complete ArkTS suite and require zero failures. Coverage must include:

- page/domain contracts for all 122 registry entries;
- cross-role projection continuity for organization membership, Marketplace
  orders, refunds, announcements, support tickets, notices, and audit records;
- unknown-ID and invalid-transition behavior;
- tenant and member isolation;
- role/action matrices;
- deterministic scenario reset;
- Demo network sentinel;
- Real wire mappings and visibility;
- route and page registration uniqueness.

Test count alone is not evidence. Every registered workflow must be represented
by a page/domain assertion rather than only a generic repository test.

## Build and signing

Using the established local toolchain:

- build the signed HAP;
- verify app signature and profile;
- record bundle name, HAP path, size, and SHA-256;
- diagnose build/signing failures and continue other available review work;
- do not alter credentials or phone settings to force a pass.

## Physical-device validation

Use the connected physical device only when available. Operations are limited
to the application:

- install the verified HAP with replacement;
- run complete platform, tenant, delegated tenant, and member journeys;
- cover list/detail/editor/action/return behavior for corrected domains;
- verify two-tenant isolation and shared tenant-admin state;
- verify Demo HTTP, WebSocket, and MQTT attempt counts remain zero;
- inspect application PID logs for app-authored error/fatal and crash
  signatures;
- do not read or change device system settings.

Real backend integration is a separate follow-up when backend routes are ready.

## Audit A

Perform a full code-review pass ordered by severity, run static checks, tests,
build/signing verification, and current app-scoped device journeys. Any
behavioral defect, unsupported visible Real action, missing page contract, or
architecture regression is a finding and returns work to the owning stage.

## Audit B

After Audit A is clean, start a fresh review from the page registry and API
catalog. Re-run the full automated suite and the critical physical-device
journeys using the same verified HAP produced from the reviewed source.

If Audit B finds an issue, repair it in the owning stage and restart both final
audits. The overall remediation passes only when final Audit A and the
immediately following final Audit B both have zero findings.

## Publication boundary

Do not stage, commit, or push during this plan unless the user separately
authorizes publication after the two clean final audits.
