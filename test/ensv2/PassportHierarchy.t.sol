// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IRegistry} from "ensv2/registry/interfaces/IRegistry.sol";
import {RegistryRolesLib} from "ensv2/registry/libraries/RegistryRolesLib.sol";

import {NomadicENSv2Fixture} from "./NomadicENSv2Fixture.sol";
import {NomadicRecords} from "../../src/ensv2/NomadicRecords.sol";

contract PassportHierarchyTest is NomadicENSv2Fixture {
    function test_platformCanProvisionPassportBelowParent() public view {
        assertEq(parentRegistry.ownerOf(passportTokenId), user);
        assertEq(address(parentRegistry.getSubregistry(PASSPORT_LABEL)), address(passportRegistry));
        assertTrue(parentRegistry.hasRootRoles(RegistryRolesLib.ROLE_REGISTRAR, platform));
    }

    function test_passportOwnershipAssignedToUser() public view {
        assertEq(parentRegistry.ownerOf(passportTokenId), user);
        assertEq(parentRegistry.findOwner(PASSPORT_LABEL), user);
    }

    function test_passportResolverPointsToPermissionedResolver() public view {
        assertEq(parentRegistry.getResolver(PASSPORT_LABEL), address(passportResolver));
        assertEq(_findResolver(passportDnsName), address(passportResolver));
    }

    function test_passportAddressRecordResolvesToUser() public view {
        assertEq(passportResolver.addr(passportNode), user);
    }

    function test_passportHasChildUserRegistry() public view {
        assertEq(address(parentRegistry.getSubregistry(PASSPORT_LABEL)), address(passportRegistry));
        (IRegistry parent, string memory label) = passportRegistry.getParent();
        assertEq(address(parent), address(parentRegistry));
        assertEq(label, PASSPORT_LABEL);
    }

    function test_credentialChildRegisteredInsidePassportRegistry() public view {
        assertEq(passportRegistry.ownerOf(credentialTokenId), user);
        assertEq(passportRegistry.findOwner(CREDENTIAL_LABEL), user);
        assertEq(address(passportRegistry.getSubregistry(CREDENTIAL_LABEL)), address(0));
        assertEq(passportRegistry.getResolver(CREDENTIAL_LABEL), address(passportResolver));
    }

    function test_credentialOwnershipAssignedToUser() public view {
        assertEq(passportRegistry.ownerOf(credentialTokenId), user);
    }

    function test_canonicalParentLinkageConfigured() public view {
        (IRegistry parentParent, string memory parentLabel) = parentRegistry.getParent();
        assertEq(address(parentParent), address(ethRegistry));
        assertEq(parentLabel, PARENT_LABEL);

        (IRegistry passportParent, string memory passportLabel_) = passportRegistry.getParent();
        assertEq(address(passportParent), address(parentRegistry));
        assertEq(passportLabel_, PASSPORT_LABEL);
    }

    function test_universalResolverFindsPassportAndCredential() public view {
        assertEq(_findResolver(passportDnsName), address(passportResolver));
        assertEq(_findResolver(credentialDnsName), address(passportResolver));
        assertEq(universalResolver.findOwner(passportDnsName), user);
        assertEq(universalResolver.findOwner(credentialDnsName), user);
        assertEq(address(universalResolver.findCanonicalRegistry(passportDnsName)), address(passportRegistry));
    }

    function test_platformCannotTransferPassportAfterHandoffWithoutUserCooperation() public {
        // After handoff, platform is not the Passport owner and holds no Passport-token roles.
        assertEq(parentRegistry.ownerOf(passportTokenId), user);
        assertFalse(parentRegistry.hasRoles(passportTokenId, RegistryRolesLib.ROLE_CAN_TRANSFER_ADMIN, platform));
        assertFalse(parentRegistry.isApprovedForAll(user, platform));

        vm.prank(platform);
        vm.expectRevert();
        parentRegistry.safeTransferFrom(user, attacker, passportTokenId, 1, "");

        assertEq(parentRegistry.ownerOf(passportTokenId), user);
    }

    function test_platformHasNoRootRolesOnPassportRegistryAfterHandoff() public view {
        assertFalse(passportRegistry.hasRootRoles(RegistryRolesLib.ROLE_REGISTRAR, platform));
        assertFalse(passportRegistry.hasRootRoles(RegistryRolesLib.ROLE_UPGRADE, platform));
        assertFalse(passportRegistry.hasRootRoles(RegistryRolesLib.ROLE_SET_PARENT, platform));
        assertTrue(passportRegistry.hasRootRoles(RegistryRolesLib.ROLE_REGISTRAR, user));
    }

    function test_passportPublicRecordsSeeded() public view {
        assertEq(passportResolver.text(passportNode, NomadicRecords.TYPE_KEY), NomadicRecords.TYPE_PASSPORT);
        assertEq(passportResolver.text(passportNode, NomadicRecords.CURRENT_JOURNEY_KEY), "lisbon-house-2026");
        assertEq(
            passportResolver.text(passportNode, NomadicRecords.CREDENTIALS_KEY),
            string.concat(CREDENTIAL_LABEL, ".", PASSPORT_LABEL, ".", PARENT_LABEL, ".eth")
        );
    }
}
