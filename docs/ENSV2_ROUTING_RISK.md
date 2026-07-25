# ENSv2 Explorer-r2 Routing Risk

## Current live route

At preparation time, the standard Sepolia Universal Resolver entrypoint follows:

```text
0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe
  → 0x6d80F2172CFdEc5730fE683860C33d26fC42e6F1
  → 0x2F8A180604c42457Cb56C7c4f708748fF1F91DF1
  → RootRegistry 0xc960F7217d3643B525Ef36Bec8Adf86953CD9aB8
```

This makes Explorer-r2 record resolution work through the standard endpoint used by ENSjs.

The upstream repository explicitly describes this route as temporary in
`lib/ens-contracts-v2/contracts/README.md`. The managed proxy may later be returned to the
`current` deployment.

## Routing guard

`script/ensv2/07_VerifyExplorerR2Routing.s.sol` and all Explorer-r2 execution scripts verify:

1. top proxy implementation equals the expected managed proxy;
2. managed proxy implementation equals the r2 Universal Resolver;
3. r2 Universal Resolver `ROOT_REGISTRY()` equals the r2 root;
4. `nomadic-passport.eth` has a nonzero owner through the top resolver;
5. `findResolver` returns a nonzero resolver;
6. `findExactRegistry` equals the Nomadic UserRegistry.

Any mismatch reverts with:

```solidity
ENSV2_ROUTING_PROFILE_MISMATCH()
```

Read-only command:

```bash
ENSV2_DEPLOYMENT_PROFILE=explorer-v1-r2 \
forge script script/ensv2/07_VerifyExplorerR2Routing.s.sol \
  --rpc-url "$SEPOLIA_RPC_URL" -vv
```

## Broadcast lock

Explorer-r2 broadcast-capable scripts require both:

```bash
ENSV2_BROADCAST=true
ENSV2_ROUTING_ACK=explorer-v1-r2-confirmed
```

The second value is a human acknowledgement that ENS has confirmed routing stability for the
demo. **Do not set it before that confirmation.**

If either value is absent, scripts revert with `ENSV2_BROADCAST_LOCKED()` or
`ENSV2_ROUTING_ACK_REQUIRED()`.

The lock is necessary but not sufficient: the routing guard is always evaluated again immediately
before preparing any transaction.

## ENSjs impact

Normal ENSjs Sepolia configuration uses the top proxy, so while the route above remains active:

* `getResolver` and Universal-Resolver-based `addr`/`text` reads work;
* ENSv2 `findOwner` works when called directly;
* ENSjs `getOwner`, registration, writes and v1 subgraph indexing remain ENSv1-oriented.

Changing the managed proxy to the current direct resolver would make Explorer-r2 names invisible
to normal Universal Resolver record reads, even though their r2 registry state remains intact.

## Go/no-go condition

**NO-GO:** routing is only observed live but ENS has not confirmed its stability.

**GO:** ENS confirms that the public top route will continue to serve Explorer-r2 throughout the
demo, the guard passes at execution time, and operators intentionally set the routing ACK.

## Recovery if routing changes after issuance

1. Stop all new Passport and credential issuance.
2. Do not automatically create a duplicate Passport under `current`.
3. Continue read-only recovery through the r2 direct resolver `0x2F8A…1DF1`.
4. Revoke issuer permissions before any ownership migration.
5. Coordinate an ENS-supported cutover or an explicit re-registration/migration plan.
6. Only update profile selection after ownership and public records are reconciled.

The r2 names are not deleted by a proxy cutover; they lose standard endpoint visibility.
