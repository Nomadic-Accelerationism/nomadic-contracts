# ENSv2 Permission Demo Plan (Lisbon House)

Exact scoped-permission + revocation sequence for the Sepolia Passport preflight.

**Do not broadcast.** Verified on Sepolia fork via `script/ensv2/06_SimulateIssuanceFork.s.sol`.

## Contracts / roles (pinned PermissionedResolver)

From `PermissionedResolverLib`:

| Constant | Value |
| --- | --- |
| `ROLE_SET_TEXT` | `1 << 4` |
| `ROLE_SET_TEXT_ADMIN` | `ROLE_SET_TEXT << 128` |

Authorization API (only path; direct `grantRoles` disabled on resolver):

```solidity
PermissionedResolver.authorizeTextRoles(
  bytes calldata toName,   // DNS-encoded credential name
  string calldata key,     // exact text key
  address account,         // issuer
  bool grant               // true=grant, false=revoke
)
```

Mechanics:

* Admin check on `resource(node, 0)` for `ROLE_SET_TEXT` grant/revoke.
* Per-key grant stored on `resource(node, partHash(key))` with bit `ROLE_SET_TEXT`.
* Unauthorized `setText` reverts `EACUnauthorizedAccountRoles(resource(node,0), ROLE_SET_TEXT, caller)` (selector `0x4b27a133`).

## Allowlist (issuer may receive)

Grant **only** these keys on the credential DNS name
`lisbon-house.victor.nomadic-passport.eth`:

1. `com.nomadic.status`
2. `com.nomadic.issuedAt`
3. `com.nomadic.expiresAt`
4. `com.nomadic.metadata`

Example (signer = Passport user / resolver admin):

```text
authorizeTextRoles(credentialDns, "com.nomadic.status", ISSUER, true)
authorizeTextRoles(credentialDns, "com.nomadic.issuedAt", ISSUER, true)
authorizeTextRoles(credentialDns, "com.nomadic.expiresAt", ISSUER, true)
authorizeTextRoles(credentialDns, "com.nomadic.metadata", ISSUER, true)
```

Do **not** grant:

* blanket root `ROLE_SET_TEXT`
* contract-wide registrar roles
* `addr` / avatar / url / contenthash permissions
* `com.nomadic.type` / `issuer` / `journey` / `policy`
* resolver / subregistry / ownership / transfer / role-admin powers

If `LISBON_HOUSE_ISSUER_ADDRESS == NOMADIC_PARENT_OWNER_ADDRESS`, flag that the demo is clearer with a distinct issuer account.

## Demo sequence

Assumes Passport + credential already issued; user owns both; issuer allowlisted.

| Step | Signer | Action | Expected |
| --- | --- | --- | --- |
| 1 | Issuer | `setText(credentialNode, "com.nomadic.status", "renewed")` | succeeds |
| 2 | Issuer | `setText(..., "com.nomadic.type", "hack")` | reverts `EACUnauthorizedAccountRoles` |
| 3 | **User** | `authorizeTextRoles(credentialDns, "com.nomadic.status", issuer, false)` | succeeds |
| 4 | Issuer | `setText(..., "com.nomadic.status", "should-fail")` | reverts |
| 5 | — | Check `ownerOf` Passport + credential | still `PASSPORT_OWNER_ADDRESS` |

### Who must sign revocation?

**The Passport user** (resolver admin on the PermissionedResolver), **not** the platform.

After ownership/admin handoff to the Magic wallet, the platform cannot revoke text roles unless it retained `ROLE_SET_TEXT_ADMIN` on the credential node resource — which this issuance plan intentionally does **not** grant to the platform.

## Transfer caveat

Local invariant tests show external text authorizations **survive** ERC-1155 transfers of Passport/credential tokens.

Production recommendation: revoke issuer keys **before** any ownership transfer (`test_recommendation_revokeBeforeTransfer`).

## Gas (demo portion)

Issuer status update + user revoke are small relative to issuance (~tens of thousands of gas each). Issuer needs Sepolia ETH only for the demo write.

## Commands

```bash
# Full issuance + permission demo on Sepolia fork (no broadcast)
forge script script/ensv2/06_SimulateIssuanceFork.s.sol --fork-url "$SEPOLIA_RPC_URL" -vv

# Local invariant suite
forge test --match-path 'test/ensv2/PermissionInvariants.t.sol' -vvv
```
