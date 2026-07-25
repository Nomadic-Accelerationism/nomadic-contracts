# ENSv2 Magic Transaction Bundle

The Magic wallet controls every operation after the platform mints `victor` directly to it.

Expected signer:

```text
0xd114FA765bA4811219AAe364c93CE8A81Ad39B17
```

No private key is required by the generator or stored in the repository.

## Counts are not equivalent

```text
19 logical contract operations
≠ 19 blockchain transactions
≠ 19 Magic confirmations
```

The default EOA plan keeps the 19 required state operations but packages them into **five**
transactions and therefore at most five wallet confirmation prompts. Strategy comparison and the
gated EIP-7702 path live in [`ENSV2_MAGIC_EXECUTION_STRATEGIES.md`](./ENSV2_MAGIC_EXECUTION_STRATEGIES.md).

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
  "logicalContractCalls": 19,
  "onchainTransactions": 5,
  "expectedMagicConfirmations": 5,
  "transactionGroups": [
    {
      "index": 1,
      "label": "Configure Passport registry",
      "expectedSigner": "0xd114FA765bA4811219AAe364c93CE8A81Ad39B17",
      "to": "0x40776D16B117b04FD5C08458E14ff8CF6518a40E",
      "targets": ["0x40776D16B117b04FD5C08458E14ff8CF6518a40E"],
      "data": "0x...",
      "calldata": "0x...",
      "value": "0",
      "atomic": true,
      "estimatedGas": 76565,
      "preconditions": ["Passport registry deployed; Magic owns victor"],
      "postconditions": ["Passport registry canonical parent is Nomadic registry"],
      "calls": [
        {
          "label": "Configure Passport registry parent",
          "to": "0x40776D16B117b04FD5C08458E14ff8CF6518a40E",
          "data": "0x...",
          "value": "0"
        }
      ]
    }
  ]
}
```

## Five-transaction EOA plan

| Tx | Logical calls | Target | Outer function | Gas estimate |
| ---: | ---: | --- | --- | ---: |
| 1 | 1 | Passport registry | `setParent` | `76,565` |
| 2 | 5 | Passport resolver | `multicallWithNodeCheck` | `305,394` |
| 3 | 1 | Passport registry | `register` | `162,012` |
| 4 | 8 | Passport resolver | `multicallWithNodeCheck` | `304,997` |
| 5 | 4 | Passport resolver | `multicall` | `267,596` |

Total measured Magic gas: `1,116,564`.

All values are zero ETH.

The historical resolver implements both multicalls. Internally it uses `delegatecall`, preserving
Magic as `msg.sender`, and reverts the entire group on the first failed inner call. Its
`multicallWithNodeCheck` node parameter is explicitly ignored by the historical implementation;
security still comes from each inner setter's own role check. The frontend must therefore validate
every inner calldata item and expected node.

The two registry operations cannot be included in resolver multicalls because they target the
Passport UserRegistry. The credential record and authorization batches must follow credential
registration to avoid pre-seeding records for a name that does not yet exist.

The frontend must:

1. require chain ID `11155111`;
2. verify connected account equals `expectedSigner`;
3. preserve call order;
4. stop immediately on any failed call;
5. re-read ownership and records through the top Universal Resolver after completion.

## Classification of all 19 logical operations

| Calls | Signer | Category | Dependency | Native batching |
| --- | --- | --- | --- | --- |
| 1 | Magic | Passport registry parent | Passport mint completed | no registry multicall |
| 2–6 | Magic | Passport addr + text | parent link first | one atomic resolver multicall |
| 7 | Magic | credential registration | Passport registrar permission | separate registry tx |
| 8–15 | Magic | credential text | credential registered | one atomic resolver multicall |
| 16–19 | Magic | issuer authorization | records initialized; issuer known | one atomic resolver multicall |

All resolver batches preserve `msg.sender == Magic`. Global atomicity across all five transactions
is intentionally not required in the default EOA strategy. If a later group fails, the frontend
can verify prior postconditions and safely retry from the failed group.

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

Revocation remains a separate Magic demo transaction and is not part of the five initial setup
transactions. Offboarding all four issuer keys could itself use `multicall`, but the status-only
demo intentionally makes one explicit revocation.

## Optional Magic/Alchemy EIP-7702 path

The current Magic smart-account extension is powered by Alchemy's EIP-7702 infrastructure.
Alchemy currently documents one supported delegation implementation:

```text
SemiModularAccount7702
0x69007702764179f14F51cdce752f4f775d74E139
```

Sepolia runtime checks confirm it advertises `IERC1155Receiver` (`0x4e2312e0`). A fork rehearsal
installed the exact `0xef0100 || implementation` designator on the real Magic address before
Passport minting and proved:

* Passport ERC-1155 mint succeeds while delegated;
* `executeBatch` executes all five groups atomically in one transaction;
* credential ERC-1155 mint succeeds while delegated;
* registry/resolver targets still observe Magic as `msg.sender`;
* ownership, scoped permissions and user-controlled revocation remain correct.

Measured Magic gas for the one-transaction delegated batch: `1,040,719`.

This path is **not the default**. Before production use, pin the Magic/Alchemy SDK versions, confirm
the authorization returned by the SDK targets exactly the audited implementation, configure and
audit any paymaster policy, and define whether/when delegation is cleared back to `address(0)`.

Fork-only optional rehearsal:

```bash
ENSV2_MAGIC_7702_DELEGATE=0x69007702764179f14F51cdce752f4f775d74E139 \
forge script script/ensv2/11_RehearseExplorerR2Fork.s.sol \
  --fork-url "$SEPOLIA_RPC_URL" -vv
```

The rehearsal rejects every other delegate address.

## Sponsorship constraints

A plain relayer cannot replace the signer: resolver and registry permissions depend on
`msg.sender`.

The five-transaction EOA path requires Magic Sepolia ETH. The optional EIP-7702 path can use
Alchemy Gas Manager sponsorship when configured, but sponsorship is an additional frontend and
policy integration, not part of this contracts package.
