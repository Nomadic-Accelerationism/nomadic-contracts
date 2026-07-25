# ENSv2 Sepolia Deployment Profiles

ENSv2 has two distinct official Sepolia deployment namespaces at the pinned upstream commit
`48b3e2d39513b9dd32ef1850877a29009bc807b9`. They are independent registry trees and must
never be mixed.

## Required profile

Every script under `script/ensv2/` requires:

```bash
ENSV2_DEPLOYMENT_PROFILE=current
```

or:

```bash
ENSV2_DEPLOYMENT_PROFILE=explorer-v1-r2
```

Missing or unknown values revert. Scripts that only support one deployment additionally reject
the other profile.

## Profile files

| Profile | Address file | Upstream source |
| --- | --- | --- |
| `current` | `addresses/sepolia.ensv2.current.json` | `contracts/deployments/sepolia` and `docs/addresses/sepolia.md` |
| `explorer-v1-r2` | `addresses/sepolia.ensv2.explorer-v1-r2.json` | `contracts/deployments/sepolia-official-v1-20260525-r2` |

The original `addresses/sepolia.ensv2.json` is retained unchanged for compatibility. New execution
code uses the explicit profile definitions in `src/ensv2/ENSv2DeploymentProfiles.sol`.

## Core comparison

| Contract | `explorer-v1-r2` | `current` |
| --- | --- | --- |
| RootRegistry | `0xc960F7217d3643B525Ef36Bec8Adf86953CD9aB8` | `0x11b5BfbE9078D826b1eDBDd1cFC12f5828D9F50C` |
| ETHRegistry | `0xDEDB92913A25abE1f7BCDD85D8A344a43B398B67` | `0x67b728a792e789a8978b30cF1b3b641f19354b43` |
| ETHRegistrar | `0x8c2E866B439358c41AE05De9cbE8A00BFEFafFcA` | `0xa4449a0dD2b83007553D9b1d28b583A46A805a30` |
| VerifiableFactory | `0xD2a632D8a8b67c2c4398c255CbD7aF8dd7236198` | `0x118Bc31A50d559F7015a8Da26d54B3b030CdB70F` |
| UserRegistryImpl | `0x0F99e7Ea74903AfCB7224d0354fD7428A6f92917` | `0x840Fa461059862Ea466A711E8C98c8dE732061C0` |
| PermissionedResolverImpl | `0xdcE5205A553573FFd47629327DDdf36186022FfA` | `0x7E4B2d59938930168024201752EE5503df402303` |
| Direct Universal Resolver | `0x2F8A180604c42457Cb56C7c4f708748fF1F91DF1` | `0x85eDf8B6b7D4211e2b07AA687506B746357B92cf` |

Both profiles reference the stable public proxy addresses:

```text
top:     0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe
managed: 0x6d80F2172CFdEc5730fE683860C33d26fC42e6F1
```

Their live implementation pointers are dynamic and must be checked before every Explorer-r2
transaction.

## Historical ABI requirement

Explorer-r2 scripts use minimal interfaces matching the committed r2 artifacts. In particular:

```solidity
initialize(address rootAccount, uint256 roleBitmap)
```

is used for both the r2 `UserRegistryImpl` and `PermissionedResolverImpl`. The later resolver
initializer with an additional `bytes[]` argument must not be used against Explorer-r2.

Historical interface IDs also differ from later source revisions:

```text
IPermissionedRegistry: 0xafff3a63
IPermissionedResolver: 0x2c7442c9
IUniversalResolverV2:  0xf99a5e06
```

## No-mixing invariants

1. A profile supplies the complete Root/ETH/registrar/factory/implementation/UR set.
2. Explorer-r2 execution scripts reject `current`.
3. The current fork simulator rejects `explorer-v1-r2`.
4. The routing guard verifies the dynamic proxy chain before Explorer-r2 execution.
5. A script must never substitute the direct resolver or registry from the other profile.

The current direct resolver intentionally does not resolve the Explorer-r2 Passport hierarchy.
