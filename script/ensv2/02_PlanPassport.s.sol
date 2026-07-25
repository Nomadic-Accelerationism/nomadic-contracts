// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2} from "forge-std/Script.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";
import {VerifiableFactory} from "@ensdomains/verifiable-factory/VerifiableFactory.sol";

import {EACBaseRolesLib} from "ensv2/access-control/libraries/EACBaseRolesLib.sol";
import {PermissionedRegistry} from "ensv2/registry/PermissionedRegistry.sol";
import {RegistryRolesLib} from "ensv2/registry/libraries/RegistryRolesLib.sol";
import {IRegistry} from "ensv2/registry/interfaces/IRegistry.sol";
import {IStandardRegistry} from "ensv2/registry/interfaces/IStandardRegistry.sol";
import {UserRegistry} from "ensv2/registry/UserRegistry.sol";
import {PermissionedResolver} from "ensv2/resolver/PermissionedResolver.sol";
import {LabelStore} from "ensv2/utils/LabelStore.sol";
import {IContractNamer} from "ensv2/reverse-registrar/interfaces/IContractNamer.sol";

import {NomadicRecords} from "../../src/ensv2/NomadicRecords.sol";
import {ENSv2DeploymentProfiles} from "../../src/ensv2/ENSv2DeploymentProfiles.sol";
import {ENSv2ExecutionBase} from "./ENSv2ExecutionBase.sol";

/// @notice Simulation-only Passport provisioning plan. Never broadcasts. No private key required.
contract PlanPassportScript is ENSv2ExecutionBase, ERC1155Holder {
    function run() external {
        ENSv2DeploymentProfiles.Profile memory deployment = _loadProfile();
        require(!vm.envOr("ENSV2_BROADCAST", false), "ENSV2_BROADCAST must be false");

        string memory parentName = vm.envOr("ENSV2_PARENT_NAME", string(""));
        string memory passportLabel = vm.envOr("ENSV2_PASSPORT_LABEL", string("victor"));
        address platform = vm.envOr("ENSV2_PLATFORM_ADDRESS", makeAddr("platform"));
        address user = vm.envOr("ENSV2_PASSPORT_OWNER_ADDRESS", makeAddr("user"));

        console2.log("=== PLAN: Passport provisioning (simulation only) ===");
        console2.log("deploymentProfile", deployment.name);
        console2.log("Sepolia VerifiableFactory", deployment.verifiableFactory);
        console2.log("Sepolia UserRegistryImpl", deployment.userRegistryImpl);
        console2.log("Sepolia PermissionedResolverImpl", deployment.permissionedResolverImpl);
        console2.log("configured parentName", parentName);
        console2.log("passportLabel", passportLabel);
        console2.log("platform", platform);
        console2.log("user", user);

        console2.log("--- Ordered future Sepolia calls ---");
        console2.log("1 parent authority: platform ROLE_REGISTRAR on parent registry");
        console2.log("2 UserRegistry proxy via VerifiableFactory.deployProxy");
        console2.logBytes32(VerifiableFactory.deployProxy.selector);
        console2.log("3 PermissionedResolver proxy via VerifiableFactory.deployProxy");
        console2.log("4 ParentRegistry.register(passportLabel, user, passportRegistry, resolver, roles, expiry)");
        console2.logBytes32(IStandardRegistry.register.selector);
        console2.log("5 ownership handoff: register mints directly to user");
        console2.log("6 PassportRegistry.setParent(parentRegistry, passportLabel) as user");
        console2.logBytes32(IStandardRegistry.setParent.selector);
        console2.log("7 resolver records: setAddr + Nomadic passport text keys as user");
        console2.log("8 platform-role cleanup: platform must retain no Passport registry root roles");
        console2.log("Prerequisites: owned parent, platform registrar, RPC; broadcast only in a later slice");

        _simulateLocal(platform, user, passportLabel);
    }

    function _simulateLocal(address platform, address user, string memory passportLabel) internal {
        VerifiableFactory factory = new VerifiableFactory();
        LabelStore labelStore = new LabelStore(IContractNamer(address(0)));
        address namer = makeAddr("implNamer");
        UserRegistry userImpl = new UserRegistry(labelStore, namer);
        PermissionedRegistry parent = new PermissionedRegistry(
            labelStore, platform, RegistryRolesLib.ROLE_REGISTRAR | RegistryRolesLib.ROLE_REGISTRAR_ADMIN
        );

        UserRegistry passport = _deployPassportRegistry(factory, userImpl, user);
        PermissionedResolver resolver = _deployResolver(factory, user);

        uint256 gasStart = gasleft();
        vm.prank(platform);
        uint256 tokenId = parent.register(
            passportLabel,
            user,
            IRegistry(address(passport)),
            address(resolver),
            RegistryRolesLib.ROLE_SET_RESOLVER | RegistryRolesLib.ROLE_SET_SUBREGISTRY
                | RegistryRolesLib.ROLE_CAN_TRANSFER_ADMIN,
            type(uint64).max
        );

        vm.prank(user);
        passport.setParent(parent, passportLabel);
        _seedPassportRecords(resolver, user, passportLabel);

        console2.log("simulated tokenId", tokenId);
        console2.log("simulated owner", parent.ownerOf(tokenId));
        console2.log("approx gas", gasStart - gasleft());
        console2.log(
            "platformHasPassportRegistrar",
            passport.hasRootRoles(RegistryRolesLib.ROLE_REGISTRAR, platform) ? "true" : "false"
        );
        console2.log("RESULT: Passport plan simulation PASSED");
    }

    function _deployPassportRegistry(VerifiableFactory factory, UserRegistry userImpl, address user)
        internal
        returns (UserRegistry)
    {
        return UserRegistry(
            factory.deployProxy(
                address(userImpl),
                uint256(keccak256("passport")),
                abi.encodeCall(
                    UserRegistry.initialize,
                    (
                        user,
                        RegistryRolesLib.ROLE_REGISTRAR | RegistryRolesLib.ROLE_REGISTRAR_ADMIN
                            | RegistryRolesLib.ROLE_SET_PARENT | RegistryRolesLib.ROLE_SET_PARENT_ADMIN
                    )
                )
            )
        );
    }

    function _deployResolver(VerifiableFactory factory, address user) internal returns (PermissionedResolver) {
        PermissionedResolver resolverImpl = new PermissionedResolver(makeAddr("resolverNamer"));
        return PermissionedResolver(
            factory.deployProxy(
                address(resolverImpl),
                uint256(keccak256("resolver")),
                abi.encodeCall(PermissionedResolver.initialize, (user, EACBaseRolesLib.ALL_ROLES, new bytes[](0)))
            )
        );
    }

    function _seedPassportRecords(PermissionedResolver resolver, address user, string memory passportLabel) internal {
        bytes32 node = NameCoder.namehash(NameCoder.encode(string.concat(passportLabel, ".parent.eth")), 0);
        vm.startPrank(user);
        resolver.setAddr(node, user);
        resolver.setText(node, NomadicRecords.TYPE_KEY, NomadicRecords.TYPE_PASSPORT);
        vm.stopPrank();
    }
}
