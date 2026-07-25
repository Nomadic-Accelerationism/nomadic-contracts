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
