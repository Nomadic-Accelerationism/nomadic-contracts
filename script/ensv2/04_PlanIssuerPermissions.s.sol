// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2} from "forge-std/Script.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";
import {VerifiableFactory} from "@ensdomains/verifiable-factory/VerifiableFactory.sol";

import {EACBaseRolesLib} from "ensv2/access-control/libraries/EACBaseRolesLib.sol";
import {IEnhancedAccessControl} from "ensv2/access-control/interfaces/IEnhancedAccessControl.sol";
import {RegistryRolesLib} from "ensv2/registry/libraries/RegistryRolesLib.sol";
import {PermissionedResolver} from "ensv2/resolver/PermissionedResolver.sol";
import {PermissionedResolverLib} from "ensv2/resolver/libraries/PermissionedResolverLib.sol";

import {NomadicRecords} from "../../src/ensv2/NomadicRecords.sol";
import {ENSv2ExecutionBase} from "./ENSv2ExecutionBase.sol";

/// @notice Simulation-only issuer permission grant/revoke plan. Never broadcasts.
contract PlanIssuerPermissionsScript is ENSv2ExecutionBase, ERC1155Holder {
    function run() external {
        _loadProfile();
        require(!vm.envOr("ENSV2_BROADCAST", false), "ENSV2_BROADCAST must be false");

        address user = vm.envOr("ENSV2_PASSPORT_OWNER_ADDRESS", makeAddr("user"));
        address issuer = vm.envOr("ENSV2_ISSUER_ADDRESS", makeAddr("issuer"));
        string memory passportLabel = vm.envOr("ENSV2_PASSPORT_LABEL", string("victor"));
        string memory credentialLabel = vm.envOr("ENSV2_CREDENTIAL_LABEL", string("lisbon-house"));

        console2.log("=== PLAN: Issuer permissions (simulation only) ===");
        console2.log("user", user);
        console2.log("issuer", issuer);
        console2.log("allowed keys: status, issuedAt, expiresAt, metadata");
        console2.log("forbidden: addr/avatar/url/contenthash/type/issuer/journey/policy/credentials");
        console2.log("--- Ordered future Sepolia calls ---");
        console2.log("grant: PermissionedResolver.authorizeTextRoles(credentialDns, key, issuer, true)");
        console2.logBytes32(PermissionedResolver.authorizeTextRoles.selector);
        console2.log("revoke: authorizeTextRoles(..., false)");
        console2.log("Forbidden capabilities must remain denied (registrar/transfer/resolver/upgrade/clear)");

        _simulateLocal(user, issuer, passportLabel, credentialLabel);
    }

    function _simulateLocal(address user, address issuer, string memory passportLabel, string memory credentialLabel)
        internal
    {
        VerifiableFactory factory = new VerifiableFactory();
        PermissionedResolver resolverImpl = new PermissionedResolver(makeAddr("resolverNamer"));
        PermissionedResolver resolver = PermissionedResolver(
            factory.deployProxy(
                address(resolverImpl),
                1,
                abi.encodeCall(PermissionedResolver.initialize, (user, EACBaseRolesLib.ALL_ROLES, new bytes[](0)))
            )
        );

        bytes memory credentialDns = NameCoder.encode(string.concat(credentialLabel, ".", passportLabel, ".parent.eth"));
        bytes32 credentialNode = NameCoder.namehash(credentialDns, 0);

        string[] memory allowed = NomadicRecords.issuerAllowlistedKeys();
        uint256 gasStart = gasleft();
        vm.startPrank(user);
        for (uint256 i = 0; i < allowed.length; i++) {
            resolver.authorizeTextRoles(credentialDns, allowed[i], issuer, true);
        }
        vm.stopPrank();

        vm.prank(issuer);
        resolver.setText(credentialNode, NomadicRecords.STATUS_KEY, "eligible");

        // Revoke status only and prove issuer write fails with exact selector.
        vm.prank(user);
        resolver.authorizeTextRoles(credentialDns, NomadicRecords.STATUS_KEY, issuer, false);

        uint256 nodeResource = PermissionedResolverLib.resource(credentialNode, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                IEnhancedAccessControl.EACUnauthorizedAccountRoles.selector,
                nodeResource,
                PermissionedResolverLib.ROLE_SET_TEXT,
                issuer
            )
        );
        vm.prank(issuer);
        resolver.setText(credentialNode, NomadicRecords.STATUS_KEY, "blocked");

        console2.log("approx gas", gasStart - gasleft());
        console2.log(
            "issuerHasUpgrade", resolver.hasRootRoles(PermissionedResolverLib.ROLE_UPGRADE, issuer) ? "true" : "false"
        );
        console2.log("issuerMustNotReceive ROLE_REGISTRAR", RegistryRolesLib.ROLE_REGISTRAR);
        console2.log("RESULT: Issuer permissions plan simulation PASSED");
    }
}
