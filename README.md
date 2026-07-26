# NOMADIC ACCELERATIONISM

`Deployments:`  

## Polygon zkEVM

Collateral.zkEVM.sol  

Deployer: 0x4A3f4D82a075434b24ff2920C573C704af776f6A
Deployed to: 0xB279337FEF2DaFa550594f5589c67b7b73DB6E24
Transaction hash: 0x2e2ac4bd565da53a253c5181b203dbd7a26217f4b49209ec4d941a457aa444f3

HackerHouse.zkEVM.sol  

Deployer: 0x4A3f4D82a075434b24ff2920C573C704af776f6A
Deployed to: 0x4fb57d05994f6D41792E42FB147D4F40426cDad2
Transaction hash: 0x2c271ea5634b825e8829323928e59e7a5fc4d70e9c37be1f0fea663797992f34

POL_ETH_USD_OracleReader.sol

Deployed at: 0x2A19790B6Dd1fC70e45e6F0D64A1a61C79a5Da0c

## FHENIX

Users.fhe.sol

Deployed to: 0x2A19790B6Dd1fC70e45e6F0D64A1a61C79a5Da0c

Journey.fhe.sol

Deployed to: 0x950650fda9c97c24aa90c6f0c3e8d9ddba4a48fb

## Ape Chain

Staking.apeChain.sol

Deployed to: 0x950650FdA9C97c24aA90C6f0C3e8d9DDbA4a48Fb

---

## Lisbon 2026 — ENSv2 Passport (ETHGlobal)

Sepolia ENSv2 demo for ETHGlobal Lisbon 2026: a user-owned Passport name, a Lisbon House journey credential child, scoped issuer text permissions, an issuer write, then Magic revocation proving the issuer can no longer write.

**Branch:** `lisboa2026`  
**Network:** Ethereum Sepolia (`chainId` `11155111`)  
**Deployment profile:** `explorer-v1-r2`  
**Date executed:** `2026-07-25`

### Hierarchy

```text
nomadic-passport.eth
└── victor.nomadic-passport.eth                    ← Magic Passport
    └── lisbon-house.victor.nomadic-passport.eth   ← Lisbon House credential
```

### Final result

```text
STAGE 3 VERIFIED WITH HARMLESS EXTRA TX
STAGE 4 VERIFIED
STAGE 5A VERIFIED
ISSUER PERMISSIONS REVOKED
STAGE 5B VERIFIED
POST-REVOCATION WRITE REJECTED
```

### Actors

| Role | Address |
| --- | --- |
| Platform / Nomadic parent owner | `0xca490deA7D7D79Bac4537D5Fe68fF10cd9c7EbEd` |
| Magic Passport owner | `0xd114FA765bA4811219AAe364c93CE8A81Ad39B17` |
| Lisbon House issuer | `0x3505b68444Db0E71987090769e5283AfC0efBd62` |

### Live contracts (Explorer-r2)

| Contract | Address |
| --- | --- |
| Nomadic parent registry | `0x8fB12e7Ab9B192503d7d02a43e0507c484e27280` |
| Passport UserRegistry | `0x40776D16B117b04FD5C08458E14ff8CF6518a40E` |
| Passport PermissionedResolver | `0x467B72a46F578a47878137883Ce35c980393Bffe` |
| Top Universal Resolver | `0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe` |
| Managed Universal Resolver | `0x6d80F2172CFdEc5730fE683860C33d26fC42e6F1` |
| Direct Explorer-r2 Universal Resolver | `0x2F8A180604c42457Cb56C7c4f708748fF1F91DF1` |

Credential node (namehash of `lisbon-house.victor.nomadic-passport.eth`):

```text
0x6ad2126ebdb620e0dedc9df67cbb3256d7d948d91f24db92ab3ede1a419e7142
```

### What was proven

1. **Platform** links the Nomadic parent and mints `victor` to Magic with a Passport UserRegistry + PermissionedResolver.
2. **Magic** configures the Passport parent, seeds Passport/credential records, registers `lisbon-house`, and grants the issuer `ROLE_SET_TEXT` only on:
   - `com.nomadic.status`
   - `com.nomadic.issuedAt`
   - `com.nomadic.expiresAt`
   - `com.nomadic.metadata`
3. **Issuer** successfully writes `com.nomadic.metadata = issuer-demo-stage4-verified`, and cannot tamper with protected keys such as `com.nomadic.type`.
4. **Magic** revokes those four text roles in one `multicall`.
5. **Post-revocation**, issuer `setText` on metadata reverts with `EACUnauthorizedAccountRoles` (simulation only — no Stage 5B broadcast). Ownership and credential records remain intact.

### Credential records (final)

| Key | Value |
| --- | --- |
| `com.nomadic.type` | `journey-eligibility` |
| `com.nomadic.issuer` | `0x3505b68444Db0E71987090769e5283AfC0efBd62` |
| `com.nomadic.journey` | `lisbon-house` |
| `com.nomadic.policy` | `lisbon_house_policy_v1` |
| `com.nomadic.status` | `active` |
| `com.nomadic.issuedAt` | `1785012002` |
| `com.nomadic.expiresAt` | `""` |
| `com.nomadic.metadata` | `issuer-demo-stage4-verified` |

### Stage highlights (public txs)

| Stage | What | Tx / note |
| ---: | --- | --- |
| 1 | Nomadic `setParent` → `nomadic-passport` | [`0xfa182140…`](https://sepolia.etherscan.io/tx/0xfa18214043a17ea2c775213c39be7cfbf96dc17151082a846a4a31329634117c) |
| 2 | Deploy Passport registry + resolver; register `victor` to Magic | [`0x6651ae96…`](https://sepolia.etherscan.io/tx/0x6651ae96217d19997fc143c165ea0f8920d96f71bc20c39cec7aaa6f93c59835), [`0xd898b399…`](https://sepolia.etherscan.io/tx/0xd898b3999eec06d19138e34ee41ce325eb6b6d3690c9e3bd146d35eb6d15462e), [`0x41d3d538…`](https://sepolia.etherscan.io/tx/0x41d3d5388163a68d413c8cc06fb7013ac1f8ffdea13e0dff2449dc9549b92903) |
| 3 | Magic Passport setup (5 canonical groups; 7 txs total) | see Stage 3 report |
| 4 | Issuer metadata write | [`0xc68d0d43…`](https://sepolia.etherscan.io/tx/0xc68d0d43654778054c5d5b2ac55f9b81ad1243167289c261983fcc3516f3992c) |
| 5A | Magic revoke 4 issuer text roles | [`0x9bb61d2b…`](https://sepolia.etherscan.io/tx/0x9bb61d2b31b38a28573dfd4cf970a661c38befe0002482f4b4d9a8504f69e801) |
| 5B | Post-revoke issuer write | **simulation only** — reverts; no broadcast |

### Package layout

| Path | Role |
| --- | --- |
| `src/ensv2/` | Deployment profiles, Sepolia addresses, Nomadic record keys |
| `script/ensv2/` | Guarded Explorer-r2 scripts `00`–`11` (routing + broadcast locks) |
| `test/ensv2/` | Hierarchy, permission invariants, profile/bundle tests |
| `docs/ENSV2_*.md` | Plans, permission model, execution log, stage reports |

### Docs entry points

- [`docs/ENSV2_SEPOLIA_EXECUTION_LOG.md`](./docs/ENSV2_SEPOLIA_EXECUTION_LOG.md) — public Stage 1–5 tx log
- [`docs/ENSV2_STAGE3_FINAL_REPORT.md`](./docs/ENSV2_STAGE3_FINAL_REPORT.md) — Magic setup verification
- [`docs/ENSV2_STAGE4_STAGE5_FINAL_REPORT.md`](./docs/ENSV2_STAGE4_STAGE5_FINAL_REPORT.md) — issuer write + revocation + post-revoke proof
- [`docs/ENSV2_EXPLORER_R2_EXECUTION_PLAN.md`](./docs/ENSV2_EXPLORER_R2_EXECUTION_PLAN.md) — operator plan / gates
- [`docs/ENSV2_PERMISSION_MODEL.md`](./docs/ENSV2_PERMISSION_MODEL.md) — scoped `ROLE_SET_TEXT` model
- [`docs/ENSV2_PASSPORT_HIERARCHY.md`](./docs/ENSV2_PASSPORT_HIERARCHY.md) — hierarchy and roles

### Local verification

```shell
export ENSV2_DEPLOYMENT_PROFILE=explorer-v1-r2
forge test -vvv
# Optional live routing guard (read-only):
forge script script/ensv2/07_VerifyExplorerR2Routing.s.sol --rpc-url "$SEPOLIA_RPC_URL"
```

Broadcast scripts remain operator-gated (`ENSV2_BROADCAST` + exact routing ack). Do not commit `.env`, private keys, or Forge `broadcast/` artifacts.

---

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
