# ENSv2 Magic Execution Strategies

## Terminology

The Passport setup contains **19 logical state-changing contract operations**. That does not imply
19 transactions or 19 wallet prompts.

## Call classification

| Logical calls | Signer | Target | Dependency | Safe native batch |
| --- | --- | --- | --- | --- |
| 1 | Magic | Passport UserRegistry | platform Passport mint complete | no registry multicall |
| 2–6 | Magic | PermissionedResolver | call 1 complete | one resolver multicall |
| 7 | Magic | Passport UserRegistry | Magic has `ROLE_REGISTRAR` | no registry multicall |
| 8–15 | Magic | PermissionedResolver | credential registered | one resolver multicall |
| 16–19 | Magic | PermissionedResolver | issuer known and records initialized | one resolver multicall |

The historical r2 resolver artifact and runtime both support:

```solidity
multicall(bytes[])
multicallWithNodeCheck(bytes32, bytes[])
```

Both use `delegatecall`, preserve the original `msg.sender`, return per-call results and revert the
entire transaction on the first failed inner call.

Historical caveat: the `node` argument to `multicallWithNodeCheck` is ignored. Every inner setter
still performs its own exact permission check, but the frontend must validate inner calldata and
nodes rather than treating the outer argument as an enforcement mechanism.

## Strategy comparison

| Property | A. Unbatched EOA | B. Native multicalls | C. Magic/Alchemy EIP-7702 |
| --- | ---: | ---: | ---: |
| Logical operations | 19 | 19 | 19 |
| Onchain Magic transactions | 19 | 5 | 1 |
| Expected confirmation prompts | up to 19 | up to 5 | up to 1 |
| Measured setup gas | ~1.40M | `1,116,564` | `1,040,719` + Type-4 authorization overhead |
| ETH at 20 gwei | ~0.028 | `0.02233` | ~`0.02081` plus overhead, or sponsored |
| Atomicity | each operation | each functional group | all five groups |
| Failure recovery | resume per call | resume from failed group | whole batch reverts |
| New infrastructure | none | none | Magic extension + Alchemy + optional paymaster |
| Technical risk | low, poor UX | low | higher |

Revocation is excluded from initial setup and remains a separate Magic demo transaction
(`33,041` measured gas).

## Recommended strategy

**B — native historical resolver multicalls** is the default hackathon strategy.

It reduces prompts from 19 to five without changing account type, introducing a batching contract,
adding a paymaster dependency, or changing any ownership/permission boundary.

## Optional exact EIP-7702 audit

Magic's Smart Account extension is powered by Alchemy. Current Alchemy documentation identifies
the supported delegation implementation as:

```text
SemiModularAccount7702
0x69007702764179f14F51cdce752f4f775d74E139
```

Live Sepolia checks:

```text
runtime bytecode: present
IERC165:          true
IERC1155Receiver: true
IERC721Receiver:  true
```

The fork rehearsal installed the exact EIP-7702 designator:

```text
0xef0100 || 0x69007702764179f14F51cdce752f4f775d74E139
```

on the real Magic address before Passport issuance. It proved:

1. Passport ERC-1155 receipt succeeds while delegated.
2. `executeBatch((address,uint256,bytes)[])` executes the five groups atomically.
3. Credential ERC-1155 receipt succeeds inside that batch.
4. Registry and resolver calls observe the Magic address as `msg.sender`.
5. Passport and credential remain owned by Magic.
6. Scoped issuer writes and forbidden-key reverts are unchanged.
7. Magic can still revoke the issuer permission.
8. The current direct Universal Resolver remains outside the execution path.

This proves technical compatibility with that exact implementation on the audited fork. It does
not authorize EIP-7702 as the default.

Before real use:

* pin and review `magic-sdk`, `@magic-ext/smart-account` and Alchemy SDK versions;
* confirm the SDK-produced authorization targets exactly `0x690077…E139`;
* audit the Alchemy Gas Manager policy if sponsorship is enabled;
* decide whether to retain delegation or explicitly clear it by delegating to `address(0)`;
* repeat the fork test if implementation bytecode or SDK-selected target changes.

A generic or different EIP-7702 delegate is rejected by the rehearsal.
