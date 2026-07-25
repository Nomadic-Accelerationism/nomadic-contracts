# ENSv2 Passport Issuance Plan (Sepolia)

Simulation-backed transaction plan for:

```text
nomadic-passport.eth
└── victor.nomadic-passport.eth
    └── lisbon-house.victor.nomadic-passport.eth
```

Source of truth: pinned ENSv2 `48b3e2d39513b9dd32ef1850877a29009bc807b9` + live Sepolia fork simulation.
**Do not broadcast from this document alone.**

## Actors

| Env var | Role |
| --- | --- |
| `NOMADIC_PARENT_OWNER_ADDRESS` | Platform |
| `PASSPORT_OWNER_ADDRESS` | Magic wallet / Passport user |
| `LISBON_HOUSE_ISSUER_ADDRESS` | Lisbon House issuer |

## Contracts (Sepolia)

| Name | Address |
| --- | --- |
| VerifiableFactory | `0x118Bc31A50d559F7015a8Da26d54B3b030CdB70F` |
| UserRegistryImpl | `0x840Fa461059862Ea466A711E8C98c8dE732061C0` |
| PermissionedResolverImpl | `0x7E4B2d59938930168024201752EE5503df402303` |
| ETHRegistrar | `0xa4449a0dD2b83007553D9b1d28b583A46A805a30` |
| ETHRegistry | `0x67b728a792e789a8978b30cF1b3b641f19354b43` |
| MockUSDC | `0xD3322B29a7BdEe707D1684676f149bf41Aa3422f` |
| UniversalResolverV2 | `0x85eDf8B6b7D4211e2b07AA687506B746357B92cf` |

Parent / Passport UserRegistry and PermissionedResolver addresses are **CREATE2 proxies** from VerifiableFactory (salts chosen by operator).

## Stage A — Acquire parent `nomadic-passport.eth`

**Signer:** platform

| # | Target | Call | Key args | Ownership after |
| --- | --- | --- | --- | --- |
| A1 | VerifiableFactory | `deployProxy(UserRegistryImpl, salt, init)` | `initialize(platform, ROLE_REGISTRAR\|ADMIN + SET_PARENT\|ADMIN + UPGRADE\|ADMIN)` | Parent UserRegistry admin = platform |
| A2 | VerifiableFactory | `deployProxy(PermissionedResolverImpl, salt, init)` | `initialize(platform, ALL_ROLES, [])` | Parent resolver admin = platform |
| A3 | ETHRegistrar | `commit(commitment)` | `makeCommitment(label, platform, secret, parentRegistry, parentResolver, duration, referrer)` | — |
| A4 | (wait) | — | ≥ `MIN_COMMITMENT_AGE` + 1s (61s) | — |
| A5 | MockUSDC | `mint` / `approve` | amount = `getRegisterPrice(...)` (~8e6 for 1y) | — |
| A6 | ETHRegistrar | `register(...)` | same commitment fields + payment token | **Parent name owner = platform**; subregistry + resolver attached |
| A7 | Parent UserRegistry | `setParent(ETHRegistry, "nomadic-passport")` | — | Canonical parent linkage |

Roles bitmap for ETHRegistrar registration uses registrar `REGISTRATION_ROLE_BITMAP` (set subregistry/resolver/transfer + admins) as implemented by the live registrar.

## Stage B — Issue Passport `victor.nomadic-passport.eth`

**Signer:** platform (B1–B3), then user (B4+)

| # | Signer | Target | Call | Key args | Ownership after |
| --- | --- | --- | --- | --- | --- |
| B1 | platform | VerifiableFactory | `deployProxy(UserRegistryImpl, …)` | `initialize(user, ROLE_REGISTRAR\|ADMIN + SET_PARENT\|ADMIN + UPGRADE\|ADMIN)` | Passport registry root admin = **user** |
| B2 | platform | VerifiableFactory | `deployProxy(PermissionedResolverImpl, …)` | `initialize(user, ALL_ROLES, [])` | Passport resolver admin = **user** |
| B3 | platform | Parent UserRegistry | `register("victor", user, passportRegistry, passportResolver, ownerRoles, type(uint64).max)` | ownerRoles = SET_SUBREGISTRY\|ADMIN + SET_RESOLVER\|ADMIN + RENEW\|ADMIN + UNREGISTER\|ADMIN + CAN_TRANSFER_ADMIN | **Passport token owner = user** |
| B4 | user | Passport UserRegistry | `setParent(parentRegistry, "victor")` | — | Canonical linkage |

Platform must have **no** Passport UserRegistry root `ROLE_REGISTRAR` after B1–B3.

## Stage C — Passport records

**Signer:** user (resolver admin)

Node: namehash of DNS-encoded `victor.nomadic-passport.eth`

| Record | Value |
| --- | --- |
| `addr` | `PASSPORT_OWNER_ADDRESS` |
| `com.nomadic.type` | `passport` |
| `com.nomadic.profile` | `https://nomadic-front-rosy.vercel.app/p/victor.nomadic-passport.eth` |
| `com.nomadic.currentJourney` | `lisbon-house` |
| `com.nomadic.credentials` | `lisbon-house.victor.nomadic-passport.eth` |

Optional (`description` / `url` / `avatar`): only if product later justifies; **not** required for P0.
**Do not** set `contenthash`. **Do not** store World data.

Calls may be individual `setAddr` / `setText` or batched via `PermissionedResolver.multicall`.

## Stage D — Credential child

**Signer:** user

| # | Target | Call | Args | Ownership after |
| --- | --- | --- | --- | --- |
| D1 | Passport UserRegistry | `register("lisbon-house", user, address(0), passportResolver, roles, type(uint64).max)` | roles = SET_RESOLVER\|ADMIN + CAN_TRANSFER_ADMIN | **Credential owner = user** |
| D2 | Passport PermissionedResolver | set credential records | see below | — |
| D3 | Passport PermissionedResolver | `authorizeTextRoles(credentialDns, key, issuer, true)` ×4 | allowlisted keys only | issuer scoped |

No separate credential UserRegistry.

### Credential records

Node: namehash of `lisbon-house.victor.nomadic-passport.eth`

| Key | Value |
| --- | --- |
| `addr` | `PASSPORT_OWNER_ADDRESS` (optional but set in sim) |
| `com.nomadic.type` | `journey-eligibility` |
| `com.nomadic.issuer` | issuer address string |
| `com.nomadic.journey` | `lisbon-house` |
| `com.nomadic.policy` | `lisbon_house_policy_v1` |
| `com.nomadic.status` | `active` |
| `com.nomadic.issuedAt` | unix timestamp placeholder at issuance |
| `com.nomadic.expiresAt` | `""` |
| `com.nomadic.metadata` | public URL or `""` |

Forbidden on-chain: World nullifiers/proofs, age/DOB/nationality, document data, selfie, Magic email, private application data.

## Stage E — Ownership checklist

| Name | Expected owner |
| --- | --- |
| `nomadic-passport.eth` | platform |
| `victor.nomadic-passport.eth` | user |
| `lisbon-house.victor.nomadic-passport.eth` | user |

Verify via registry `ownerOf` and `UniversalResolverV2.findOwner(dnsName)`.

## Gas notes (fork)

Approximate metered gas across staged calls: **~1.72e6** (see `06_SimulateIssuanceFork` logs). Parent also needs ~8 MockUSDC.

## Rollback / recovery

| Failure | Recovery |
| --- | --- |
| Commit expires (`MAX_COMMITMENT_AGE`) | New commit |
| Register reverts (taken / payment) | Re-check availability + USDC balance/allowance |
| Passport mint fails (EIP-7702 recipient) | Use empty-code EOA or IERC1155Receiver wallet |
| Wrong owner on Passport | Do not continue; unregister/reissue only if roles allow |
| Issuer over-granted | User revokes via `authorizeTextRoles(..., false)` before any transfer |
| Need to abandon parent | Parent remains platform-owned; do not transfer Passport registry admin to platform |

## Primary name

Not part of platform issuance broadcast. See preflight: recommendation **B** or **C**.

## Simulation command

```bash
forge script script/ensv2/06_SimulateIssuanceFork.s.sol --fork-url "$SEPOLIA_RPC_URL" -vv
```
