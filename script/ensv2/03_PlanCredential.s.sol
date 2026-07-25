// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";
import {VerifiableFactory} from "@ensdomains/verifiable-factory/VerifiableFactory.sol";

import {EACBaseRolesLib} from "ensv2/access-control/libraries/EACBaseRolesLib.sol";
import {RegistryRolesLib} from "ensv2/registry/libraries/RegistryRolesLib.sol";
import {IRegistry} from "ensv2/registry/interfaces/IRegistry.sol";
import {IStandardRegistry} from "ensv2/registry/interfaces/IStandardRegistry.sol";
import {UserRegistry} from "ensv2/registry/UserRegistry.sol";
import {PermissionedResolver} from "ensv2/resolver/PermissionedResolver.sol";
import {LabelStore} from "ensv2/utils/LabelStore.sol";
import {IContractNamer} from "ensv2/reverse-registrar/interfaces/IContractNamer.sol";

import {NomadicRecords} from "../../src/ensv2/NomadicRecords.sol";

/// @notice Simulation-only credential child plan. Never broadcasts. No private key required.
contract PlanCredentialScript is Script, ERC1155Holder {
    function run() external {
        require(!vm.envOr("ENSV2_BROADCAST", false), "ENSV2_BROADCAST must be false");

        string memory passportLabel = vm.envOr("ENSV2_PASSPORT_LABEL", string("victor"));
        string memory credentialLabel = vm.envOr("ENSV2_CREDENTIAL_LABEL", string("lisbon-house"));
        address user = vm.envOr("ENSV2_PASSPORT_OWNER_ADDRESS", makeAddr("user"));

        console2.log("=== PLAN: Credential child (simulation only) ===");
        console2.log("passportLabel", passportLabel);
        console2.log("credentialLabel", credentialLabel);
        console2.log("user", user);
        console2.log("--- Ordered future Sepolia calls ---");
        console2.log("1 PassportRegistry.register(credentialLabel, user, address(0), resolver, roles, expiry)");
        console2.logBytes32(IStandardRegistry.register.selector);
        console2.log("2 user ownership via register mint");
        console2.log("3 PermissionedResolver.setText credential schema keys as user");
        console2.log("4 PassportResolver.setText(passportNode, com.nomadic.credentials, credentialFqdn)");
        console2.log("No separate UserRegistry for credential in this slice");
        console2.log("Prerequisites: provisioned Passport UserRegistry + PermissionedResolver");

        _simulateLocal(user, passportLabel, credentialLabel);
    }

    function _simulateLocal(address user, string memory passportLabel, string memory credentialLabel) internal {
        VerifiableFactory factory = new VerifiableFactory();
        LabelStore labelStore = new LabelStore(IContractNamer(address(0)));
        address namer = makeAddr("implNamer");
        UserRegistry userImpl = new UserRegistry(labelStore, namer);
        PermissionedResolver resolverImpl = new PermissionedResolver(namer);

        UserRegistry passport = UserRegistry(
            factory.deployProxy(
                address(userImpl),
                1,
                abi.encodeCall(
                    UserRegistry.initialize,
                    (user, RegistryRolesLib.ROLE_REGISTRAR | RegistryRolesLib.ROLE_REGISTRAR_ADMIN)
                )
            )
        );
        PermissionedResolver resolver = PermissionedResolver(
            factory.deployProxy(
                address(resolverImpl),
                2,
                abi.encodeCall(PermissionedResolver.initialize, (user, EACBaseRolesLib.ALL_ROLES, new bytes[](0)))
            )
        );

        uint256 gasStart = gasleft();
        vm.startPrank(user);
        uint256 tokenId = passport.register(
            credentialLabel,
            user,
            IRegistry(address(0)),
            address(resolver),
            RegistryRolesLib.ROLE_SET_RESOLVER | RegistryRolesLib.ROLE_CAN_TRANSFER_ADMIN,
            type(uint64).max
        );

        bytes memory passportDns = NameCoder.encode(string.concat(passportLabel, ".parent.eth"));
        bytes memory credentialDns = NameCoder.encode(string.concat(credentialLabel, ".", passportLabel, ".parent.eth"));
        bytes32 passportNode = NameCoder.namehash(passportDns, 0);
        bytes32 credentialNode = NameCoder.namehash(credentialDns, 0);

        resolver.setAddr(credentialNode, user);
        resolver.setText(credentialNode, NomadicRecords.TYPE_KEY, NomadicRecords.TYPE_JOURNEY_ELIGIBILITY);
        resolver.setText(credentialNode, NomadicRecords.STATUS_KEY, "eligible");
        resolver.setText(
            passportNode,
            NomadicRecords.CREDENTIALS_KEY,
            string.concat(credentialLabel, ".", passportLabel, ".parent.eth")
        );
        vm.stopPrank();

        console2.log("simulated credential tokenId", tokenId);
        console2.log("simulated credential owner", passport.ownerOf(tokenId));
        console2.log("approx gas", gasStart - gasleft());
        console2.log("RESULT: Credential plan simulation PASSED");
    }
}
