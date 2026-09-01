# HM-7 implementation audit

## Scope

HM-7 implements the 50 registered Demo pages for SaaS lifecycle and quota,
Marketplace, announcements and comments, Support and messages, AI review,
platform runtime recovery, organization membership, and read-only audit.

- Platform: P108, P111-P120, P122-P131, P133.
- Tenant: P213-P218, P220-P222, P233, P235-P241.
- Member: P310-P313, P320-P326.

All 50 page IDs have one configuration and one page entry. All page entries and
all discovered route targets are registered exactly once in `main_pages.json`
and resolve to existing ArkTS files.

## Implementation

- `DemoHm7CapabilityRepository` provides deterministic, tenant- and
  member-isolated local data, search and status filtering, edits, confirmed
  actions, scenario errors, request IDs, and reset behavior.
- `RealHm7CapabilityRepository` remains a separate `REAL_API_PENDING`
  implementation until the public contracts exist.
- `RepositoryFactory` selects Demo or Real HM-7 repositories from the runtime
  mode and propagates scenario/reset changes without replacing existing HTTP,
  session, `ApiError`, WebSocket, or MQTT architecture.
- Platform, tenant, and member service roots expose the corresponding HM-7
  journeys. Platform-managed tenant details expose P108 account entitlement.
- Platform delegates can write only P108 entitlement Demo data. Other tenant
  plan capabilities remain read-only for delegated platform access.

## Automated evidence

- Full ArkTS suite: 92 run, 92 pass, 0 failure, 0 error, 0 ignored.
- Signed `assembleHap`: successful with DevEco JBR 21.0.8 after placing its
  `bin` directory first in the process `PATH`.
- `verify-app`: Signing Block v3, code signature, certificate chain, and
  SHA-256 digest verified.
- `verify-profile`: `verifiedPassed=true`, profile type `debug`.
- Bundle name: `com.plagod.WiFiEdgeManager`.
- Signed HAP: 4,095,271 bytes.
- Signed HAP SHA-256:
  `E248BA5370D92618AC4C7ED5A91C67996FF97BB0F462D5D3671EF7E4F41D59BE`.

## Device evidence

The verified HAP was installed with `hdc install -r` on the only connected USB
device `88X9K26526081036`. One complete `hm1-device-audit.ps1 -Hm7Only` run
passed 34 checks:

- Super administrator: Marketplace list/detail, AI review confirmation,
  runtime recovery confirmation, and read-only audit.
- Tenant administrator: organization/member/invitation links, subscription and
  quota, announcement creation and deterministic reset, and Support action.
- Member: Marketplace purchase, Support creation, and message read action.
- All three journeys reported zero Demo network attempts.
- The final application PID had no app-authored ERROR/FATAL or crash signature.

## Static review

- 50 expected HM-7 IDs, 50 unique configs, and 50 unique page wrappers match.
- 116 total registered page entries are unique.
- All 52 discovered navigation targets exist and are registered.
- `git diff --check` passes; only repository line-ending warnings remain.
- The PowerShell device script parses without errors.
- Demo HM-7 code has no HTTP, WebSocket, or MQTT dependency.

## Remaining gaps

- Public Real Repository contracts and real Gateway integration are still
  `REAL_API_PENDING`.
- Real payment, production service calls, and Real device integration were not
  added or exercised by HM-7.
- This HM-7 snapshot predates delivery closeout; current HM-8 evidence is
  recorded in `docs/HM8-implementation-audit.md`.
