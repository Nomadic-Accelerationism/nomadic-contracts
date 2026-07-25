// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IEnhancedAccessControl} from "ensv2/access-control/interfaces/IEnhancedAccessControl.sol";
import {IRegistry} from "ensv2/registry/interfaces/IRegistry.sol";
import {RegistryRolesLib} from "ensv2/registry/libraries/RegistryRolesLib.sol";
import {PermissionedResolverLib} from "ensv2/resolver/libraries/PermissionedResolverLib.sol";
import {PermissionedResolver} from "ensv2/resolver/PermissionedResolver.sol";

import {NomadicENSv2Fixture} from "./NomadicENSv2Fixture.sol";
import {NomadicRecords} from "../../src/ensv2/NomadicRecords.sol";

contract PermissionInvariantsTest is NomadicENSv2Fixture {
    function test_issuerCanUpdateEachAllowlistedKey() public {
        string[] memory keys = NomadicRecords.issuerAllowlistedKeys();
        for (uint256 i = 0; i < keys.length; i++) {
            string memory value = string.concat("issuer-value-", vm.toString(i));
            vm.prank(issuer);
            passportResolver.setText(credentialNode, keys[i], value);
            assertEq(passportResolver.text(credentialNode, keys[i]), value);
        }
    }

    function test_issuerCannotUpdateForbiddenTextKeys() public {
        // PermissionedResolver reverts with the widest name resource `resource(node, 0)`
        // when the caller lacks both per-key and any-name part roles.
        uint256 nodeResource = PermissionedResolverLib.resource(credentialNode, bytes32(0));
        string[] memory keys = NomadicRecords.issuerForbiddenTextKeys();
        for (uint256 i = 0; i < keys.length; i++) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IEnhancedAccessControl.EACUnauthorizedAccountRoles.selector,
                    nodeResource,
                    PermissionedResolverLib.ROLE_SET_TEXT,
                    issuer
                )
            );
            vm.prank(issuer);
            passportResolver.setText(credentialNode, keys[i], "attack");
        }
    }

    function test_issuerCannotChangePassportOrCredentialAddr() public {
        vm.prank(issuer);
        vm.expectRevert();
        passportResolver.setAddr(passportNode, attacker);

        vm.prank(issuer);
        vm.expectRevert();
        passportResolver.setAddr(credentialNode, attacker);

        assertEq(passportResolver.addr(passportNode), user);
        assertEq(passportResolver.addr(credentialNode), user);
    }

    function test_issuerCannotReplaceResolvers() public {
        vm.prank(issuer);
        vm.expectRevert();
        parentRegistry.setResolver(passportTokenId, attacker);

        vm.prank(issuer);
        vm.expectRevert();
        passportRegistry.setResolver(credentialTokenId, attacker);

        assertEq(parentRegistry.getResolver(PASSPORT_LABEL), address(passportResolver));
        assertEq(passportRegistry.getResolver(CREDENTIAL_LABEL), address(passportResolver));
    }

    function test_issuerCannotTransferPassportOrCredential() public {
        vm.prank(issuer);
        vm.expectRevert();
        parentRegistry.safeTransferFrom(user, attacker, passportTokenId, 1, "");

        vm.prank(issuer);
        vm.expectRevert();
        passportRegistry.safeTransferFrom(user, attacker, credentialTokenId, 1, "");

        assertEq(parentRegistry.ownerOf(passportTokenId), user);
        assertEq(passportRegistry.ownerOf(credentialTokenId), user);
    }

    function test_issuerCannotRegisterArbitrarySiblingCredentials() public {
        vm.prank(issuer);
        vm.expectRevert();
        passportRegistry.register(
            "evil-sibling", issuer, IRegistry(address(0)), address(passportResolver), 0, NAME_EXPIRY
        );

        assertEq(passportRegistry.findOwner("evil-sibling"), address(0));
    }

    function test_issuerCannotGrantItselfAdditionalPermissions() public {
        vm.prank(issuer);
        vm.expectRevert();
        passportResolver.authorizeTextRoles(credentialDnsName, NomadicRecords.TYPE_KEY, issuer, true);

        vm.prank(issuer);
        vm.expectRevert();
        passportResolver.authorizeNameRoles(credentialDnsName, PermissionedResolverLib.ROLE_SET_TEXT, issuer, true);
    }

    function test_issuerCannotUpgradeResolver() public {
        PermissionedResolver newImpl = new PermissionedResolver(address(this));
        // Expected: EACUnauthorizedAccountRoles(0, ROLE_UPGRADE, issuer)
        // selector 0x4b27a133 — use startPrank so msg.sender is preserved through the
        // VerifiableFactory UUPSProxyLogic upgrade path.
        vm.startPrank(issuer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEnhancedAccessControl.EACUnauthorizedAccountRoles.selector,
                uint256(0),
                PermissionedResolverLib.ROLE_UPGRADE,
                issuer
            )
        );
        passportResolver.upgradeToAndCall(address(newImpl), "");
        vm.stopPrank();
    }

    function test_issuerCannotClearUnrelatedRecords() public {
        vm.prank(issuer);
        vm.expectRevert();
        passportResolver.clearRecords(credentialNode);

        vm.prank(issuer);
        vm.expectRevert();
        passportResolver.clearRecords(passportNode);

        assertEq(
            passportResolver.text(credentialNode, NomadicRecords.TYPE_KEY), NomadicRecords.TYPE_JOURNEY_ELIGIBILITY
        );
    }

    function test_issuerCannotSetContenthash() public {
        vm.prank(issuer);
        vm.expectRevert();
        passportResolver.setContenthash(credentialNode, hex"01");
    }

    function test_revokeExactTextAuthorization() public {
        string memory key = NomadicRecords.STATUS_KEY;
        string memory siblingBefore = passportResolver.text(credentialNode, NomadicRecords.TYPE_KEY);

        vm.prank(issuer);
        passportResolver.setText(credentialNode, key, "revoking-soon");
        assertEq(passportResolver.text(credentialNode, key), "revoking-soon");

        vm.prank(user);
        passportResolver.authorizeTextRoles(credentialDnsName, key, issuer, false);

        // After revoke, setText falls back to checking resource(node, 0).
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
        passportResolver.setText(credentialNode, key, "should-fail");

        // User can still update; sibling allowlisted keys remain writable by issuer.
        vm.prank(user);
        passportResolver.setText(credentialNode, key, "user-restored");
        assertEq(passportResolver.text(credentialNode, key), "user-restored");

        vm.prank(issuer);
        passportResolver.setText(credentialNode, NomadicRecords.METADATA_KEY, "still-allowed");
        assertEq(passportResolver.text(credentialNode, NomadicRecords.METADATA_KEY), "still-allowed");

        assertEq(parentRegistry.ownerOf(passportTokenId), user);
        assertEq(passportResolver.addr(passportNode), user);
        assertEq(passportResolver.text(credentialNode, NomadicRecords.TYPE_KEY), siblingBefore);
    }

    function test_issuerHasNoBroadRoles_regression() public view {
        // Root / registrar / transfer / subregistry / upgrade must never be granted to issuer.
        assertFalse(passportRegistry.hasRootRoles(RegistryRolesLib.ROLE_REGISTRAR, issuer));
        assertFalse(passportRegistry.hasRootRoles(RegistryRolesLib.ROLE_REGISTRAR_ADMIN, issuer));
        assertFalse(passportRegistry.hasRootRoles(RegistryRolesLib.ROLE_SET_SUBREGISTRY, issuer));
        assertFalse(passportRegistry.hasRootRoles(RegistryRolesLib.ROLE_SET_SUBREGISTRY_ADMIN, issuer));
        assertFalse(passportRegistry.hasRootRoles(RegistryRolesLib.ROLE_SET_RESOLVER, issuer));
        assertFalse(passportRegistry.hasRootRoles(RegistryRolesLib.ROLE_SET_RESOLVER_ADMIN, issuer));
        assertFalse(passportRegistry.hasRootRoles(RegistryRolesLib.ROLE_UPGRADE, issuer));
        assertFalse(passportRegistry.hasRootRoles(RegistryRolesLib.ROLE_UPGRADE_ADMIN, issuer));
        assertFalse(parentRegistry.hasRoles(passportTokenId, RegistryRolesLib.ROLE_CAN_TRANSFER_ADMIN, issuer));
        assertFalse(passportRegistry.hasRoles(credentialTokenId, RegistryRolesLib.ROLE_CAN_TRANSFER_ADMIN, issuer));

        assertFalse(passportResolver.hasRootRoles(PermissionedResolverLib.ROLE_SET_TEXT_ADMIN, issuer));
        assertFalse(passportResolver.hasRootRoles(PermissionedResolverLib.ROLE_SET_ADDR, issuer));
        assertFalse(passportResolver.hasRootRoles(PermissionedResolverLib.ROLE_SET_CONTENTHASH, issuer));
        assertFalse(passportResolver.hasRootRoles(PermissionedResolverLib.ROLE_CLEAR, issuer));
        assertFalse(passportResolver.hasRootRoles(PermissionedResolverLib.ROLE_UPGRADE, issuer));

        // Only the four allowlisted credential text-key resources are granted.
        string[] memory allowed = NomadicRecords.issuerAllowlistedKeys();
        for (uint256 i = 0; i < allowed.length; i++) {
            uint256 resource =
                PermissionedResolverLib.resource(credentialNode, PermissionedResolverLib.partHash(allowed[i]));
            assertTrue(passportResolver.hasRoles(resource, PermissionedResolverLib.ROLE_SET_TEXT, issuer));
        }

        string[] memory forbidden = NomadicRecords.issuerForbiddenTextKeys();
        for (uint256 i = 0; i < forbidden.length; i++) {
            uint256 resource =
                PermissionedResolverLib.resource(credentialNode, PermissionedResolverLib.partHash(forbidden[i]));
            assertFalse(passportResolver.hasRoles(resource, PermissionedResolverLib.ROLE_SET_TEXT, issuer));
        }
    }

    function test_transferPassport_externalResolverPermissionsSurvive() public {
        address newOwner = makeAddr("newPassportOwner");
        vm.prank(issuer);
        passportResolver.setText(credentialNode, NomadicRecords.STATUS_KEY, "pre-transfer");

        // Documented behavior: PermissionedResolver authorizations are account-scoped on the
        // resolver, not automatically cleared by ERC1155 Passport transfer.
        vm.prank(user);
        parentRegistry.safeTransferFrom(user, newOwner, passportTokenId, 1, "");
        assertEq(parentRegistry.ownerOf(passportTokenId), newOwner);

        vm.prank(issuer);
        passportResolver.setText(credentialNode, NomadicRecords.STATUS_KEY, "post-transfer");
        assertEq(passportResolver.text(credentialNode, NomadicRecords.STATUS_KEY), "post-transfer");
    }

    function test_transferCredential_externalResolverPermissionsSurvive() public {
        address newOwner = makeAddr("newCredentialOwner");
        vm.prank(issuer);
        passportResolver.setText(credentialNode, NomadicRecords.METADATA_KEY, "cred-pre");

        vm.prank(user);
        passportRegistry.safeTransferFrom(user, newOwner, credentialTokenId, 1, "");
        assertEq(passportRegistry.ownerOf(credentialTokenId), newOwner);

        vm.prank(issuer);
        passportResolver.setText(credentialNode, NomadicRecords.METADATA_KEY, "cred-post");
        assertEq(passportResolver.text(credentialNode, NomadicRecords.METADATA_KEY), "cred-post");
    }

    function test_recommendation_revokeBeforeTransfer() public {
        // Safest operational policy: revoke issuer text authorizations before ownership transfer.
        string[] memory keys = NomadicRecords.issuerAllowlistedKeys();
        vm.startPrank(user);
        for (uint256 i = 0; i < keys.length; i++) {
            passportResolver.authorizeTextRoles(credentialDnsName, keys[i], issuer, false);
        }
        parentRegistry.safeTransferFrom(user, attacker, passportTokenId, 1, "");
        vm.stopPrank();

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
        passportResolver.setText(credentialNode, NomadicRecords.STATUS_KEY, "blocked");
    }
}
