// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2} from "forge-std/Script.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";

import {RegistryRolesLib} from "ensv2/registry/libraries/RegistryRolesLib.sol";

import {ENSv2DeploymentProfiles} from "../../src/ensv2/ENSv2DeploymentProfiles.sol";
import {ENSv2ExecutionBase, IENSv2R2Registry, IENSv2UniversalResolver} from "./ENSv2ExecutionBase.sol";

/// @notice Broadcast-capable one-time parent-link operation. Locked until explicit ENS routing ACK.
/// @dev This task only prepares this script; do not execute until ENS confirms routing stability.
contract SetParentExplorerR2Script is ENSv2ExecutionBase {
    function run() external {
        ENSv2DeploymentProfiles.Profile memory deployment = _loadProfile();
        _requireSepolia(deployment);
        _requireExplorerR2(deployment);

        address platform = _platform();
        IENSv2R2Registry nomadic = IENSv2R2Registry(deployment.nomadicRegistry);
        IENSv2R2Registry ethRegistry = IENSv2R2Registry(deployment.ethRegistry);

        _assertExplorerRouting(deployment);

        (address oldParent, string memory oldLabel) = nomadic.getParent();
        require(oldParent == address(0) && bytes(oldLabel).length == 0, "Nomadic parent already configured");
        require(nomadic.hasRootRoles(RegistryRolesLib.ROLE_SET_PARENT, platform), "platform missing ROLE_SET_PARENT");
        require(ethRegistry.findOwner(PARENT_LABEL) == platform, "platform is not parent owner");
        require(ethRegistry.getSubregistry(PARENT_LABEL) == deployment.nomadicRegistry, "downward subregistry mismatch");
        require(ethRegistry.getResolver(PARENT_LABEL) == deployment.nomadicResolver, "parent resolver mismatch");

        uint256 rolesBefore = nomadic.roles(0, platform);
        address ownerBefore = ethRegistry.findOwner(PARENT_LABEL);
        address resolverBefore = ethRegistry.getResolver(PARENT_LABEL);
        address subregistryBefore = ethRegistry.getSubregistry(PARENT_LABEL);

        _requireBroadcastUnlocked(deployment);

        vm.startBroadcast(platform);
        nomadic.setParent(deployment.ethRegistry, PARENT_LABEL);
        vm.stopBroadcast();

        (address newParent, string memory newLabel) = nomadic.getParent();
        require(newParent == deployment.ethRegistry, "parent postcondition");
        require(keccak256(bytes(newLabel)) == keccak256(bytes(PARENT_LABEL)), "label postcondition");
        require(ethRegistry.findOwner(PARENT_LABEL) == ownerBefore, "owner changed");
        require(ethRegistry.getResolver(PARENT_LABEL) == resolverBefore, "resolver changed");
        require(ethRegistry.getSubregistry(PARENT_LABEL) == subregistryBefore, "subregistry changed");
        require(nomadic.roles(0, platform) == rolesBefore, "platform roles changed");

        bytes memory parentDns = NameCoder.encode(PARENT_NAME);
        require(
            IENSv2UniversalResolver(deployment.topUniversalResolver).findCanonicalRegistry(parentDns)
                == deployment.nomadicRegistry,
            "canonical registry postcondition"
        );

        console2.log("setParent target", deployment.nomadicRegistry);
        console2.log("setParent parent", deployment.ethRegistry);
        console2.log("setParent label", PARENT_LABEL);
        console2.log("RESULT: Explorer-r2 setParent completed");
    }
}
