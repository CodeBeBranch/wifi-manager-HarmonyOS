# Stage 5: Real mode and API coverage

## Goal

Make Real mode truthful. Connect every source-proven CURRENT API that has a
valid mobile-client use case, hide unsupported pages, and keep PARTIAL or
PREDICTED capabilities explicit without Demo fallback.

## Source of truth

- API catalog:
  `F:\MyProject\summary\wifi-manager-HarmonyOS\15-harmony-real-api-catalog.json`
- Capability matrix:
  `F:\MyProject\summary\wifi-manager-HarmonyOS\03-current-api-and-domain-capability-matrix.md`
- Page visibility:
  `F:\MyProject\summary\wifi-manager-HarmonyOS\08-harmonyos-demo-page-registry.md`
- Runtime integration values:
  `F:\MyProject\summary\wifi-manager-HarmonyOS\16-harmony-real-runtime-config.json`

Stage 5 creates the runtime integration file if it does not exist. Its minimum
schema is:

```json
{
  "schemaVersion": 1,
  "payment": {
    "enabled": false,
    "channel": ""
  }
}
```

The synchronization tool validates this file and generates
`entry/src/main/ets/config/RealRuntimeConfig.ets` as UTF-8 source. Generated
source is not manually edited. `RuntimeConfig.ets` exposes the validated values
to repositories and pages.

At planning time, executable client source references 47 of 82 CURRENT catalog
keys. The following 35 CURRENT keys need connection or an explicit,
source-proven non-exposure decision.

## CURRENT backlog

Authentication and workspace:

- `auth.stepUp`
- `auth.operationToken`
- `auth.accountSwitch`
- `auth.accountSwitchCodes`
- `auth.oauthProviders`
- `workspace.mine`
- `workspace.current`
- `workspace.switchTenant`

Platform organization:

- `platform.tenantDetail`
- `platform.tenantStatus`
- `platform.tenantMembers`
- `platform.saasPlans`

Profile and platform users:

- `users.self`
- `users.avatar`
- `users.purgeRequest`
- `users.socialIdentities`
- `users.socialIdentityDelete`
- `admin.users`
- `admin.userStats`
- `admin.userDetail`
- `admin.userStatus`

Commerce and device:

- `entitlements.paymentDetail`
- `devices.restore`
- `devices.allow`
- `devices.blacklistDelete`

Session, traffic, and signal:

- `sessions.portalAuthorize`
- `sessions.portalStatus`
- `traffic.mine`
- `traffic.admin`
- `signals.mine`
- `signals.admin`

Location and analytics:

- `locations.report`
- `analytics.signals`
- `analytics.traffic`
- `gis.coverage`

## Required implementation

1. Connect CURRENT keys through domain repositories and wire DTO mappings.
2. If a CURRENT endpoint cannot safely power a registered mobile page, record a
   concrete source-level reason and keep that action hidden. Do not replace it
   with Demo behavior.
3. Real page visibility is computed from actual capability status:
   - registry `PROD_HIDDEN` always remains hidden, even when an endpoint is
     `CURRENT`;
   - registry `PROD_READY` is visible only when every required action is backed
     by a safe executable `CURRENT` contract;
   - a `PARTIAL` capability is visible only when the registry permits it and
     the page exposes only the explicitly supported subset;
   - `PREDICTED`, `PLANNED`, and unsafe capabilities remain hidden;
   - changing a registry publish status is a separate product-scope decision,
     not an implementation side effect.
4. Remove visible Real pages that only throw `REAL_API_PENDING`.
5. Payment channel comes from `RuntimeConfig` backed by the external Real
   runtime configuration above. Real mode defaults to payment disabled when the
   file is absent, invalid, disabled, or has an empty channel. Do not hardcode
   `LOCAL_DEMO`, infer a channel from catalog routes, or show Demo payment copy
   in Real mode.
6. Preserve the catalog as the endpoint-string source. Repositories own wire
   schema and behavior, not duplicated literal paths.
7. Never call `/internal/**` from the mobile client.
8. Preserve security rules for Cookie/JWT/session context, tenant switching,
   operation tokens, sensitive fields, and unified `ApiError`.

## Tests

Add contract tests for:

- all connected CURRENT catalog keys and method/path parameter mapping;
- workspace and account switch state;
- profile and platform tenant/user DTO mapping;
- payment detail and runtime-configured channels;
- Portal, traffic, signal, location report, and analytics mapping;
- Real visibility for CURRENT/PARTIAL/PREDICTED pages;
- precedence tests where a CURRENT endpoint belongs to a `PROD_HIDDEN` page;
- fail-closed payment behavior when no Real channel is configured;
- no Demo fallback and no `/internal/**` route;
- safe handling of 401, 403, 404, 409, 429, 502, and 503.

Live backend availability is not required to finish client contracts. Static
wire tests and fake HTTP responses must prove the client behavior until the
backend is ready for end-to-end integration.

## Audit A

Recompute CURRENT key coverage from the catalog and executable source, inspect
all uncovered keys, review Real navigation visibility, and run wire-contract
tests. Search for literal API paths, `LOCAL_DEMO`, `/internal/`, and Demo
fallback.

## Audit B

Recompute coverage independently from the persisted catalog. Navigate Real mode
from each role and verify that every visible action has a non-Demo execution
path. Recheck registry/API intersection, payment, and tenant context behavior.

The stage passes only after two consecutive zero-finding audits. A documented
non-exposure decision counts as covered only when the page/action is hidden and
the reason is supported by current backend source.
