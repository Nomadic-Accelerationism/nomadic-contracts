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

Stage 2 (`09_IssuePassportExplorerR2.s.sol`) was **not** executed in this step.

## Stage 2 — Passport issuance

Pending. Do not run until Stage 1 postconditions above remain true and operators explicitly authorize Stage 2.

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

Stage 4 / issuer writes / Magic revocation: **not executed**.
