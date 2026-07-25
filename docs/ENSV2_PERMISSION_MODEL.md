# ENSv2 Permission Model

## Official primitives used

* `PermissionedResolver.authorizeTextRoles(name, key, account, grant)`
* `PermissionedResolverLib.ROLE_SET_TEXT` / `ROLE_SET_TEXT_ADMIN`
* Per-key resource: `resource(node, partHash(key))`
* Unauthorized `setText` reverts with  
  `EACUnauthorizedAccountRoles(resource(node, 0), ROLE_SET_TEXT, caller)`  
  selector `0x4b27a133` when the caller lacks both per-key and any-name part roles.

`grantRoles` / `revokeRoles` on `PermissionedResolver` are disabled; use authorize helpers only.

## Issuer allowlist

Authorized credential text keys:

* `com.nomadic.status`
* `com.nomadic.issuedAt`
* `com.nomadic.expiresAt`
* `com.nomadic.metadata`

## Issuer denylist (must fail)

* `addr` / address records
* `avatar`, `url`
* `contenthash`
* `com.nomadic.type`
* `com.nomadic.issuer`
* `com.nomadic.journey`
* `com.nomadic.policy`
* `com.nomadic.credentials`
* resolver replacement
* Passport / credential transfer
* sibling credential registration
* self-grant of additional permissions
* resolver upgrade
* `clearRecords`

## Broad-role safety

Issuer must never receive:

* Passport registry root roles (`ROLE_REGISTRAR`, upgrade, set-parent, etc.)
* `ROLE_CAN_TRANSFER_ADMIN` on Passport or credential
* resolver-admin / upgrade / clear / blanket `ROLE_SET_TEXT` root roles

Regression coverage: `test_issuerHasNoBroadRoles_regression`.

## Revocation

1. User grants exact key authorization.
2. Issuer updates allowed key.
3. User calls `authorizeTextRoles(..., false)`.
4. Issuer write reverts with `EACUnauthorizedAccountRoles`.
5. User can still write; sibling allowlisted keys remain usable until revoked.

## Transfer behavior (documented, not enforced as product policy yet)

Local tests show **external PermissionedResolver text authorizations survive** Passport or credential ERC1155 transfers.

**Safest recommendation for production:**

* revoke issuer text authorizations before transfer; or
* transfer through a helper that revokes first.

Covered by:

* `test_transferPassport_externalResolverPermissionsSurvive`
* `test_transferCredential_externalResolverPermissionsSurvive`
* `test_recommendation_revokeBeforeTransfer`
