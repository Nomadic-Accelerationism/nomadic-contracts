# ENSv2 Explorer-r2 — Stage 4 + Stage 5 Final Verification Report

**Network:** Ethereum Sepolia (`11155111`)  
**Profile:** `explorer-v1-r2`  
**Verification time:** 2026-07-25 (live RPC reads; Stage 5B = simulation only)  

| Actor | Address |
|-------|---------|
| Magic Passport owner | `0xd114FA765bA4811219AAe364c93CE8A81Ad39B17` |
| Lisbon House issuer | `0x3505b68444Db0E71987090769e5283AfC0efBd62` |
| Passport PermissionedResolver | `0x467B72a46F578a47878137883Ce35c980393Bffe` |
| Passport UserRegistry | `0x40776D16B117b04FD5C08458E14ff8CF6518a40E` |
| Nomadic parent registry | `0x8fB12e7Ab9B192503d7d02a43e0507c484e27280` |
| Credential | `lisbon-house.victor.nomadic-passport.eth` |
| Credential node | `0x6ad2126ebdb620e0dedc9df67cbb3256d7d948d91f24db92ab3ede1a419e7142` |

**Final result:**

```text
STAGE 4 VERIFIED
STAGE 5A VERIFIED
ISSUER PERMISSIONS REVOKED
STAGE 5B VERIFIED
POST-REVOCATION WRITE REJECTED
```

No cleanup required. Stage 5B did **not** broadcast any transaction.

---

## 1. Stage 4 — allowed issuer write

| Field | Value |
|-------|-------|
| Tx | `0xc68d0d43654778054c5d5b2ac55f9b81ad1243167289c261983fcc3516f3992c` |
| Sender | Issuer `0x3505b684…efBd62` |
| Target | PermissionedResolver `0x467B72a4…93Bffe` |
| Function | `setText(bytes32,string,string)` selector `0x10f13a8c` |
| Args | node = credential node; key = `com.nomadic.metadata`; value = `issuer-demo-stage4-verified` |
| Receipt status | `1` |
| Block | `11350501` (`0xad31e5`) |
| Gas used | `70867` (`0x114d3`) |
| Issuer nonce | `0 → 1` |

### Metadata before / after Stage 4

| Moment | `com.nomadic.metadata` |
|--------|------------------------|
| Before | `""` (empty) |
| After | `issuer-demo-stage4-verified` |

### Stage 4 protected type-write simulation (not broadcast)

Issuer `eth_call`:

```solidity
setText(credentialNode, "com.nomadic.type", "tampered")
```

**Reverted** with:

```text
EACUnauthorizedAccountRoles(
  resource(credentialNode, 0) = 0x1d37577f6ac0e47f13e2369f81a14d5bd55e540e4677b210b0bf1c3f1f7af9b6,
  ROLE_SET_TEXT = 16,
  account = 0x3505b68444Db0E71987090769e5283AfC0efBd62
)
```

Selector `0x4b27a133`.  
`com.nomadic.type` remained `journey-eligibility`.

---

## 2. Stage 5A — Magic revocation

| Field | Value |
|-------|-------|
| Tx | `0x9bb61d2b31b38a28573dfd4cf970a661c38befe0002482f4b4d9a8504f69e801` |
| Sender | Magic `0xd114FA765bA4811219AAe364c93CE8A81Ad39B17` |
| Target | PermissionedResolver `0x467B72a46F578a47878137883Ce35c980393Bffe` |
| Outer function | `multicall(bytes[])` selector `0xac9650d8` |
| Receipt status | `1` |
| Block | `11350959` (`0xad33af`) |
| Gas used | `107072` (`0x1a240`) |
| Magic nonce | `7` |
| Logs | 4 (one per revoke) |
| `setText` / record writes | **none** (no `0x10f13a8c` in calldata) |

### Decoded four inner calls

DNS-encoded credential name (all four):

```text
0x0c6c6973626f6e2d686f75736506766963746f72106e6f6d616469632d70617373706f72740365746800
= lisbon-house.victor.nomadic-passport.eth
```

Issuer account (all four): `0x3505b68444Db0E71987090769e5283AfC0efBd62`  
`grant = false` (all four).

| # | Inner selector | Function | Key |
|--:|----------------|----------|-----|
| 0 | `0xf2d1eb25` | `authorizeTextRoles(bytes,string,address,bool)` | `com.nomadic.status` |
| 1 | `0xf2d1eb25` | `authorizeTextRoles(...)` | `com.nomadic.issuedAt` |
| 2 | `0xf2d1eb25` | `authorizeTextRoles(...)` | `com.nomadic.expiresAt` |
| 3 | `0xf2d1eb25` | `authorizeTextRoles(...)` | `com.nomadic.metadata` |

Exactly **four** inner calls. No other functions.

---

## 3. Issuer role resources — before and after revocation

`ROLE_SET_TEXT = 1 << 4 = 0x10`  
Resource ID = `keccak256(abi.encode(credentialNode, keccak256(key)))`

| Key | Resource ID | Before Stage 5A | After Stage 5A |
|-----|-------------|----------------:|---------------:|
| `com.nomadic.status` | `0xd954aa9090964a494142c9cd106c869b0df05ee6c86eb57c545de1f1d8939c19` | `0x10` | `0x0` |
| `com.nomadic.issuedAt` | `0x81c5f13ac823df263546b5a7dd735e7e3801b6256b6b74566305bf87680eb761` | `0x10` | `0x0` |
| `com.nomadic.expiresAt` | `0xf96114844050d7564cac0a8ad2bcb518af9c140ff9a6e05c2249781210b2f1d8` | `0x10` | `0x0` |
| `com.nomadic.metadata` | `0x67e70b959565375779e17f67e5889af208bdd5d4e0f52917fce3870d09ec6cac` | `0x10` | `0x0` |

---

## 4. Broader permissions absent (post-revocation)

All of the following issuer probes returned **roles = 0** or **hasRootRoles = false**:

| Probe | Result |
|-------|--------|
| Credential name-wide `resource(node, 0)` | `0` |
| Passport name-wide `resource(passportNode, 0)` | `0` |
| Zero resource / node-as-resource | `0` |
| Empty-key / wildcard text key `""` | `0` |
| Protected: `type`, `issuer`, `journey`, `policy` | `0` |
| Extra texts: `avatar`, `url`, `email` | `0` |
| `addr` coinType-60 resource | `0` |
| Resolver root: `SET_ADDR`, `SET_TEXT`, `SET_CONTENTHASH`, `CLEAR`, `SET_DATA`, `UPGRADE`, admins | `false` |
| Passport registry root registrar-style bits | `false` |

Confirmed: issuer has no credential name-wide role, root role, wildcard/empty-key role, Passport registrar role, resolver administration role, role-administration role, or permissions on protected keys / addr / contenthash.

---

## 5. Stage 5B — post-revocation issuer write simulation

**Not broadcast.** Read-only `eth_call` / `cast call --from` issuer:

```solidity
setText(
  0x6ad2126ebdb620e0dedc9df67cbb3256d7d948d91f24db92ab3ede1a419e7142,
  "com.nomadic.metadata",
  "issuer-demo-after-revoke"
)
```

**Result:** revert (missing `ROLE_SET_TEXT`).

```text
selector: 0x4b27a133
error:    EACUnauthorizedAccountRoles(uint256,uint256,address)
args:
  resource = 0x1d37577f6ac0e47f13e2369f81a14d5bd55e540e4677b210b0bf1c3f1f7af9b6
             (= resource(credentialNode, 0))
  roles    = 16  (= ROLE_SET_TEXT)
  account  = 0x3505b68444Db0E71987090769e5283AfC0efBd62
```

After simulation, metadata still:

```text
com.nomadic.metadata = issuer-demo-stage4-verified
```

Issuer on-chain nonce remains `1` (Stage 4 write only; Stage 5B did not send a tx).

---

## 6. Final Passport and credential records

### Credential (`lisbon-house.victor.nomadic-passport.eth`)

| Key | Value |
|-----|-------|
| `com.nomadic.type` | `journey-eligibility` |
| `com.nomadic.issuer` | `0x3505b68444Db0E71987090769e5283AfC0efBd62` |
| `com.nomadic.journey` | `lisbon-house` |
| `com.nomadic.policy` | `lisbon_house_policy_v1` |
| `com.nomadic.status` | `active` |
| `com.nomadic.issuedAt` | `1785012002` |
| `com.nomadic.expiresAt` | `""` |
| `com.nomadic.metadata` | `issuer-demo-stage4-verified` |

### Ownership and hierarchy (unchanged)

| Check | Live |
|-------|------|
| Passport owner (`victor` on Nomadic registry) | Magic |
| Credential owner (`lisbon-house` on Passport registry) | Magic |
| Passport / credential resolver | `0x467B72a46F578a47878137883Ce35c980393Bffe` |
| Passport subregistry | Passport UserRegistry `0x40776D16…` |
| Credential subregistry | `address(0)` |
| Passport registry parent | Nomadic registry `0x8fB12e7A…` / label `victor` |
| Credential node | `0x6ad2126e…419e7142` (not the broken frontend node) |

---

## 7. Universal Resolver agreement

Top / Managed / Direct Explorer-r2 URs all agree with the PermissionedResolver for all eight credential texts, and return:

| UR | Address | Credential owner | Passport owner | Passport canonical registry | Credential resolver / node |
|----|---------|------------------|----------------|-----------------------------|----------------------------|
| Top | `0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe` | Magic | Magic | `0x40776D16…` | PermissionedResolver / credential node |
| Managed | `0x6d80F2172CFdEc5730fE683860C33d26fC42e6F1` | Magic | Magic | `0x40776D16…` | same |
| Direct | `0x2F8A180604c42457Cb56C7c4f708748fF1F91DF1` | Magic | Magic | `0x40776D16…` | same |

No discrepancy between direct resolver and UR paths.

---

## 8. Cleanup

| Item | Assessment |
|------|------------|
| Stage 4 write | Intended demo write — keep |
| Stage 5A revocation | Intended — keep |
| Stage 5B | Simulation only — no state change |
| Wrong-node / PII / broader perms | None |
| Cleanup actions | **None required** |

---

## 9. Final result

```text
STAGE 4 VERIFIED
STAGE 5A VERIFIED
ISSUER PERMISSIONS REVOKED
STAGE 5B VERIFIED
POST-REVOCATION WRITE REJECTED
```

Demo arc complete on Sepolia Explorer-r2:

1. Issuer wrote allowed metadata (Stage 4).  
2. Magic revoked the four text roles (Stage 5A).  
3. Issuer post-revocation metadata write reverts (Stage 5B).  
4. Credential records and ownership remain intact.
