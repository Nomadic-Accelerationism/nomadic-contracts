# ENSv2 Explorer-r2 — Stage 3 Final Verification Report

**Network:** Ethereum Sepolia (`11155111`)  
**Profile:** `explorer-v1-r2`  
**Verification time:** 2026-07-25 (live RPC reads; Blockscout tx enumeration)  
**Signer (Magic):** `0xd114FA765bA4811219AAe364c93CE8A81Ad39B17`  
**Bundle `issuedAt`:** `1785012002`  

**Final result: `STAGE 3 VERIFIED WITH HARMLESS EXTRA TX`**

Do not execute Stage 4, issuer writes, or revocation.

---

## 1. Total Stage 3 transaction attempts

Magic nonce advanced `0 → 7` during Stage 3. Blockscout lists **7** successful Magic txs to the Passport registry / PermissionedResolver in blocks `11350310–11350356`.

| # | Nonce | Hash | Block | Gas | Target | Selector | Group | Bundle match | Role |
|---|------:|------|------:|----:|--------|----------|------:|:------------:|------|
| A | 0 | `0x4961dbbc7580f125348ee8670cad91465fe13a0b5369f198e780f30bc86bd3c7` | 11350310 | 87444 | Passport registry | `0x5357263f` setParent | **1** | exact | **Canonical** |
| B | 1 | `0x5100e857f676638c5be76a3ab5c7639d1691375afd84cd0580f05cf6433854c8` | 11350313 | 329611 | PermissionedResolver | `0xe32954eb` multicallWithNodeCheck | **2** | exact | **Canonical** (first write) |
| C | 2 | `0xa857a8783e2df02c79796b2c3f3b9a0f1e395ddc34049a9e9a43e4ce6c2979e1` | 11350315 | 130887 | PermissionedResolver | `0xe32954eb` multicallWithNodeCheck | **2** | exact | **Redundant rewrite** (harmless) |
| D | 3 | `0xf6a53888a1361b825aaf8218c7acfdbe0f15a493c67f01b6732dc8cf7071d595` | 11350329 | 178324 | Passport registry | `0x85f3e643` register | **3** | exact | **Canonical** |
| E | 4 | `0x6730aec958bfc32b10de62a735025dd95b8f683991537709721ce6fd118b61fa` | 11350347 | 328682 | PermissionedResolver | `0xe32954eb` multicallWithNodeCheck | **4** | exact | **Canonical** (first write) |
| F | 5 | `0x8f12865d876c9b11ddb1644f7fa4ae7d4037c5f225184bf417335d62afed6023` | 11350349 | 169620 | PermissionedResolver | `0xe32954eb` multicallWithNodeCheck | **4** | exact | **Redundant rewrite** (harmless) |
| G | 6 | `0xb8fc4cbdfbdc8cb6eef5b6350611d9c9ddd19fdf63bc52aec94d76f4f43c35d8` | 11350356 | 287120 | PermissionedResolver | `0xac9650d8` multicall | **5** | exact | **Canonical** |

All seven receipts: **status 1 (success)**.  
Sender for all: Magic `0xd114…`.  
No Magic / issuer / platform txs after block `11350356` (Stage boundary clean).

Stage 3 is therefore **not** “five on-chain transactions”; it is **seven successful attempts**, of which **five are canonical** and **two are identical redundant rewrites**.

---

## 2. Canonical transaction per reviewed group

| Group | Label | Canonical tx |
|------:|-------|--------------|
| 1 | Configure Passport registry parent | `0x4961dbbc7580f125348ee8670cad91465fe13a0b5369f198e780f30bc86bd3c7` |
| 2 | Set Passport records | `0x5100e857f676638c5be76a3ab5c7639d1691375afd84cd0580f05cf6433854c8` |
| 3 | Register Lisbon credential | `0xf6a53888a1361b825aaf8218c7acfdbe0f15a493c67f01b6732dc8cf7071d595` |
| 4 | Set credential records | `0x6730aec958bfc32b10de62a735025dd95b8f683991537709721ce6fd118b61fa` |
| 5 | Grant scoped issuer permissions | `0xb8fc4cbdfbdc8cb6eef5b6350611d9c9ddd19fdf63bc52aec94d76f4f43c35d8` |

Superseded / duplicate (same calldata, same node, lower gas = warm SSTORE):

- Group 2: `0xa857a878…` after `0x5100e857…`
- Group 4: `0x8f12865d…` after `0x6730aec9…`

---

## 3. Full analysis of `0xa857a8783e2df02c79796b2c3f3b9a0f1e395ddc34049a9e9a43e4ce6c2979e1`

| Field | Value |
|-------|-------|
| Intended group | 2 — Set Passport records |
| Sender | `0xd114FA765bA4811219AAe364c93CE8A81Ad39B17` |
| Target | `0x467B72a46F578a47878137883Ce35c980393Bffe` |
| Function | `multicallWithNodeCheck(bytes32 nodehash, bytes[] data)` |
| Node / namehash | `0xc60a6d215c6da5d140152c60f32f60a6946efca7aebd26f39ff66018886a2834` = `namehash(victor.nomadic-passport.eth)` |
| Bundle match | Exact match to reviewed Group 2 calldata |
| Block | 11350315 |
| Receipt | status **1** |
| Gas used | 130887 (vs 329611 on the prior identical write — consistent with warm storage) |
| Logs | 6 events; every `topics[1]` node = passport node above |

### Inner calls (decoded)

1. `setAddr(passportNode, 0xd114…)`
2. `setText(passportNode, "com.nomadic.type", "passport")`
3. `setText(passportNode, "com.nomadic.profile", "https://nomadic-front-rosy.vercel.app/p/victor.nomadic-passport.eth")`
4. `setText(passportNode, "com.nomadic.currentJourney", "lisbon-house")`
5. `setText(passportNode, "com.nomadic.credentials", "lisbon-house.victor.nomadic-passport.eth")`

### Misdirection / cleanup?

| Check | Result |
|-------|--------|
| Wrong frontend node `0x86ee…` written? | **No** — empty on resolver |
| `nomadic-passport.eth` node polluted? | **No** |
| `lisbon-house.victor…` node polluted by this tx? | **No** (logs only passport node) |
| `bytes32(0)` polluted? | **No** |
| Unwanted PII keys? | **No** |
| Classification | **Harmless redundant rewrite** of the correct Passport node (identical to prior canonical Group 2 tx `0x5100e857…`) |

UI postcondition failure after this tx was a **frontend namehash bug** (read wrong node), not an on-chain miss. No cleanup required.

---

## 4. Namehashes

| Name | namehash |
|------|----------|
| `victor.nomadic-passport.eth` | `0xc60a6d215c6da5d140152c60f32f60a6946efca7aebd26f39ff66018886a2834` |
| `lisbon-house.victor.nomadic-passport.eth` | `0x6ad2126ebdb620e0dedc9df67cbb3256d7d948d91f24db92ab3ede1a419e7142` |
| `nomadic-passport.eth` (parent) | `0x82c52101cd66c2c2122c4cc36d1017d1ad2b68f573b06c48951a824e6d562f9b` |
| Broken frontend node (historical) | `0x86ee08d08dc976a172e361396955cc752bd4328e943d606781a832ea0cc0b2fb` — **empty / unused** |

---

## 5. Passport hierarchy (live)

| Check | Expected | Live | OK |
|-------|----------|------|:--:|
| Passport `getParent` registry | `0x8fB12e7Ab9B192503d7d02a43e0507c484e27280` | same | ✓ |
| Passport `getParent` label | `victor` | `victor` | ✓ |
| `victor` owner (Nomadic registry) | Magic `0xd114…` | same | ✓ |
| `victor` subregistry | `0x40776D16B117b04FD5C08458E14ff8CF6518a40E` | same | ✓ |
| `victor` resolver | `0x467B72a46F578a47878137883Ce35c980393Bffe` | same | ✓ |
| Platform has Passport `ROLE_REGISTRAR` | false | false | ✓ |
| Magic has Passport `ROLE_REGISTRAR` | true (needed for credential register) | true | ✓ |
| Issuer has Passport `ROLE_REGISTRAR` | false | false | ✓ |

---

## 6. Passport records — direct PermissionedResolver

Read on `0x467B72a46F578a47878137883Ce35c980393Bffe` at passport node:

| Key | Expected | Live | OK |
|-----|----------|------|:--:|
| `addr` | `0xd114…` | `0xd114…` | ✓ |
| `com.nomadic.type` | `passport` | `passport` | ✓ |
| `com.nomadic.profile` | `https://nomadic-front-rosy.vercel.app/p/victor.nomadic-passport.eth` | same | ✓ |
| `com.nomadic.currentJourney` | `lisbon-house` | `lisbon-house` | ✓ |
| `com.nomadic.credentials` | `lisbon-house.victor.nomadic-passport.eth` | same | ✓ |
| PII / World / email / age / nationality / document / selfie / nullifier | absent | all `""` | ✓ |
| `contenthash` | empty | `0x` | ✓ |

Contamination (same resolver): parent node, wrong node `0x86ee…`, and `bytes32(0)` all have empty addr/texts for the Passport keys.

---

## 7. Passport records — Universal Resolver path

`resolve(dnsName, text/addr calldata)` agrees with direct reads on all three Explorer-r2 URs:

| UR | Role | Passport `addr` | Passport `type` | Other passport texts |
|----|------|-----------------|-----------------|----------------------|
| `0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe` | Top | Magic | `passport` | match |
| `0x6d80F2172CFdEc5730fE683860C33d26fC42e6F1` | Managed (= top implementation) | Magic | `passport` | match |
| `0x2F8A180604c42457Cb56C7c4f708748fF1F91DF1` | Direct Explorer-r2 (= managed implementation) | Magic | `passport` | match |

Also: `findOwner` / `findResolver` / `findExactRegistry` for the Passport name return Magic / PermissionedResolver / Passport UserRegistry on all three.

No discrepancy between direct resolver and UR paths for Passport records.

---

## 8. Lisbon credential

| Check | Live | OK |
|-------|------|:--:|
| Owner (`findOwner("lisbon-house")` on Passport registry) | Magic `0xd114…` | ✓ |
| Node | `0x6ad2126e…419e7142` | ✓ |
| Direct texts | type `journey-eligibility`; issuer `0x3505…`; journey `lisbon-house`; policy `lisbon_house_policy_v1`; status `active`; issuedAt `1785012002`; expiresAt `""`; metadata `""` | ✓ |
| Forbidden claim words (accepted/approved/resident/attended/identity/citizenship/age/nationality) | not present | ✓ |
| Credential `addr` | zero (not set; expected) | ✓ |

UR path: all three URs return the same eight credential text values as the direct resolver.  
`findExactRegistry` for the credential name is `address(0)` on URs (leaf has no subregistry) while `findOwner` is Magic — consistent with `register(..., subregistry=0, ...)`.

---

## 9. Issuer permissions

Issuer: `0x3505b68444Db0E71987090769e5283AfC0efBd62`  
`ROLE_SET_TEXT = 1 << 4 = 0x10`

| Key | Resource ID (`keccak256(abi.encode(credentialNode, keccak256(key)))`) | `roles` | SET_TEXT |
|-----|---------------------------------------------------------------------|---------|:--------:|
| `com.nomadic.status` | `0xd954aa9090964a494142c9cd106c869b0df05ee6c86eb57c545de1f1d8939c19` | `0x10` | ✓ |
| `com.nomadic.issuedAt` | `0x81c5f13ac823df263546b5a7dd735e7e3801b6256b6b74566305bf87680eb761` | `0x10` | ✓ |
| `com.nomadic.expiresAt` | `0xf96114844050d7564cac0a8ad2bcb518af9c140ff9a6e05c2249781210b2f1d8` | `0x10` | ✓ |
| `com.nomadic.metadata` | `0x67e70b959565375779e17f67e5889af208bdd5d4e0f52917fce3870d09ec6cac` | `0x10` | ✓ |

Absent SET_TEXT (roles `0`) for protected / broader probes:

- Credential: `type`, `issuer`, `journey`, `policy`, `avatar`, `url`, `email`
- Passport node keys: `type`, `profile`, `currentJourney`, `credentials`
- Broader: empty-key resource on passport/credential/zero nodes; treating node itself as resource; issuer Passport registrar = false

Group 5 tx authorized exactly these four keys via `authorizeTextRoles(credentialDns, key, issuer, true)` inside `multicall`.

---

## 10. Resolver routing note

Live proxy chain:

- Top UR implementation → Managed UR  
- Managed UR implementation → Direct Explorer-r2 UR  

Stage 3 writes targeted only:

- Passport UserRegistry `0x40776D16…`  
- Passport PermissionedResolver `0x467B72a4…`  

No successful Stage 3 op used a non–Explorer-r2 “current-deployment” resolver. Final verification used Top / Managed / Direct Explorer-r2 URs plus the PermissionedResolver directly.

---

## 11. Stage boundary

| Action | Executed? |
|--------|:---------:|
| Stage 4 issuer write | **No** (issuer nonce 0; no issuer txs) |
| Magic revocation | **No** (no Magic txs after Group 5) |
| Issuer post-revocation | **No** |
| Extra txs after Group 5 | **No** |

---

## 12. Unintended state / cleanup

| Item | Assessment |
|------|------------|
| Extra Group 2 tx `0xa857…` | Harmless identical rewrite — **no cleanup** |
| Extra Group 4 tx `0x8f12865d…` | Harmless identical rewrite — **no cleanup** |
| Wrong-node writes | None found |
| PII records | None found |
| Broader issuer perms | None found |

---

## 13. Final result

### `STAGE 3 VERIFIED WITH HARMLESS EXTRA TX`

- Hierarchy, Passport records, credential records, issuer scopes, and Explorer-r2 Universal Resolver reads all match the reviewed bundle.  
- Seven Magic txs succeeded; five are canonical; two are redundant same-calldata rewrites (Groups 2 and 4).  
- The previously UI-failed Group 2 receipt `0xa857…` was a correct, harmless rewrite — not misdirected.  
- Stage 4 / revocation not executed. Cleanup not required and not performed.
