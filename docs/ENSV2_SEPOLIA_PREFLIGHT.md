# ENSv2 Sepolia Preflight

Read-only preflight for the first real Nomadic Passport issuance on Ethereum Sepolia.

**Status:** simulation-backed plan complete. **No transactions broadcast.**

> This document describes the `current` deployment profile. The registered Explorer-r2 parent
> and guarded execution package are documented in
> [`ENSV2_EXPLORER_R2_EXECUTION_PLAN.md`](./ENSV2_EXPLORER_R2_EXECUTION_PLAN.md). Never combine
> addresses from the two profiles.

Target hierarchy:

```text
nomadic-passport.eth
└── victor.nomadic-passport.eth
    └── lisbon-house.victor.nomadic-passport.eth
```

## 1. Upstream pin

| Field | Value |
| --- | --- |
| Submodule | `lib/ens-contracts-v2` → `ensdomains/contracts-v2` |
| Pinned commit | `48b3e2d39513b9dd32ef1850877a29009bc807b9` |
| Address source | `lib/ens-contracts-v2/contracts/docs/addresses/sepolia.md` |
| Committed mirror | `addresses/sepolia.ensv2.json` / `src/ensv2/SepoliaENSv2.sol` |
| Chain ID | `11155111` |
| Deployed-at (upstream) | `2026-06-29T05:35:12.452Z` |

Pin was **not** updated. Official Sepolia markdown addresses match the committed JSON (verified).

## 2. Sepolia deployment verification

Command:

```bash
forge script script/ensv2/00_VerifyDeployment.s.sol --rpc-url "$SEPOLIA_RPC_URL" -vv
```

**Result:** `Sepolia ENSv2 deployment verification PASSED`

Bytecode present and contracts callable at every required address, including:

* `ETHRegistrar` `0xa4449a0dD2b83007553D9b1d28b583A46A805a30`
* `ETHRegistry` `0x67b728a792e789a8978b30cF1b3b641f19354b43`
* `VerifiableFactory` `0x118Bc31A50d559F7015a8Da26d54B3b030CdB70F`
* `UserRegistryImpl` `0x840Fa461059862Ea466A711E8C98c8dE732061C0`
* `PermissionedResolverImpl` `0x7E4B2d59938930168024201752EE5503df402303`
* `UniversalResolverV2` `0x85eDf8B6b7D4211e2b07AA687506B746357B92cf`
* MockUSDC payment token `0xD3322B29a7BdEe707D1684676f149bf41Aa3422f`

## 3. Parent readiness: `nomadic-passport.eth`

Command:

```bash
forge script script/ensv2/05_PreflightParent.s.sol --rpc-url "$SEPOLIA_RPC_URL" -vv
```

| Field | Live value |
| --- | --- |
| State | **AVAILABLE_UNREGISTERED** |
| Owner | `0x000…000` |
| Expiry | `0` |
| Resolver | none |
| Subregistry | none |
| `ETHRegistrar.isAvailable("nomadic-passport")` | `true` |

Registrar parameters (live):

* `MIN_COMMITMENT_AGE` = `60`
* `MAX_COMMITMENT_AGE` = `86400`
* `MIN_REGISTER_DURATION` = `2419200` (28 days)
* ~1y MockUSDC price ≈ `8000021` raw units (~8 USDC with 6 decimals)

Safe alternatives (also available; **not** auto-selected):

1. `nomadic-passport-test.eth`
2. `nomadic-lisbon-passport.eth`
3. `nomadic-ethglobal-lisbon.eth`

`01_InspectParent` correctly reports `parentSuitableForPrototype=false` until the parent is registered and the platform holds `ROLE_REGISTRAR` on its UserRegistry.

## 4. Required signer addresses

Set via environment (never hardcoded in Solidity product sources):

| Variable | Role |
| --- | --- |
| `NOMADIC_PARENT_OWNER_ADDRESS` | Platform / deployer; owns parent; issues Passports |
| `PASSPORT_OWNER_ADDRESS` | Real Magic Ethereum wallet; owns Passport + credential |
| `LISBON_HOUSE_ISSUER_ADDRESS` | Lisbon House operator; scoped text updates only |

If `NOMADIC_PARENT_OWNER_ADDRESS == LISBON_HOUSE_ISSUER_ADDRESS`, the scoped-permission demo is weaker — use a distinct issuer.

**EIP-7702 / smart-wallet warning:** ERC-1155 singleton safe-mint requires the recipient to be an empty-code EOA **or** implement `IERC1155Receiver`. `makeAddr("user")` is EIP-7702 delegated on live Sepolia and fails mint. Real Magic wallets must be empty-code EOAs or ERC-1155-capable contracts.

Fork-sim defaults (empty-code demo EOAs only):

* platform `0x723d360EA1f6eFb71c3798C267EFddE1604bf4a4`
* user `0x263d44bE3B07686a0f6CcF2Bc81d2b6d89eBeB5b`
* issuer `0xc0b76553a2A5DD6D5Ba5f6AefD178615C079f64b`

## 5–7. Exact registration / issuance paths

See [`ENSV2_PASSPORT_ISSUANCE_PLAN.md`](./ENSV2_PASSPORT_ISSUANCE_PLAN.md).

## 8. Final ownership (after successful issuance)

| Name | Owner |
| --- | --- |
| `nomadic-passport.eth` | `NOMADIC_PARENT_OWNER_ADDRESS` |
| `victor.nomadic-passport.eth` | `PASSPORT_OWNER_ADDRESS` |
| `lisbon-house.victor.nomadic-passport.eth` | `PASSPORT_OWNER_ADDRESS` |

Platform must **not** retain Passport UserRegistry root registrar roles after handoff.

## 9–11. Records, permissions, revocation

See issuance plan + [`ENSV2_PERMISSION_DEMO_PLAN.md`](./ENSV2_PERMISSION_DEMO_PLAN.md).

## 12. Primary-name recommendation

**B. User must sign a separate frontend transaction** (preferred for consent), or **C. Defer for P0**.

`L2ReverseRegistrar.setName(name)` uses `msg.sender`. `setNameForAddr` requires the caller to be an authorized namer for that address. The platform must **not** force-change a Magic wallet primary name during issuance broadcast.

## 13–15. Transactions / gas / funding

From fork simulation (`06_SimulateIssuanceFork.s.sol`):

| Metric | Value |
| --- | --- |
| Metered logical stages | ~10 (proxies/records may be split further on broadcast) |
| Approximate metered gas | ~1.72e6 |
| Approx Sepolia ETH @ 20 gwei | ~0.034 ETH for gas (platform-heavy) |
| Parent payment | ~8 MockUSDC (mintable on Sepolia) for 1y |
| Passport owner Sepolia ETH | Required for user-signed txs (setParent, records, credential, authorize, revoke) unless platform sponsors via meta-tx (out of scope) |
| Issuer Sepolia ETH | Required only for permission-demo status updates |

Logical signer map:

1. **Platform:** parent proxies, commit, USDC mint/approve, register parent, parent `setParent`, passport proxies, register `victor`
2. **User:** passport `setParent`, passport records, register credential, credential records, authorize issuer, revoke
3. **Issuer:** allowlisted `setText` demo only

## 16. Fork simulation result

```bash
forge script script/ensv2/06_SimulateIssuanceFork.s.sol --fork-url "$SEPOLIA_RPC_URL" -vv
```

**Result:** `Sepolia fork issuance simulation PASSED`

Asserted:

* parent owned by platform
* Passport + credential owned by user
* Passport `addr` → user
* Passport / credential texts readable
* UniversalResolver finds both owners
* issuer can update allowlisted keys only
* issuer forbidden keys revert
* user revocation succeeds; post-revoke issuer write reverts
* ownership unchanged after demo

## 17. Blockers before real broadcast

1. Operator must supply real `NOMADIC_PARENT_OWNER_ADDRESS`, `PASSPORT_OWNER_ADDRESS`, `LISBON_HOUSE_ISSUER_ADDRESS`.
2. Parent is still unregistered — platform must complete commit–reveal and fund MockUSDC.
3. Wait ≥61s between commit and register.
4. Confirm Magic wallet has empty code (or ERC-1155 receiver).
5. User wallet needs Sepolia ETH for post-handoff txs (or a future sponsored path).
6. Keep `ENSV2_BROADCAST=false` until an explicit broadcast slice.

## 18. Exact future broadcast command (DO NOT RUN YET)

After a dedicated broadcast script exists and operators confirm keys/RPC:

```bash
# ILLUSTRATIVE ONLY — do not execute in this preflight slice.
# ENSV2_BROADCAST=true forge script script/ensv2/<BroadcastIssuance>.s.sol \
#   --rpc-url "$SEPOLIA_RPC_URL" \
#   --broadcast \
#   --private-key "$PLATFORM_PRIVATE_KEY"
```

This repository currently rejects broadcast when `ENSV2_BROADCAST` is true on the simulation scripts. A separate, reviewed broadcast script is required before any live send.

## Related docs

* [`ENSV2_PASSPORT_ISSUANCE_PLAN.md`](./ENSV2_PASSPORT_ISSUANCE_PLAN.md)
* [`ENSV2_PERMISSION_DEMO_PLAN.md`](./ENSV2_PERMISSION_DEMO_PLAN.md)
* [`ENSV2_SOURCE_AND_DEPLOYMENT.md`](./ENSV2_SOURCE_AND_DEPLOYMENT.md)
* [`ENSV2_RECORD_SCHEMA.md`](./ENSV2_RECORD_SCHEMA.md)
