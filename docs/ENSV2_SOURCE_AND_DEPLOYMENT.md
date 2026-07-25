# ENSv2 Source and Sepolia Deployment

## Upstream pin

| Field | Value |
| --- | --- |
| Repository | `https://github.com/ensdomains/contracts-v2` |
| Submodule path | `lib/ens-contracts-v2` |
| Pinned commit | `48b3e2d39513b9dd32ef1850877a29009bc807b9` |
| Selection reason | Matches the audited activation tip; current `main` was identical at pin time; `contracts/docs/addresses/sepolia.md` unchanged vs tip |

Before changing the pin:

1. Fetch the newer upstream commit.
2. Diff `contracts/docs/addresses/sepolia.md`.
3. Re-verify bytecode on Sepolia for required contracts.
4. Regenerate `addresses/sepolia.ensv2.json` and update `src/ensv2/SepoliaENSv2.sol`.

## Setup

```bash
git submodule update --init --recursive
```

This repository depends on nested ENSv2 submodules (OpenZeppelin, verifiable-factory, ens-contracts, etc.).

## Generated address source

| File | Role |
| --- | --- |
| `lib/ens-contracts-v2/contracts/docs/addresses/sepolia.md` | Authoritative upstream doc |
| `addresses/sepolia.ensv2.json` | Generated Nomadic address file |
| `src/ensv2/SepoliaENSv2.sol` | Solidity constants used by every script |

Do not scatter addresses through scripts. Always import `SepoliaENSv2`.

## Sepolia snapshot (pinned)

- Network: sepolia
- Chain ID: `11155111`
- Deployed at: `2026-06-29T05:35:12.452Z`

Important contracts (see JSON/library for full list):

- RootRegistry, ETHRegistry, ETHRegistrar, BatchRegistrar
- VerifiableFactory, UserRegistryImpl, PermissionedResolverImpl
- PublicResolverV2, UniversalResolverV2
- UpgradableUniversalResolverProxy, ManagedUniversalResolverProxy
- ReverseRegistrarAdapter, DefaultReverseRegistrarAdapter

Older folder `deployments/sepolia-official-v1-20260525-r2/` is historical and must not be used.

## Verification

```bash
forge script script/ensv2/00_VerifyDeployment.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" -vvv
```

Read-only. No private key. No broadcast.
