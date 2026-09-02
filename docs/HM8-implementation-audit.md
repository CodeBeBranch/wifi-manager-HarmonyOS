# HM-8 implementation audit

## Scope

HM-8A closes the HarmonyOS Demo implementation defined by the 07 phased plan
and the 08 page registry. HM-8B Real integration remains `REAL_PENDING` and is
not part of this closeout.

- 122 logical registry entries are represented by 116 unique routable ArkTS
  pages plus the shared root/content/config components used by multiple entries.
- All 116 page registrations are unique and resolve to existing files.
- All 115 static `pages/*` route references resolve to registered pages.

## Implementation closeout

- Symbol-only navigation and creation controls have explicit accessibility
  labels.
- Interactive buttons use explicit touch heights of at least 44vp. Adjacent
  segmented controls use at least 8vp spacing, and their containers no longer
  clip 44vp children.
- No page uses a fixed width wider than the 375vp content boundary.
- The UI has no app-authored animation API, so reduced-motion mode does not
  leave an independent animation path active.
- `DemoHm7CapabilityRepository.reset()` now restores the `NORMAL` scenario as
  well as deterministic records and sequences.
- HM-7 `PARTIAL_FAILURE` remains local to AI review with a 502
  `HM7_AI_PARTIAL_FAILURE`; unrelated HM-7 capabilities stay available.
- `tools/hm1-device-audit.ps1 -Hm8Only` composes the existing HM-2 through HM-7
  journeys without weakening their assertions and adds foreground-resume
  verification.

## Automated evidence

Run date: 2026-09-01.

- Full ArkTS suite: 93 run, 93 pass, 0 failure, 0 error, 0 ignored.
- Signed `assembleHap`: `BUILD SUCCESSFUL` with DevEco JBR 21.0.8.
- `verify-app`: Signing Block v3, code signature, SHA-256 digest, and
  certificate chain verified.
- `verify-profile`: `verifiedPassed=true`, profile type `debug`.
- Bundle name: `com.plagod.WiFiEdgeManager`.
- Signed HAP: 4,112,354 bytes.
- Signed HAP SHA-256:
  `0851AA6E302BBA9C71A867B00FFBC76901D071CD93984E20E4C07EF552276EB9`.

## Device evidence

The verified HAP was installed with `hdc install -r` on the only connected USB
device `88X9K26526081036`. No uninstall, app-data clear, device reset, or system
setting change was performed.

One complete `hm1-device-audit.ps1 -Hm8Only` run passed 211 checks:

- cold start, force-stop restore, foreground/background resume, and upgrade
  installation;
- super administrator, tenant administrator, and member account journeys;
- HM-2 through HM-7 registered Demo workflows and deterministic reset;
- 401/403-style authorization, 409 conflict, 429 rate limit, local 502 partial
  failure, and 503 dependency states covered by the existing scenario journeys
  and unit contracts;
- platform/tenant/member and cross-tenant isolation boundaries;
- zero Demo HTTP, WebSocket, and MQTT attempts throughout the journeys;
- no app-authored ERROR/FATAL or crash signature in the observed application
  PIDs.

## Static review

- 122 registry entries, 116 unique profile pages, and zero missing page files.
- 115 discovered static route references, zero unregistered route references.
- Zero explicit button heights below 44vp.
- Zero clickable buttons without an explicit height.
- Zero unlabeled symbol-only buttons.
- Zero fixed page widths above the 375vp content boundary.
- The only remaining row spacing below 8vp is the non-interactive map grid in
  `TenantGisPage`.
- No password, token, cookie, authorization, SSID, or secret is written by
  application `hilog` or console calls.
- Demo HM-7 has no HTTP, WebSocket, or MQTT dependency. RepositoryFactory keeps
  Demo selection separate and retains Real `REAL_API_PENDING` branches.
- `git diff --check` passes; only repository line-ending warnings remain.
- The PowerShell device script parses without errors.

## Accessibility evidence

- At the system `Extra large` font setting, the login page reflowed into its
  existing scroll container without horizontal overflow or overlapping text.
- With the software keyboard open at that font size, the focused username
  field remained fully visible above the keyboard. Its visible bounds were
  `[81,1350][1084,1502]` inside the resized application viewport
  `[81,129][1152,1530]`.
- The system accessibility semantic tree exposed the login controls in visual
  order, and the screen reader recognized the first application text node with
  a visible focus indicator. Symbol-only application buttons already carry
  explicit accessibility labels.
- The device owner restored the temporary font and accessibility settings.
  Future verification is restricted to application-scoped operations and must
  not read or change device system settings.

## Remaining gaps

- HM-8B live HTTPS, Cookie, WebSocket, Gateway, real tenant isolation, real
  ESP32, and production-environment verification remain `REAL_PENDING`.

## HM-8B client contract preparation

Run date: 2026-09-01.

The backend services and environments exist, but they are not yet stable enough
for full end-to-end integration. Client work therefore proceeded contract-first
without claiming live integration:

- HM-5 now has real wire DTOs and Repository calls for products, member
  entitlement, purchases, usage logs, orders, payments, refunds, refund review,
  location consent, and owned location history.
- Product codes, order numbers, payment numbers, refund numbers, and purchase
  IDs remain string business identifiers from the backend. The client no longer
  fabricates numeric IDs for those domains.
- Backend cent amounts and duration entitlements are mapped explicitly. HM-5
  pages display a duration/quota label instead of assuming every real
  entitlement is measured in gigabytes.
- HM-6 now has real mappings and calls for tenant location records and circular
  geofence list/detail/create/update/toggle/delete/event flows.
- HM-6 track, stay, heat-map, GIS aggregate, and analytics methods remain
  capability-local `REAL_API_PENDING` because their backend queries do not yet
  provide the required tenant boundary.
- HM-7 has an explicit per-capability Real route table. Entitlement delegates to
  HM-5; audit is marked `TENANT_BOUNDARY_PENDING`; Marketplace, Support, and AI
  are marked `PUBLIC_API_PENDING` because their service and persistence layers
  exist but stable public Controllers and Gateway routes are not yet available.
- Demo and Real selection remains in `RepositoryFactory`; no Real error falls
  back to Demo data.

### Unified Real API catalog

The replaceable integration contract is maintained outside the application
repository at:

`F:\MyProject\summary\wifi-manager-HarmonyOS\15-harmony-real-api-catalog.json`

The catalog is the single source for the Gateway origin, alert WebSocket path,
service-port reference, and public API paths. It currently contains 10 services
and 124 endpoint records:

- `CURRENT`: 82 source-proven public contracts.
- `PARTIAL`: 12 public contracts with a known capability limitation.
- `PREDICTED`: 30 replaceable defaults for backend surfaces that are not yet
  stable.
- Duplicate keys: 0.
- `/internal/**` paths exposed to the mobile client: 0.
- Catalog SHA-256:
  `ABFE437F99A2FA06272B63F30F09F0D7FDFAAF5EFD25F0F6E49216DCBE9FD117`.

`tools/sync-real-api-catalog.ps1` validates and generates
`entry/src/main/ets/config/RealApiCatalog.ets`. Real repositories use generated
keys instead of embedding endpoint strings. When backend contracts stabilize,
update the external catalog and run the sync script; Repository code only needs
changes when the wire schema or capability semantics change.

Verification for this contract-preparation change:

- Full ArkTS suite: 100 run, 100 pass, 0 failure, 0 error, 0 ignored.
- Signed `assembleHap`: `BUILD SUCCESSFUL` with DevEco JBR 21.0.8.
- `verify-app`: HAP Signing Block v3, code signature, and SHA-256 digest passed.
- `verify-profile`: `verifiedPassed=true`, profile type `debug`, bundleName
  `com.plagod.WiFiEdgeManager`.
- Signed HAP: 4,165,969 bytes.
- Signed HAP SHA-256:
  `5B7A002E66466C4BEE1091303B3770651C50B4576C05C77610B159E7A3142378`.
- No backend, Gateway, ESP32, or device integration run was performed.
- No device system setting was read or changed.
