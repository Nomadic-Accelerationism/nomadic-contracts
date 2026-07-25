# ENSv2 Sepolia Readiness

## Current limitation

* No Sepolia state-changing transactions have been broadcast in this slice.
* Parent ownership remains unresolved — do not assume `nomadic.eth` or any specific parent.
* World eligibility remains an offchain backend responsibility.
* This slice proves hierarchy + permission model locally and verifies deployment addresses read-only.

## Read-only scripts

```bash
# Deployment verification (requires SEPOLIA_RPC_URL)
forge script script/ensv2/00_VerifyDeployment.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" -vvv

# Parent inspection (requires SEPOLIA_RPC_URL + ENSV2_PARENT_NAME)
forge script script/ensv2/01_InspectParent.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" -vvv
```

Planning simulations (local, no RPC required):

```bash
forge script script/ensv2/02_PlanPassport.s.sol -vvv
forge script script/ensv2/03_PlanCredential.s.sol -vvv
forge script script/ensv2/04_PlanIssuerPermissions.s.sol -vvv
```

`ENSV2_BROADCAST` must remain `false`. Scripts reject broadcast in this slice.

## Environment

See `.env.example`. No private key is required for this scaffold. Every script now requires an
explicit `ENSV2_DEPLOYMENT_PROFILE`; see
[`ENSV2_DEPLOYMENT_PROFILES.md`](./ENSV2_DEPLOYMENT_PROFILES.md).

## Parent-name blocker

Before any real Sepolia write:

1. Obtain/control a parent name under ENSv2 Sepolia.
2. Ensure platform has `ROLE_REGISTRAR` on the parent registry where Passports will be created.
3. Run `01_InspectParent.s.sol` until `parentSuitableForPrototype=true`.

## Ordered transaction plan for the next slice

1. Re-run `00_VerifyDeployment` on the pinned addresses.
2. Confirm parent suitability via `01_InspectParent`.
3. Deploy Passport `UserRegistry` proxy via Sepolia `VerifiableFactory` + `UserRegistryImpl`.
4. Deploy Passport `PermissionedResolver` proxy via Sepolia `PermissionedResolverImpl`.
5. `ParentRegistry.register(passportLabel, user, passportRegistry, resolver, ownerRoles, expiry)`.
6. `PassportRegistry.setParent(parentRegistry, passportLabel)` as user.
7. Seed Passport records (`addr` + Nomadic text schema) as user.
8. Register credential child in Passport registry as user.
9. Seed credential records as user; update Passport `com.nomadic.credentials`.
10. `authorizeTextRoles` for issuer allowlist as user.
11. Explicitly confirm platform retained no Passport registry root roles.

Only then enable an explicit broadcast path with chain-id checks and key management.

## Safe to prepare real Sepolia broadcasts?

**Preflight complete; broadcast still blocked.** See:

* [`ENSV2_SEPOLIA_PREFLIGHT.md`](./ENSV2_SEPOLIA_PREFLIGHT.md)
* [`ENSV2_PASSPORT_ISSUANCE_PLAN.md`](./ENSV2_PASSPORT_ISSUANCE_PLAN.md)
* [`ENSV2_PERMISSION_DEMO_PLAN.md`](./ENSV2_PERMISSION_DEMO_PLAN.md)

`nomadic-passport.eth` is available. Do not broadcast until operators set real signer addresses, fund MockUSDC + Sepolia ETH, and run a dedicated broadcast script with `ENSV2_BROADCAST` explicitly enabled.
