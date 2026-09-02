# Stage 4: production domain naming

## Goal

Remove delivery-stage identifiers from production ArkTS filenames, symbols,
repository contracts, errors, and shared page abstractions. Historical plans,
audit reports, and device journey labels may retain HM identifiers.

## Target structure

The target ownership is fixed below. Existing domain files may receive the
symbols when they already match the target path; otherwise create the named
file.

| Current symbols | Required target |
| --- | --- |
| `AppNotice`, `unreadNoticeCount` | `model/NoticeModels.ets` |
| `UserProfile`, `SocialIdentity`, profile portion of `DemoAccountState` | `model/ProfileModels.ets` |
| `SecuritySession` | existing `model/SessionModels.ets` |
| notice/session portions of `DemoAccountState` | owning Demo repositories; delete the mixed state type |
| `PlatformSummary` | `model/PlatformOverviewModels.ets` |
| `TenantCreateInput`, `TenantUpdateInput`, `PlatformTenantMember`, `PlatformTenantDetailParams` | existing `model/TenantModels.ets` |
| `PlatformAccount`, `PlatformAccountPage`, `AccountDeleteReview`, `AccountReviewPage`, account/review params | `model/AccountGovernanceModels.ets` |
| `SaasPlan`, `SaasPlanPage`, `SaasPlanDetailParams` | `model/SubscriptionModels.ets` |
| `Hm2DemoState` | split into organization, account-governance, and subscription Demo stores; delete the mixed state type |
| `BlacklistEntry`, `BlacklistQuery` | `model/SecurityModels.ets` |
| `DeviceSignalRecord`, `DeviceTrafficPoint` | `model/NetworkTelemetryModels.ets` |
| `DeviceEditInput` | existing `model/DeviceModels.ets` |
| `TenantAlertRule`, `AlertAnalytics`, `DemoAlertConnection`, `AlertHandleResult`, `AlertRuleInput` | existing `model/AlertModels.ets` |
| `TenantAuditRecord` | `model/AuditModels.ets` |
| `MemberSummary` | `model/MemberModels.ets` |
| entitlement/product/purchase/usage symbols | `model/EntitlementModels.ets` |
| order status and order symbols | `model/OrderModels.ets` |
| payment status and payment symbols | `model/PaymentModels.ets` |
| refund status and refund symbols | `model/RefundModels.ets` |
| member location permission/history symbols | `model/LocationPrivacyModels.ets` |
| map/location/track/stay/heat/coverage symbols | `model/LocationModels.ets` |
| geofence shape/event and geofence symbols | `model/GeofenceModels.ets` |
| signal/traffic insight and analytics snapshot symbols | `model/AnalyticsModels.ets` |
| all `Hm*DemoScenario` types | `model/DemoScenario.ets` as one shared `DemoScenario` union |
| all `Hm7*` models | domain models created in stages 2 and 3; delete `Hm7Models.ets` |

Repository targets are also fixed:

| Current repository boundary | Required target repositories/factory accessors |
| --- | --- |
| `Hm4SecurityRepository` | `SecurityRepository` and existing `AlertRepository`; accessors `security()` and `alert()` |
| `Hm5MemberRepository` | `EntitlementRepository`, `OrderRepository`, `PaymentRepository`, `RefundRepository`, `MemberLocationRepository`; accessors use the same domain names |
| `Hm6LocationRepository` | `LocationRepository`, `GeofenceRepository`, `AnalyticsRepository`; accessors `location()`, `geofence()`, `analytics()` |
| `Hm7CapabilityRepository` | organization, membership, subscription, Marketplace, content, support, notice, AI review, runtime, and audit repositories created in stages 2 and 3 |
| `Hm7FeaturePage` / `Hm7PageConfigs` | domain components/configuration created in stages 2 and 3; old files deleted |

No `PlatformModels`, `MemberRepository`, `DomainModels`, or
`CapabilityRepository` catch-all may replace the old phase containers.

## Exact exported-symbol disposition

The following inventory is normative. A slash-separated target means the
source container must be split; it does not permit retaining a facade.

| Source exports | Disposition |
| --- | --- |
| `AppNotice`, `unreadNoticeCount` | move to `NoticeModels.ets`; rename `AppNotice` to `UserNotice` |
| `UserProfile`, `SocialIdentity` | move unchanged to `ProfileModels.ets` |
| `SecuritySession` | move unchanged to `SessionModels.ets` |
| `DemoAccountState` | delete after its fields move to notice/profile/session Demo stores |
| `Hm2DemoScenario`, `Hm3DemoScenario`, `Hm4DemoScenario` | replace with `DemoScenario` from `DemoScenario.ets` |
| `PlatformSummary` | move unchanged to `PlatformOverviewModels.ets` |
| `TenantCreateInput`, `TenantUpdateInput`, `PlatformTenantMember`, `PlatformTenantDetailParams` | move unchanged to `TenantModels.ets` |
| `PlatformAccount`, `PlatformAccountPage`, `AccountDeleteReview`, `AccountReviewPage`, `PlatformAccountDetailParams`, `PlatformReviewDetailParams` | move unchanged to `AccountGovernanceModels.ets` |
| `SaasPlan`, `SaasPlanPage`, `SaasPlanDetailParams` | move unchanged to `SubscriptionModels.ets` |
| `Hm2DemoState` | delete after fields/sequences move to their three owning Demo stores |
| `BlacklistEntry`, `BlacklistQuery` | move unchanged to `SecurityModels.ets` |
| `DeviceSignalRecord`, `DeviceTrafficPoint` | move unchanged to `NetworkTelemetryModels.ets` |
| `DeviceEditInput` | move unchanged to `DeviceModels.ets` |
| `TenantAlertRule`, `AlertAnalytics`, `DemoAlertConnection`, `AlertHandleResult`, `AlertRuleInput` | move unchanged to `AlertModels.ets` |
| `TenantAuditRecord` | move to `AuditModels.ets`; rename to `AuditRecord` |
| `Hm5OrderStatus`, `MemberOrder` | move to `OrderModels.ets`; rename status to `OrderStatus` |
| `Hm5PaymentStatus`, `MemberPayment` | move to `PaymentModels.ets`; rename status to `PaymentStatus` |
| `Hm5RefundStatus`, `MemberRefund` | move to `RefundModels.ets`; rename status to `RefundStatus` |
| `MemberSummary` | move unchanged to `MemberModels.ets` |
| `MemberEntitlement`, `MemberProduct`, `MemberPurchase`, `MemberUsageRecord` | move unchanged to `EntitlementModels.ets` |
| `MemberLocationPermission`, `MemberLocationRecord` | move unchanged to `LocationPrivacyModels.ets` |
| `Hm6MapState`, `Hm6GisMode` | move to `LocationModels.ets`; rename to `MapState`, `GisMode` |
| `TenantLocation`, `TenantTrackPoint`, `TenantStayPoint`, `TenantHeatPoint`, `TenantCoverageNode`, `TenantGisSnapshot` | move unchanged to `LocationModels.ets` |
| `Hm6GeofenceShape`, `Hm6GeofenceEventType` | move to `GeofenceModels.ets`; rename to `GeofenceShape`, `GeofenceEventType` |
| `TenantGeofence`, `TenantGeofenceInput`, `TenantGeofenceEvent` | move unchanged to `GeofenceModels.ets` |
| `TenantSignalInsight`, `TenantTrafficInsight`, `TenantAnalyticsSnapshot` | move unchanged to `AnalyticsModels.ets` |
| `Hm7Capability`, `Hm7Scope`, `Hm7PageMode`, `Hm7RequestContext`, `Hm7Record`, `Hm7RecordInput`, `Hm7ActionResult`, `Hm7PageConfig` | delete; use the explicit domain models and page contracts from stages 2 and 3 |
| `DemoHm4SecurityRepository`, `RealHm4SecurityRepository` | move/rename to `DemoSecurityRepository`, `RealSecurityRepository` in `SecurityRepository.ets` |
| `Hm5PageWire`, `Hm6PageWire` | replace with one `PageWire<T>` in `ApiModels.ets` |
| `EntitlementWire`, `ProductWire`, `PurchaseWire`, `UsageWire`, `mapHm5Entitlement`, `mapHm5Product`, `mapHm5Purchase`, `mapHm5Usage` | move to `EntitlementRepository.ets`; remove `Hm5` from mapper names |
| `OrderWire`, `mapHm5Order` | move to `OrderRepository.ets`; rename mapper to `mapOrder` |
| `PaymentWire`, `mapHm5Payment` | move to `PaymentRepository.ets`; rename mapper to `mapPayment` |
| `RefundWire`, `mapHm5Refund` | move to `RefundRepository.ets`; rename mapper to `mapRefund` |
| `LocationAuthorizationWire`, `LocationWire`, `mapHm5LocationPermission`, `mapHm5Location` | move to `MemberLocationRepository.ets`; rename mappers to `mapLocationPermission`, `mapMemberLocation` |
| `DemoHm5MemberRepository`, `RealHm5MemberRepository` | delete after methods/state are distributed to entitlement, order, payment, refund, and member-location repositories |
| `TenantLocationWire`, `mapHm6Location` | move to `LocationRepository.ets`; rename mapper to `mapTenantLocation` |
| `GeofenceWire`, `GeofenceEventWire`, `mapHm6Geofence`, `mapHm6GeofenceEvent` | move to `GeofenceRepository.ets`; remove `Hm6` from mapper names |
| `DemoHm6LocationRepository`, `RealHm6LocationRepository` | delete after methods/state are distributed to location, geofence, and analytics repositories |
| `Hm7CapabilityRepositoryContract`, `DemoHm7CapabilityRepository`, `RealHm7CapabilityRepository` | delete after all callers use stage-2/3 domain repositories |
| `Hm7RealRouteState`, `Hm7RealCapabilityRoute`, `realHm7CapabilityRoute` | delete; Real visibility and route availability come from the registry/API policy in stage 5 |

## Error, storage, and request identifiers

The phase cleanup applies to all production identifiers and literals, not only
exports.

| Current identifier | Required disposition |
| --- | --- |
| `HM2_DEMO_STATE_KEY` / `demo_platform_hm2_state_v1` | replace with `PLATFORM_DEMO_STATE_KEY` / `demo_platform_state_v2`; old Demo state may reset and is not migrated |
| `HM4_SCENARIO_FORBIDDEN` | `SECURITY_SCENARIO_FORBIDDEN` |
| `HM4_SCENARIO_RATE_LIMITED` | `SECURITY_SCENARIO_RATE_LIMITED` |
| `HM4_SCENARIO_DEPENDENCY_DOWN` | `SECURITY_SCENARIO_DEPENDENCY_DOWN` |
| `HM5_SCENARIO_FORBIDDEN` | owning commerce or member-location repository uses `<DOMAIN>_SCENARIO_FORBIDDEN` |
| `HM5_SCENARIO_RATE_LIMITED` | owning repository uses `<DOMAIN>_SCENARIO_RATE_LIMITED` |
| `HM5_SCENARIO_DEPENDENCY_DOWN` | owning repository uses `<DOMAIN>_SCENARIO_DEPENDENCY_DOWN` |
| `HM5_WRITE_FORBIDDEN` | owning repository uses `<DOMAIN>_WRITE_FORBIDDEN` |
| `HM5_SCENARIO_CONFLICT` | owning repository uses `<DOMAIN>_SCENARIO_CONFLICT` |
| `HM6_SCENARIO_FORBIDDEN` | location, geofence, or analytics repository uses `<DOMAIN>_SCENARIO_FORBIDDEN` |
| `HM6_SCENARIO_RATE_LIMITED` | owning repository uses `<DOMAIN>_SCENARIO_RATE_LIMITED` |
| `HM6_SCENARIO_DEPENDENCY_DOWN` | owning repository uses `<DOMAIN>_SCENARIO_DEPENDENCY_DOWN` |
| `HM7_PLATFORM_FORBIDDEN` | `PLATFORM_ACCESS_FORBIDDEN` |
| `HM7_TENANT_FORBIDDEN` | `TENANT_ACCESS_FORBIDDEN` |
| `HM7_MEMBER_FORBIDDEN` | `MEMBER_ACCESS_FORBIDDEN` |
| `HM7_AI_PARTIAL_FAILURE` | `AI_REVIEW_PARTIAL_FAILURE` |
| `HM7_SCENARIO_FORBIDDEN` | owning stage-2/3 repository uses `<DOMAIN>_SCENARIO_FORBIDDEN` |
| `HM7_SCENARIO_RATE_LIMITED` | owning repository uses `<DOMAIN>_SCENARIO_RATE_LIMITED` |
| `HM7_SCENARIO_DEPENDENCY_DOWN` | owning repository uses `<DOMAIN>_SCENARIO_DEPENDENCY_DOWN` |
| `HM7_SCENARIO_CONFLICT` | owning repository uses `<DOMAIN>_SCENARIO_CONFLICT` |
| `HM7_RECORD_NOT_FOUND` | owning repository uses `<ENTITY>_NOT_FOUND` |
| `HM7_TITLE_REQUIRED` | Marketplace, announcement, or support input uses its explicit validation key |
| `HM7-<sequence>` request IDs | use domain prefixes: `ORG`, `MEM`, `SUB`, `MKT`, `CNT`, `SUP`, `AIR`, `RUN`, or `NOT` |

`<DOMAIN>` is restricted to `ENTITLEMENT`, `ORDER`, `PAYMENT`, `REFUND`,
`MEMBER_LOCATION`, `LOCATION`, `GEOFENCE`, `ANALYTICS`, `ORGANIZATION`,
`MEMBERSHIP`, `SUBSCRIPTION`, `MARKETPLACE`, `CONTENT`, `SUPPORT`, `AI_REVIEW`,
`RUNTIME`, `AUDIT`, or `NOTICE`. `<ENTITY>` is the concrete aggregate name from
the ownership tables in stages 2 and 3. No generic `CAPABILITY_*` replacement
is allowed.

## Required implementation

1. Rename remaining phase-prefixed symbols such as `Hm3DemoScenario`,
   `Hm5OrderStatus`, mapper functions, page configs, and repository classes.
2. Replace phase-prefixed error keys with stable domain keys, for example:
   - authentication and account;
   - tenant and workspace;
   - security and alert;
   - commerce;
   - location;
   - marketplace, content, support, AI, runtime, and audit.
3. Update RepositoryFactory to expose domain repositories. Demo/Real selection
   remains explicit and Real never falls back to Demo.
4. Remove generic phase page wrappers once their page IDs are backed by the
   domain components from stages 2 and 3.
5. Update tests, imports, scenario reset wiring, and app-scoped device scripts
   to use domain names.
6. Keep migration behavior stable. This is an architectural rename and split,
   not permission to drop page actions or error scenarios.
7. Produce a before/after symbol inventory from the tables above. Every export
   from `Hm1Models` through `Hm7Models` and each phase repository must have
   exactly one target or an explicit deletion reason.

## Acceptance scans

Production source under `entry/src/main/ets` must have no filename, import path,
exported or private identifier, class, interface, type, function, field,
storage key, request ID prefix, error key, or shared contract containing a
case-insensitive phase identity `hm1` through `hm8`.

Allowed exceptions:

- user-facing historical audit text outside production source;
- test descriptions that explicitly verify migration compatibility;
- device-script labels that refer to the historical delivery journey.

All imports must resolve, RepositoryFactory must have one Demo/Real decision per
domain, and no compatibility facade may route new code through the old generic
HM-7 repository.

## Audit A

Run identifier scans, compile/type checks, focused domain tests, and a manual
RepositoryFactory review. Confirm that renamed error keys preserve status,
retryability, and user-safe messages.

## Audit B

Review production source by domain directory and import graph. Search again for
phase identifiers and inspect any exception manually. Re-run the affected tests
from a clean process.

The stage passes only after two consecutive zero-finding audits.
