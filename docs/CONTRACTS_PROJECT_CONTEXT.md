# Nomadic Contracts — ETHGlobal Lisbon 2026 Project Context

Activation and audit pass for ENSv2 Passport / Journey credential work.  
**No contracts were deployed. No transactions were broadcast. No ABIs were imported.**

---

## 1. Repository state

| Item | Value |
| --- | --- |
| Remote | `https://github.com/Nomadic-Accelerationism/nomadic-contracts` |
| Classification | **Foundry project** with legacy multi-chain Solidity experiments |
| Package manager | None (`package.json` absent) |
| TypeScript / Hardhat / Bun app layer | Absent |
| Working tree at activation | Clean (no uncommitted user edits) |
| Submodules | Declared; were empty until `git submodule update --init --recursive` (checkout only; no content edits) |

This is **not** empty/scaffold-only: it contains prior Nomadic contract experiments (zkEVM, Fhenix FHE, ApeChain staking, Chronicle oracle reader) plus Foundry defaults (`Counter`).

Preserve all existing `src/` contracts. Do not replace the Foundry toolchain without justification.

---

## 2. Active branch and base commit

| Item | Value |
| --- | --- |
| Active branch | `lisboa2026` (**created locally**; did not exist on remote) |
| Base branch | `main` (`origin/main`, default) |
| Base commit | `a867758eaed84b9c31ae6fa11d34183324dfdd58` |
| Base commit subject | `update readme` |
| Pushed? | **No** (explicitly not pushed in activation; scaffold also unpushed unless instructed) |
| Uncommitted work status | Scaffold adds ENSv2 docs/scripts/tests; `docs/` is now trackable (`.gitignore` updated) |

---

## 3. Existing toolchain

| Tool | Version / notes |
| --- | --- |
| Foundry / forge | `1.7.1` (`4072e48705`, 2026-05-08) — installed in this environment for baseline validation |
| cast / anvil / chisel | Bundled with Foundry `1.7.1` |
| Solc (via forge) | `0.8.25` used for compile |
| Contract pragmas | Mostly `^0.8.13`; `Pol_Eth_Usd_OracleReader.sol` uses `^0.8.16` |
| Node | `v22.14.0` present; unused by this repo today |
| npm | `10.9.7` present; no project scripts |
| Bun | Not installed / not used |
| TypeScript / Hardhat | Not configured |
| CI | `.github/workflows/test.yml` — Foundry nightly, `forge build --sizes`, `forge test -vvv`, `workflow_dispatch` only |
| Submodules | `lib/forge-std` @ `07263d1` (v1.9.1); `lib/openzeppelin-contracts` @ `dbb6104` (v5.0.0-ish); `lib/fhenix-contracts` @ `9e17d0a` (v0.2.1) |

`foundry.toml` is minimal (`src`, `out`, `libs = ["lib"]`). No remappings file beyond Foundry defaults/submodules.

---

## 4. Baseline command results

| Command | Result |
| --- | --- |
| `git submodule update --init --recursive` | Success (required; libs were empty) |
| `forge build` | **Success** (36 files, Solc 0.8.25). Pre-existing lint warning: `block.timestamp` in `HackerHouse.zkEVM.sol:26` |
| `forge test` | **Success** — `Counter.t.sol`: 2 passed (including fuzz) |
| `npm ci` / `npm run build` / `npm test` | **Not applicable** — no `package.json` |
| `bun` scripts | **Not applicable** |

Environment requirements observed:

* Foundry must be installed (`forge` was missing until `foundryup`).
* Git submodules must be initialized or compile fails on `forge-std` / OZ / Fhenix imports.
* No `.env` / `.env.example` currently required for build/test.

Unrelated failures were **not** fixed in this pass.

---

## 5. Existing contracts / scripts / tests

### Contracts (`src/`)

| File | Purpose (legacy) |
| --- | --- |
| `Counter.sol` | Foundry template |
| `Collateral.zkEVM.sol` | ETH collateral mapping (Polygon zkEVM experiment) |
| `HackerHouse.zkEVM.sol` | Hacker-house lifecycle struct/status |
| `Journey.fhe.sol` | Fhenix FHE journey record |
| `Users.fhe.sol` | Fhenix FHE hacker profile (includes opaque `bytes32 ens` field — not ENSv2) |
| `Staking.apeChain.sol` | APE/ETH staking mock |
| `Pol_Eth_Usd_OracleReader.sol` | Chronicle ETH/USD reader (Polygon zkEVM testnet addresses) |

### Scripts (`script/`)

* `Counter.s.sol` only — broadcasts `new Counter()` (template).

### Tests (`test/`)

* `Counter.t.sol` only.

### Deployments / broadcasts

* No `broadcast/` directory in the tree.
* Deployment addresses are documented in `README.md` (zkEVM / Fhenix / ApeChain), not as Foundry broadcast artifacts.

### Env / ignore / CI / README

* `.env` ignored; no `.env.example`.
* `.gitignore` ignores `cache/`, `out/`, local broadcast dry-runs, **`docs/`**, and `.env`.
* README mixes Nomadic deployment notes with Foundry usage boilerplate.
* README deploy example passes `--private-key` on the CLI (legacy pattern; do not extend for ENSv2).

---

## 6. Current ENS work

**None for ENSv2.**

* No ENS registry/resolver integrations.
* No viem/ethers scripts for name registration.
* Only ENS mention: `Users.fhe.sol` stores a `bytes32 ens` credential hash alongside other opaque proofs.
* No chain config for Sepolia ENSv2.
* No private-key handling beyond README’s Foundry deploy example string.

Legacy Nomadic experiments remain relevant as product history (Journey / HackerHouse / identity proofs) but are **not** the Lisbon ENSv2 implementation surface.

---

## 7. Recommended upstream ENSv2 source strategy

Authoritative upstream: [`ensdomains/contracts-v2`](https://github.com/ensdomains/contracts-v2)  
Pinned assessment tip: **`48b3e2d39513b9dd32ef1850877a29009bc807b9`** (`main` as of this audit; commit message includes post-audit changes; owns current `contracts/docs/addresses/sepolia.md`).

### Option comparison

| Option | Verdict |
| --- | --- |
| **A — Pinned git submodule** | **Recommended.** Exact commit, full Solidity sources, unit tests (`UserRegistry.t.sol`, `PermissionedResolver.t.sol`), deploy scripts, and `deployments/sepolia/*.json` ABIs/addresses. Matches existing repo pattern (`lib/*` submodules). Heavier clone, but strongest audit trail for a hackathon. |
| **B — Pinned npm package** | **Insufficient as sole source.** No `@ensdomains/ens-contracts-v2` (404). Upstream `contracts/package.json` is named `"contracts"` and is a Hardhat/Bun monorepo package, not a published ENSv2 artifact set. `@ensdomains/ens-contracts` is v1. `@ensdomains/verifiable-factory` exists (`0.0.1-alpha.2`) but does not cover registries/resolvers/addresses. |
| **C — Minimal local ABI fragments** | Rejected as primary: high staleness risk; must re-copy on every redeploy; weak for writing permission-safe scripts. |
| **D — Fetch/generate ABIs from pinned commit during setup** | Acceptable **secondary** path (CI/setup script curling `deployments/sepolia/*.json` + `docs/addresses/sepolia.md` at a pinned SHA). Good reproducibility if submodule weight is unwanted, but worse offline/hackathon resilience than A. |

### Recommendation

**Use Option A:** add `lib/ens-contracts-v2` (or similar) as a **pinned submodule** at `48b3e2d…` (or a newer SHA re-verified against Sepolia bytecode before implementation).

Consume from that pin:

* `contracts/docs/addresses/sepolia.md`
* `contracts/deployments/sepolia/*.json` (ABIs + addresses)
* Solidity sources / role libs for reference and forge tests
* Upstream unit/integration tests as behavioral oracle

Optional complement: thin generated/committed address constants file **derived from the pin**, never hand-copied from chat/docs previews.

**Do not import ABIs in this activation pass** (already respected).

---

## 8. Current Sepolia deployment source

Source file: `contracts/docs/addresses/sepolia.md` @ upstream commit `48b3e2d39513b9dd32ef1850877a29009bc807b9`

| Field | Value |
| --- | --- |
| Network | sepolia |
| Chain ID | `11155111` |
| Deployed at | `2026-06-29T05:35:12.452Z` |
| Doc ↔ `deployments/sepolia/*.json` | Spot-checked match for RootRegistry, ETHRegistry, VerifiableFactory, UserRegistryImpl, PermissionedResolverImpl |

### Important addresses (documentation snapshot; do not hardcode into app code yet)

| Contract | Address | Bytecode on Sepolia (publicnode RPC) |
| --- | --- | --- |
| RootRegistry | `0x11b5bfbe9078d826b1edbdd1cfc12f5828d9f50c` | Present (~14711 B) |
| ETHRegistry | `0x67b728a792e789a8978b30cf1b3b641f19354b43` | Present (~14711 B) |
| ETHRegistrar | `0xa4449a0dd2b83007553d9b1d28b583a46a805a30` | Present (~7472 B) |
| BatchRegistrar | `0xfe2aab6df1cbff84534ce65d9e4a755ba02d6795` | Present (~2196 B) |
| VerifiableFactory | `0x118bc31a50d559f7015a8da26d54b3b030cdb70f` | Present (~1403 B) |
| UserRegistryImpl | `0x840fa461059862ea466a711e8c98c8de732061c0` | Present (~17140 B) |
| PermissionedResolverImpl | `0x7e4b2d59938930168024201752ee5503df402303` | Present (~17554 B) |
| PublicResolverV2 | `0xd25f66dd4ff61486c2c5c1e6201a23576698d3df` | Present (~14402 B) |
| UniversalResolverV2 | `0x85edf8b6b7d4211e2b07aa687506b746357b92cf` | Present (~18354 B) |
| UpgradableUniversalResolverProxy | `0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe` | Present (~2491 B) |
| ReverseRegistrarAdapter | `0x94e64e29e25533f93ba0a430646ae42cb47bf8f3` | Present (~1427 B) |
| DefaultReverseRegistrarAdapter | `0x1f7b9461d17d5cf43553253c6b78d252d9575954` | Present (~1492 B) |

### Differs from documentation previews

Yes. Older folder `contracts/deployments/sepolia-official-v1-20260525-r2/` contains a **prior** Sepolia deployment with different addresses (e.g. ETHRegistry `0xdedb…b67`, VerifiableFactory `0xd2a6…6198`). Current docs + `deployments/sepolia/` reflect the **2026-06-29** deployment. Prefer current `sepolia.md` / `deployments/sepolia/`; treat older folders as historical only.

---

## 9. Proposed directory structure

Keep legacy contracts in place. Add ENSv2 work beside them:

```text
nomadic-contracts/
├── docs/
│   └── CONTRACTS_PROJECT_CONTEXT.md          # this file (un-ignore in next slice)
├── lib/
│   ├── forge-std/
│   ├── openzeppelin-contracts/
│   ├── fhenix-contracts/
│   └── ens-contracts-v2/                     # NEW: pinned submodule → ensdomains/contracts-v2
├── src/
│   ├── <legacy contracts unchanged>
│   └── ensv2/                                # optional thin wrappers / helpers only if needed
├── script/
│   └── ensv2/
│       ├── 00_CheckChain.s.sol               # chain-id guard, no broadcast by default
│       ├── 01_ProvisionPassport.s.sol
│       ├── 02_IssueCredential.s.sol
│       └── 03_AuthorizeIssuerRecords.s.sol
├── test/
│   └── ensv2/
│       ├── PassportHierarchy.t.sol
│       └── PermissionInvariants.t.sol
├── addresses/
│   └── sepolia.ensv2.json                    # generated from pinned upstream; committed
├── .env.example
├── foundry.toml                              # extend remappings / fs_permissions as needed
└── README.md                                 # Lisbon ENSv2 section later
```

Scripts should default to simulation; require an explicit broadcast flag plus chain-id check.

---

## 10. Proposed environment variables

Proposed `.env.example` names only (no secrets):

```text
# RPC
SEPOLIA_RPC_URL=

# ENSv2 hierarchy targets (do not assume nomadic.eth)
ENSV2_PARENT_NAME=
ENSV2_PLATFORM_ADDRESS=
ENSV2_PASSPORT_OWNER_ADDRESS=
ENSV2_ISSUER_ADDRESS=
ENSV2_PASSPORT_LABEL=
ENSV2_CREDENTIAL_LABEL=

# Writes (never print; never commit)
ENSV2_DEPLOYER_PRIVATE_KEY=

# Safety
ENSV2_EXPECTED_CHAIN_ID=11155111
ENSV2_BROADCAST=false
```

Security rules for the next implementation:

* No real keys in `.env.example` or committed files.
* Keep `.env` gitignored.
* Scripts must never `console.log` private keys.
* No transaction broadcast by default (`ENSV2_BROADCAST=false`).
* Require explicit broadcast confirmation.
* Verify `block.chainid == ENSV2_EXPECTED_CHAIN_ID` before any write.
* Do not commit mnemonics.

---

## 11. Product hierarchy

Conceptual target (parent name TBD; not assumed owned):

```text
<passport-label>.<parent-name>
└── <journey-credential>.<passport-label>.<parent-name>
```

Example only:

```text
victor.nomadic-passport-test.eth
└── lisbon-house.victor.nomadic-passport-test.eth
```

Product cycle:

```text
Onboarding → Nomadic ENS Passport
→ Journey application (World privately verifies policy)
→ Eligibility → Journey credential subname issued
→ Passport reads ENS records
→ Other apps resolve the same portable identity
```

Likely on-chain mapping:

```text
Platform-controlled parent registry
└── User-owned Passport (UserRegistry proxy + PermissionedResolver)
    └── User-owned Journey credential child (pre-created; issuer gets narrow record roles)
```

---

## 12. Permission invariants

Derived from product requirements + upstream `RegistryRolesLib` / `PermissionedResolver` (`authorizeTextRoles`, per-key `resource(node, partHash(key))`):

### Passport owner

* Owns the Passport name (ERC1155 / registry token).
* Controls wallet/address records and Passport text/data records.
* Controls child credential lifecycle (create/pre-create, revoke issuer grants).
* Holds admin roles needed to revoke issuer permissions.
* Must be able to transfer/revoke issuer `ROLE_SET_TEXT` (etc.) on the credential node.

### Nomadic platform

* May provision Passport under the platform parent (registrar on parent only as needed).
* After handoff, must **not** retain unrestricted Passport control.
* Any retained permission must be explicit, documented, and minimal (e.g. operational renew if required — undecided).

### Journey issuer

* Must **not** own the Passport token.
* Must **not** transfer names / hold `ROLE_CAN_TRANSFER_ADMIN` on Passport.
* Must **not** replace resolvers (`ROLE_SET_RESOLVER`).
* Must **not** hold broad `ROLE_REGISTRAR` on the entire Passport registry.
* Must **not** create arbitrary sibling credentials.
* May update **only** explicitly allowlisted records on its own pre-created credential (prefer `PermissionedResolver.authorizeTextRoles` / per-key resources, not blanket `ROLE_SET_TEXT` on the whole node unless unavoidable).

### Implementation lean (still to validate in next slice)

* `VerifiableFactory` → `UserRegistry` proxy per Passport (and possibly per credential registry if needed).
* `PermissionedResolver` proxy for record permissions.
* Pre-create credential child; grant issuer narrow record roles only.
* Prefer token-scoped roles over `ROOT_RESOURCE` grants inside the Passport registry.

---

## 13. Risks and unknowns

1. **Parent name ownership unknown** — do not assume `nomadic.eth` or any specific parent is available.
2. **ENSv2 preview surface is moving** — older Sepolia deployment folder differs; always re-pin + re-verify bytecode.
3. **`docs/` tracking fixed in scaffold** — `.gitignore` no longer ignores `docs/`.
4. **No broadcast safety harness yet** — current `Counter.s.sol` uses unconditional `vm.startBroadcast()`.
5. **Permission model nuance** — issuer may need credential-node `ROLE_SET_TEXT` vs only per-key authorization; confirm against `PermissionedResolver.t.sol` before coding.
6. **Hierarchy depth** — whether credential gets its own `UserRegistry` subregistry vs only a label under the Passport registry is still open.
7. **Platform handoff** — exact role bitmap to grant/revoke at Passport transfer needs a checklist test.
8. **World / off-chain eligibility** — out of scope for contracts repo; issuer key management TBD.
9. **Frontend/backend repos** — must not be modified in this stream; address consumption strategy for apps comes later.
10. **Branch not on remote** — `lisboa2026` exists only locally until an explicit push is requested.
11. **Fhenix/zkEVM legacy compile coupling** — keep compiling, but isolate ENSv2 tests so legacy warnings do not block Lisbon work.
12. **Private key UX** — prefer Foundry keystore / env; avoid README-style CLI `--private-key` echo risk.

---

## 14. Exact next implementation slice

**Slice name:** `ensv2-passport-scaffold` (read-only + local tests; still no Sepolia broadcasts)

Ship only:

1. Adjust `.gitignore` so `docs/CONTRACTS_PROJECT_CONTEXT.md` (and future Lisbon docs) can be committed; keep `.env` ignored.
2. Add pinned submodule `lib/ens-contracts-v2` @ `48b3e2d…` (re-verify tip if newer).
3. Add `addresses/sepolia.ensv2.json` generated from upstream pin (addresses only; or addresses+ABI paths).
4. Add `.env.example` with the variable names above.
5. Add Foundry remappings / `fs_permissions` needed to read pinned artifacts.
6. Add **dry-run** scripts under `script/ensv2/`:
   * chain-id assertion helper;
   * resolve parent name / registry via UniversalResolver or registry walk (read-only);
   * simulate Passport `UserRegistry` + `PermissionedResolver` proxy deployment via `VerifiableFactory` **without** broadcast.
7. Add forge tests under `test/ensv2/` that fork Sepolia (or use upstream deploy fixtures) and assert permission invariants:
   * issuer cannot transfer Passport;
   * issuer cannot set Passport resolver;
   * issuer cannot register arbitrary siblings if not granted registrar;
   * issuer can set only allowlisted text keys on the credential node.
8. Document operator runbook: required env, parent prerequisites, explicit broadcast flag.

**Out of scope for that slice:** mainnet, frontend/backend changes, real name creation on shared parents, ABI hand-copies without pin provenance, mnemonic files.

---

## Activation checklist (this pass)

* [x] Remote verified as Nomadic contracts repo
* [x] Uncommitted work preserved (none present)
* [x] `lisboa2026` activated from `main` @ `a867758…`
* [x] Branch not pushed
* [x] Toolchain / contracts audited
* [x] Baseline `forge build` / `forge test` validated
* [x] Upstream ENSv2 strategy decided (Option A)
* [x] Sepolia addresses recorded + bytecode checked
* [x] Context doc written
* [ ] ENSv2 prototype implementation — **not started**
