# ENSv2 Sepolia Execution Log

Public Stage results for Explorer-r2 (`ENSV2_DEPLOYMENT_PROFILE=explorer-v1-r2`).
No private keys, RPC credentials, or secret-bearing command history are recorded here.

## Stage 1 — Canonical parent link (`setParent`)

| Field | Value |
| --- | --- |
| Date | `2026-07-25` |
| Script | `script/ensv2/08_SetParentExplorerR2.s.sol` |
| Chain | Sepolia `11155111` |
| Transaction | `0xfa18214043a17ea2c775213c39be7cfbf96dc17151082a846a4a31329634117c` |
| Block | `11349952` |
| Receipt status | `1` (success) |
| Gas used | `87564` |
| Nomadic registry | `0x8fB12e7Ab9B192503d7d02a43e0507c484e27280` |
| Resulting parent | `0xDEDB92913A25abE1f7BCDD85D8A344a43B398B67` |
| Resulting label | `nomadic-passport` |
| Canonical registry | `0x8fB12e7Ab9B192503d7d02a43e0507c484e27280` |
| Parent owner (unchanged) | `0xca490deA7D7D79Bac4537D5Fe68fF10cd9c7EbEd` |
| `victor` owner after Stage 1 | `address(0)` — **not issued** |

Stage 2 (`09_IssuePassportExplorerR2.s.sol`) was **not** executed in that Stage 1 step; it followed separately (below).

## Stage 2 — Passport issuance

| Field | Value |
| --- | --- |
| Date | `2026-07-25` |
| Script | `script/ensv2/09_IssuePassportExplorerR2.s.sol` |
| Chain | Sepolia `11155111` |
| Profile | `explorer-v1-r2` |
| Platform signer | `0xca490deA7D7D79Bac4537D5Fe68fF10cd9c7EbEd` |
| Block (all three txs) | `11350002` |
| Passport UserRegistry | `0x40776D16B117b04FD5C08458E14ff8CF6518a40E` |
| Passport PermissionedResolver | `0x467B72a46F578a47878137883Ce35c980393Bffe` |
| Passport owner after Stage 2 | Magic `0xd114FA765bA4811219AAe364c93CE8A81Ad39B17` |

| # | Hash | Target | Function | Gas | Status |
| --- | --- | --- | --- | ---: | --- |
| 1 | `0x6651ae96217d19997fc143c165ea0f8920d96f71bc20c39cec7aaa6f93c59835` | VerifiableFactory `0xd2a632d8…` | `deployProxy` (Passport registry) | 176492 | `1` |
| 2 | `0xd898b3999eec06d19138e34ee41ce325eb6b6d3690c9e3bd146d35eb6d15462e` | VerifiableFactory `0xd2a632d8…` | `deployProxy` (PermissionedResolver) | 175954 | `1` |
| 3 | `0x41d3d5388163a68d413c8cc06fb7013ac1f8ffdea13e0dff2449dc9549b92903` | Nomadic registry `0x8fB12e7A…` | `register("victor", Magic, …)` | 180248 | `1` |

## Stage 3 — Magic Passport setup (Magic wallet confirmations)

| Field | Value |
| --- | --- |
| Date | `2026-07-25` |
| Chain | Sepolia `11155111` |
| Profile | `explorer-v1-r2` |
| Magic signer | `0xd114FA765bA4811219AAe364c93CE8A81Ad39B17` |
| Total Magic Stage 3 txs | **7** (not 5) |
| Final result | `STAGE 3 VERIFIED WITH HARMLESS EXTRA TX` |
| Full report | [`docs/ENSV2_STAGE3_FINAL_REPORT.md`](./ENSV2_STAGE3_FINAL_REPORT.md) |

### Canonical group txs

| Group | Hash | Block | Gas |
| --- | --- | ---: | ---: |
| 1 Configure Passport registry parent | `0x4961dbbc7580f125348ee8670cad91465fe13a0b5369f198e780f30bc86bd3c7` | 11350310 | 87444 |
| 2 Set Passport records (first write) | `0x5100e857f676638c5be76a3ab5c7639d1691375afd84cd0580f05cf6433854c8` | 11350313 | 329611 |
| 3 Register Lisbon credential | `0xf6a53888a1361b825aaf8218c7acfdbe0f15a493c67f01b6732dc8cf7071d595` | 11350329 | 178324 |
| 4 Set credential records (first write) | `0x6730aec958bfc32b10de62a735025dd95b8f683991537709721ce6fd118b61fa` | 11350347 | 328682 |
| 5 Authorize scoped issuer keys | `0xb8fc4cbdfbdc8cb6eef5b6350611d9c9ddd19fdf63bc52aec94d76f4f43c35d8` | 11350356 | 287120 |

### Harmless redundant rewrites (exact same calldata / node)

| Group | Hash | Block | Gas | Note |
| --- | --- | ---: | ---: | --- |
| 2 | `0xa857a8783e2df02c79796b2c3f3b9a0f1e395ddc34049a9e9a43e4ce6c2979e1` | 11350315 | 130887 | UI postconditions failed due to frontend namehash bug; on-chain write was correct |
| 4 | `0x8f12865d876c9b11ddb1644f7fa4ae7d4037c5f225184bf417335d62afed6023` | 11350349 | 169620 | Identical credential multicall rewrite |

## Stage 4 — Issuer allowed write + Stage 5 — Magic revocation + post-revoke proof

| Field | Value |
| --- | --- |
| Date | `2026-07-25` |
| Chain | Sepolia `11155111` |
| Profile | `explorer-v1-r2` |
| Full report | [`docs/ENSV2_STAGE4_STAGE5_FINAL_REPORT.md`](./ENSV2_STAGE4_STAGE5_FINAL_REPORT.md) |
| Final result | `STAGE 4 VERIFIED` / `STAGE 5A VERIFIED` / `ISSUER PERMISSIONS REVOKED` / `STAGE 5B VERIFIED` / `POST-REVOCATION WRITE REJECTED` |

| Stage | Hash | Signer | Target | Notes | Block | Gas | Status |
| --- | --- | --- | --- | --- | ---: | ---: | --- |
| 4 | `0xc68d0d43654778054c5d5b2ac55f9b81ad1243167289c261983fcc3516f3992c` | Issuer | PermissionedResolver | `setText` metadata → `issuer-demo-stage4-verified` | 11350501 | 70867 | `1` |
| 5A | `0x9bb61d2b31b38a28573dfd4cf970a661c38befe0002482f4b4d9a8504f69e801` | Magic | PermissionedResolver | `multicall` of 4× `authorizeTextRoles(..., false)` | 11350959 | 107072 | `1` |
| 5B | *(none)* | Issuer | — | read-only `setText` metadata simulation **reverted**; no broadcast; issuer nonce remains `1` | — | — | — |

Cleanup: **not required**.
