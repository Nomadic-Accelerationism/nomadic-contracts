# ENSv2 Magic Transaction Bundle

The Magic wallet controls every operation after the platform mints `victor` directly to it.

Expected signer:

```text
0xd114FA765bA4811219AAe364c93CE8A81Ad39B17
```

No private key is required by the generator or stored in the repository.

## Prerequisites

1. ENS routing confirmation received.
2. Explorer-r2 routing guard passes.
3. Nomadic registry parent link configured.
4. Platform issuance completed.
5. Passport contracts match the deterministic factory addresses.
6. A real Lisbon issuer address is supplied and differs from platform and Magic.
7. Magic wallet funded with Sepolia ETH.

## Deterministic destinations

For the confirmed platform and fixed execution salts:

```text
Passport UserRegistry:
0x40776D16B117b04FD5C08458E14ff8CF6518a40E

Passport PermissionedResolver:
0x467B72a46F578a47878137883Ce35c980393Bffe
```

The generator verifies factory provenance if these contracts are already deployed.

## Generate JSON

```bash
ENSV2_DEPLOYMENT_PROFILE=explorer-v1-r2 \
NOMADIC_PARENT_OWNER_ADDRESS=0xca490deA7D7D79Bac4537D5Fe68fF10cd9c7EbEd \
PASSPORT_OWNER_ADDRESS=0xd114FA765bA4811219AAe364c93CE8A81Ad39B17 \
LISBON_HOUSE_ISSUER_ADDRESS=<distinct-real-issuer> \
ENSV2_ISSUED_AT=<runtime-unix-timestamp> \
ENSV2_BROADCAST=false \
forge script script/ensv2/10_BuildMagicBundleExplorerR2.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" -vv
```

The final log line is frontend-consumable JSON:

```json
{
  "chainId": 11155111,
  "deploymentProfile": "explorer-v1-r2",
  "passport": "victor.nomadic-passport.eth",
  "expectedSigner": "0xd114FA765bA4811219AAe364c93CE8A81Ad39B17",
  "issuer": "<runtime issuer>",
  "passportRegistry": "0x40776D16B117b04FD5C08458E14ff8CF6518a40E",
  "passportResolver": "0x467B72a46F578a47878137883Ce35c980393Bffe",
  "issuedAt": "<runtime timestamp>",
  "calls": [
    {
      "label": "Configure Passport registry parent",
      "to": "0x40776D16B117b04FD5C08458E14ff8CF6518a40E",
      "data": "0x...",
      "value": "0"
    }
  ]
}
```

## Ordered calls

| # | Target | Operation |
| ---: | --- | --- |
| 1 | Passport registry | `setParent(NomadicRegistry, "victor")` |
| 2 | Passport resolver | `setAddr(passportNode, Magic)` |
| 3–6 | Passport resolver | Passport text records |
| 7 | Passport registry | register `lisbon-house` directly to Magic |
| 8–15 | Passport resolver | credential text records |
| 16–19 | Passport resolver | four per-key issuer authorizations |

All values are zero ETH.

The frontend must:

1. require chain ID `11155111`;
2. verify connected account equals `expectedSigner`;
3. preserve call order;
4. stop immediately on any failed call;
5. re-read ownership and records through the top Universal Resolver after completion.

## Issuer permission demo calls

Allowed issuer update:

```solidity
setText(credentialNode, "com.nomadic.status", "renewed")
```

Forbidden proof:

```solidity
setText(credentialNode, "com.nomadic.type", "hack")
```

Expected result: `EACUnauthorizedAccountRoles`.

Magic revocation:

```solidity
authorizeTextRoles(
    credentialDns,
    "com.nomadic.status",
    issuer,
    false
)
```

The issuer's next status update must revert.

## Sponsorship constraints

The 19 calls are suitable for future batching, but a relayer cannot simply replace the signer:
resolver and registry permissions depend on `msg.sender`.

Sponsorship requires a wallet/paymaster or delegated execution design that retains Magic as the
authorized account. Re-run ERC-1155 compatibility checks before enabling any EIP-7702 delegation.
