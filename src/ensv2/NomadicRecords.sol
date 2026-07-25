// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @notice Public Nomadic Passport / credential text-record schema.
/// @dev Never store age, nationality, legal name, email, World nullifiers/proofs, or document data.
library NomadicRecords {
    // Passport keys
    string internal constant TYPE_KEY = "com.nomadic.type";
    string internal constant PROFILE_KEY = "com.nomadic.profile";
    string internal constant CURRENT_JOURNEY_KEY = "com.nomadic.currentJourney";
    string internal constant CREDENTIALS_KEY = "com.nomadic.credentials";

    // Credential keys
    string internal constant ISSUER_KEY = "com.nomadic.issuer";
    string internal constant JOURNEY_KEY = "com.nomadic.journey";
    string internal constant POLICY_KEY = "com.nomadic.policy";
    string internal constant STATUS_KEY = "com.nomadic.status";
    string internal constant ISSUED_AT_KEY = "com.nomadic.issuedAt";
    string internal constant EXPIRES_AT_KEY = "com.nomadic.expiresAt";
    string internal constant METADATA_KEY = "com.nomadic.metadata";

    // Common values
    string internal constant TYPE_PASSPORT = "passport";
    string internal constant TYPE_JOURNEY_ELIGIBILITY = "journey-eligibility";

    /// @notice Text keys the Journey issuer may update on the credential node.
    function issuerAllowlistedKeys() internal pure returns (string[] memory keys) {
        keys = new string[](4);
        keys[0] = STATUS_KEY;
        keys[1] = ISSUED_AT_KEY;
        keys[2] = EXPIRES_AT_KEY;
        keys[3] = METADATA_KEY;
    }

    /// @notice Text keys the issuer must never be able to update.
    function issuerForbiddenTextKeys() internal pure returns (string[] memory keys) {
        keys = new string[](7);
        keys[0] = "avatar";
        keys[1] = "url";
        keys[2] = TYPE_KEY;
        keys[3] = ISSUER_KEY;
        keys[4] = JOURNEY_KEY;
        keys[5] = POLICY_KEY;
        keys[6] = CREDENTIALS_KEY;
    }
}
