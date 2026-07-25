# ENSv2 Local Test Results

## Commands

```bash
git submodule update --init --recursive
forge fmt --check
forge build --sizes
forge test -vvv
```

## Results (this scaffold)

| Suite | Result |
| --- | --- |
| `Counter.t.sol` (legacy) | 2 passed |
| `PassportHierarchy.t.sol` | 12 passed |
| `PermissionInvariants.t.sol` | 15 passed |
| **Total** | **29 passed, 0 failed** |

## Hierarchy results

* Platform provisions Passport under parent.
* Passport ownership assigned to user.
* Passport resolver is PermissionedResolver; `addr` resolves to user.
* Passport has child UserRegistry; credential is a normal child label (no credential UserRegistry).
* UniversalResolver finds Passport + credential owners/resolvers.
* Platform has no Passport registry root roles after handoff and cannot transfer without user cooperation.

## Permission / revocation results

* Issuer can update only allowlisted credential text keys.
* Forbidden keys / addr / contenthash / resolver / transfer / sibling register / self-grant / upgrade / clear all fail.
* Revocation uses `authorizeTextRoles(..., false)`; subsequent issuer write reverts with  
  `EACUnauthorizedAccountRoles(resource(node,0), ROLE_SET_TEXT, issuer)` (`0x4b27a133`).
* Transfer leaves external resolver permissions intact unless revoked first.

## Warnings classification

| Item | Class |
| --- | --- |
| `HackerHouse.zkEVM.sol` `block.timestamp` lint | Legacy unrelated warning (not silenced) |
| `UUPSProxyLogic` payable fallback without receive | Upstream ENSv2 / verifiable-factory warning |

## Current limitation

These tests prove hierarchy and permissions **locally**. No Sepolia state-changing transactions were broadcast.

## Sepolia read-only (this environment)

* `00_VerifyDeployment` against public Sepolia RPC: **PASSED**
* `01_InspectParent` without `ENSV2_PARENT_NAME`: fails with explanatory require (expected)
* Planning scripts 02-04 local simulations: **PASSED**
