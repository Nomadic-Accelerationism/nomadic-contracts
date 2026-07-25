// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2} from "forge-std/Script.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";

import {RegistryRolesLib} from "ensv2/registry/libraries/RegistryRolesLib.sol";

import {ENSv2DeploymentProfiles} from "../../src/ensv2/ENSv2DeploymentProfiles.sol";
import {ENSv2ExecutionBase, IENSv2R2Factory, IENSv2R2Registry, IENSv2UniversalResolver} from "./ENSv2ExecutionBase.sol";

/// @notice Platform phase: deploy user-administered Passport contracts and mint `victor` to Magic.
/// @dev Uses the historical r2 initialize(address,uint256) ABI. Locked until routing is acknowledged.
contract IssuePassportExplorerR2Script is ENSv2ExecutionBase {
    function run() external {
        ENSv2DeploymentProfiles.Profile memory deployment = _loadProfile();
        _requireSepolia(deployment);
        _requireExplorerR2(deployment);

        address platform = _platform();
        address user = _passportOwner();
        require(platform != user, "platform must differ from Passport owner");
        require(user.code.length == 0, "Passport owner must be EOA or IERC1155Receiver");

        _assertExplorerRouting(deployment);

        IENSv2R2Registry nomadic = IENSv2R2Registry(deployment.nomadicRegistry);
        require(
            IENSv2R2Registry(deployment.ethRegistry).findOwner(PARENT_LABEL) == platform, "platform is not parent owner"
        );
        (address parent, string memory label) = nomadic.getParent();
        require(parent == deployment.ethRegistry, "Nomadic canonical parent not configured");
        require(keccak256(bytes(label)) == keccak256(bytes(PARENT_LABEL)), "Nomadic parent label mismatch");
        require(nomadic.hasRootRoles(RegistryRolesLib.ROLE_REGISTRAR, platform), "platform missing ROLE_REGISTRAR");
        require(nomadic.findOwner(PASSPORT_LABEL) == address(0), "victor already registered");

        (address expectedRegistry, address expectedResolver) = _predictedPassportContracts(deployment, platform);
        require(expectedRegistry.code.length == 0, "Passport registry CREATE2 collision");
        require(expectedResolver.code.length == 0, "Passport resolver CREATE2 collision");

        _requireBroadcastUnlocked(deployment);

        IENSv2R2Factory factory = IENSv2R2Factory(deployment.verifiableFactory);
        bytes memory init = _historicalInitialize(user);

        vm.startBroadcast(platform);
        address passportRegistry = factory.deployProxy(deployment.userRegistryImpl, PASSPORT_REGISTRY_SALT, init);
        address passportResolver =
            factory.deployProxy(deployment.permissionedResolverImpl, PASSPORT_RESOLVER_SALT, init);
        uint256 tokenId = nomadic.register(
            PASSPORT_LABEL, user, passportRegistry, passportResolver, _passportOwnerRoles(), type(uint64).max
        );
        vm.stopBroadcast();

        require(passportRegistry == expectedRegistry, "Passport registry address mismatch");
        require(passportResolver == expectedResolver, "Passport resolver address mismatch");
        require(factory.verifyContract(passportRegistry, deployment.userRegistryImpl), "registry proxy verification");
        require(
            factory.verifyContract(passportResolver, deployment.permissionedResolverImpl), "resolver proxy verification"
        );
        require(nomadic.ownerOf(tokenId) == user, "Passport owner postcondition");
        require(
            IENSv2R2Registry(passportRegistry).hasRootRoles(RegistryRolesLib.ROLE_REGISTRAR, user),
            "user missing Passport registrar"
        );
        require(
            !IENSv2R2Registry(passportRegistry).hasRootRoles(RegistryRolesLib.ROLE_REGISTRAR, platform),
            "platform retained Passport registrar"
        );
        require(
            IENSv2UniversalResolver(deployment.topUniversalResolver).findOwner(NameCoder.encode(PASSPORT_NAME)) == user,
            "top Universal Resolver owner mismatch"
        );

        console2.log("passportTokenId", tokenId);
        console2.log("passportRegistry", passportRegistry);
        console2.log("passportResolver", passportResolver);
        console2.log("passportOwner", user);
        console2.log("NEXT: generate and sign the Magic transaction bundle");
    }
}
