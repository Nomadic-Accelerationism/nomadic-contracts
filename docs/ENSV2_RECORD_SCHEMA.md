# ENSv2 Record Schema

Public records only. Values in local tests are synthetic.

## Passport records

| Key | Example value |
| --- | --- |
| `com.nomadic.type` | `passport` |
| `com.nomadic.profile` | `https://example.invalid/p/victor` |
| `com.nomadic.currentJourney` | `lisbon-house-2026` |
| `com.nomadic.credentials` | `lisbon-house.<passport-name>` |
| `addr` | user wallet |

## Credential records

| Key | Example value |
| --- | --- |
| `com.nomadic.type` | `journey-eligibility` |
| `com.nomadic.issuer` | `nomadic-lisbon-house` |
| `com.nomadic.journey` | `lisbon-house-2026` |
| `com.nomadic.policy` | `lisbon_house_policy_v1` |
| `com.nomadic.status` | `eligible` |
| `com.nomadic.issuedAt` | `0` |
| `com.nomadic.expiresAt` | `0` |
| `com.nomadic.metadata` | `https://example.invalid/credential` |

## Never create records for

* age
* nationality
* issuing country
* document type
* legal name
* email
* World nullifier
* World session ID
* raw World proof
* selfie / document information

Solidity constants: `src/ensv2/NomadicRecords.sol`.
