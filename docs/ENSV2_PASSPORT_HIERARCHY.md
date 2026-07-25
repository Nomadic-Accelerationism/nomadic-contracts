# ENSv2 Passport Hierarchy

## Why ENS is essential

Nomadic issues a portable Passport identity rather than requiring an existing ENS name:

* the user owns the Passport name after handoff;
* Journeys produce namespaced credential children under that Passport;
* public records make Journey state discoverable by any ENS-aware client;
* issuers receive only scoped record authority;
* the user can revoke that authority without surrendering Passport ownership.

## Target hierarchy

```text
<passport-label>.<parent>
└── <credential-label>.<passport-label>.<parent>
```

Example only:

```text
victor.nomadic-passport-test.eth
└── lisbon-house.victor.nomadic-passport-test.eth
```

## On-chain shape used in this slice

```text
Platform-controlled parent registry
└── Passport label owned by user
    ├── PermissionedResolver (user-admin)
    └── Passport UserRegistry (user-admin)
        └── Credential label owned by user (no separate credential UserRegistry)
```

### Roles

| Actor | Control |
| --- | --- |
| Platform | ROLE_REGISTRAR on parent registry only; provisions Passport then retains no Passport registry root roles |
| User | Owns Passport + credential tokens; admin of Passport UserRegistry + PermissionedResolver |
| Issuer | Neither name owner; only allowlisted credential text-key authorizations |

## Local fixture

`test/ensv2/NomadicENSv2Fixture.sol` deploys a minimal ENSv2 stack locally:

* root + `.eth` registries;
* platform parent `nomadic-passport-test.eth` UserRegistry;
* Passport UserRegistry + PermissionedResolver via `VerifiableFactory`;
* credential child label inside the Passport registry;
* UniversalResolverV2 for resolution checks.

## Tests

See `test/ensv2/PassportHierarchy.t.sol`.
