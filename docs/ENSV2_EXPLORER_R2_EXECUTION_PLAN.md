# ENSv2 Explorer-r2 Execution Plan

Status: **prepared but blocked from broadcast pending ENS routing confirmation**.

Target:

```text
nomadic-passport.eth
└── victor.nomadic-passport.eth
    └── lisbon-house.victor.nomadic-passport.eth
```

## Actors

| Actor | Environment variable | Address / status |
| --- | --- | --- |
| Platform | `NOMADIC_PARENT_OWNER_ADDRESS` | `0xca490deA7D7D79Bac4537D5Fe68fF10cd9c7EbEd` |
| Passport owner | `PASSPORT_OWNER_ADDRESS` | `0xd114FA765bA4811219AAe364c93CE8A81Ad39B17` |
| Lisbon issuer | `LISBON_HOUSE_ISSUER_ADDRESS` | pending; must differ from both |

No script reads or references a private key.

## Go/no-go gates

Before every state-changing phase:

1. `ENSV2_DEPLOYMENT_PROFILE=explorer-v1-r2`;
2. chain ID `11155111`;
3. routing guard passes;
4. exact signer matches the operation;
5. ENS has confirmed routing stability;
6. only then may an operator intentionally set:

```bash
ENSV2_BROADCAST=true
ENSV2_ROUTING_ACK=explorer-v1-r2-confirmed
```

Do not set the acknowledgement yet.

## Phase 1 — Canonical parent link

Prepared script:

```text
script/ensv2/08_SetParentExplorerR2.s.sol
```

Signer: platform.

Target:

```text
0x8fB12e7Ab9B192503d7d02a43e0507c484e27280
```

Call:

```solidity
setParent(
    0xDEDB92913A25abE1f7BCDD85D8A344a43B398B67,
    "nomadic-passport"
)
```

The script checks owner, `ROLE_SET_PARENT`, empty current parent, downward subregistry, resolver,
roles and routing. After execution it verifies the owner/resolver/subregistry/roles did not change
and the top Universal Resolver reports the Nomadic registry as canonical.

## Phase 2 — Platform Passport issuance

Prepared script:

```text
script/ensv2/09_IssuePassportExplorerR2.s.sol
```

Signer: platform.

Historical calls:

```solidity
factory.deployProxy(
    0x0F99e7Ea74903AfCB7224d0354fD7428A6f92917,
    PASSPORT_REGISTRY_SALT,
    abi.encodeWithSelector(
        bytes4(keccak256("initialize(address,uint256)")),
        PASSPORT_OWNER_ADDRESS,
        ALL_ROLES
    )
);

factory.deployProxy(
    0xdcE5205A553573FFd47629327DDdf36186022FfA,
    PASSPORT_RESOLVER_SALT,
    sameHistoricalInitializer
);

nomadicRegistry.register(
    "victor",
    PASSPORT_OWNER_ADDRESS,
    passportRegistry,
    passportResolver,
    passportOwnerRoles,
    type(uint64).max
);
```

Fixed salts:

```text
registry: 0x6d1c86646574f4bb7d4417ef076d3c875e2a5f771758172632925459bd7cea5f
resolver: 0xb289fadc5ddf0dcd877378b815cee6a74af6f650670f8c7e4d1bc899b0d95a76
```

For the confirmed platform address, the deterministic destinations are:

```text
Passport UserRegistry:        0x40776D16B117b04FD5C08458E14ff8CF6518a40E
Passport PermissionedResolver: 0x467B72a46F578a47878137883Ce35c980393Bffe
```

The registry and resolver initialize directly with the Magic wallet as root admin. The platform
does not receive Passport registry root roles. `victor` is minted directly to Magic.

## Phase 3 — Magic bundle

After platform issuance, the bundle retains 19 logical state operations but groups them into five
Magic-signed transactions:

```text
script/ensv2/10_BuildMagicBundleExplorerR2.s.sol
```

The five transaction groups contain:

1. Passport registry `setParent` — one registry call;
2. Passport records — five calls in `multicallWithNodeCheck`;
3. Lisbon credential registration — one registry call;
4. credential records — eight calls in `multicallWithNodeCheck`;
5. issuer authorization — four calls in `multicall`.

Therefore:

```text
logical contract operations: 19
onchain transactions:         5
Magic confirmation prompts:   5 maximum
```

See `ENSV2_MAGIC_TRANSACTION_BUNDLE.md` and `ENSV2_MAGIC_EXECUTION_STRATEGIES.md`.

## Phase 4 — Permission demo

1. Issuer updates `com.nomadic.status`.
2. Issuer update to `com.nomadic.type` reverts.
3. Magic calls `authorizeTextRoles(credentialDns, "com.nomadic.status", issuer, false)`.
4. Issuer's next status update reverts.
5. Passport and credential remain owned by Magic.

Only these issuer keys are granted:

```text
com.nomadic.status
com.nomadic.issuedAt
com.nomadic.expiresAt
com.nomadic.metadata
```

## Records

Passport:

```text
addr = 0xd114FA765bA4811219AAe364c93CE8A81Ad39B17
com.nomadic.type = passport
com.nomadic.profile = https://nomadic-front-rosy.vercel.app/p/victor.nomadic-passport.eth
com.nomadic.currentJourney = lisbon-house
com.nomadic.credentials = lisbon-house.victor.nomadic-passport.eth
```

Credential:

```text
com.nomadic.type = journey-eligibility
com.nomadic.issuer = <runtime issuer address>
com.nomadic.journey = lisbon-house
com.nomadic.policy = lisbon_house_policy_v1
com.nomadic.status = active
com.nomadic.issuedAt = <runtime timestamp>
com.nomadic.expiresAt = ""
com.nomadic.metadata = ""
```

No World data, nullifiers, proofs, age, nationality, document data or email is stored.

## Gas and funding

Fork rehearsal including transaction base gas:

| Signer | Estimated gas | ETH @ 20 gwei | Recommended testnet funding |
| --- | ---: | ---: | ---: |
| Platform | `697,337` | `0.01395` | at least `0.025` Sepolia ETH |
| Magic, five EOA tx | `1,116,564` | `0.02233` | at least `0.035` Sepolia ETH at normal fees |
| Magic revocation demo | `33,041` | `0.00066` | included in a demo buffer |
| Issuer allowed update | `35,071` | `0.00070` | at least `0.005` Sepolia ETH for full demo |

At 50 gwei the platform and Magic setup costs are approximately `0.0349` and `0.0558` Sepolia
ETH. Fund against current fee conditions, not only the 20 gwei example.

Magic currently requires Sepolia ETH.

### Future sponsorship

The native five-transaction EOA path does not require account abstraction. The calls can only be
sponsored if Magic remains the effective `msg.sender`; a plain relayer fails authorization.

The optional Magic/Alchemy path was separately rehearsed with the exact
`SemiModularAccount7702` implementation `0x690077…E139`. It accepted both ERC-1155 mints and
executed all five groups atomically with Magic preserved as `msg.sender`, but remains non-default
until SDK versions, delegate target and sponsorship policy are pinned.

## Rehearsal

```bash
ENSV2_DEPLOYMENT_PROFILE=explorer-v1-r2 \
NOMADIC_PARENT_OWNER_ADDRESS=0xca490deA7D7D79Bac4537D5Fe68fF10cd9c7EbEd \
PASSPORT_OWNER_ADDRESS=0xd114FA765bA4811219AAe364c93CE8A81Ad39B17 \
forge script script/ensv2/11_RehearseExplorerR2Fork.s.sol \
  --fork-url "$SEPOLIA_RPC_URL" -vv
```

Result: `Explorer-r2 full fork rehearsal PASSED`.

It verifies top, managed and Explorer-direct resolution. It separately proves the `current` direct
resolver cannot resolve the generated hierarchy.

## Recovery

If a phase fails, do not continue to the next signer bundle. If routing changes after issuance,
pause issuance and use the r2 direct resolver for recovery reads. Do not create a second Passport
under `current` without an explicit ENS-supported migration decision.
