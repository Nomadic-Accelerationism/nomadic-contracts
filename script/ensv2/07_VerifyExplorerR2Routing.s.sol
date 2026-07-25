// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2} from "forge-std/Script.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";

import {ENSv2DeploymentProfiles} from "../../src/ensv2/ENSv2DeploymentProfiles.sol";
import {ENSv2ExecutionBase, IENSv2Proxy, IENSv2UniversalResolver} from "./ENSv2ExecutionBase.sol";

/// @notice Reusable read-only go/no-go check for the temporary Explorer-r2 routing.
contract VerifyExplorerR2RoutingScript is ENSv2ExecutionBase {
    function run() external view {
        ENSv2DeploymentProfiles.Profile memory deployment = _loadProfile();
        _requireSepolia(deployment);
        _assertExplorerRouting(deployment);

        address topImplementation = IENSv2Proxy(deployment.topUniversalResolver).implementation();
        address managedImplementation = IENSv2Proxy(deployment.managedUniversalResolver).implementation();
        address root = IENSv2UniversalResolver(deployment.universalResolver).ROOT_REGISTRY();
        bytes memory parentDns = NameCoder.encode(PARENT_NAME);
        address owner = IENSv2UniversalResolver(deployment.topUniversalResolver).findOwner(parentDns);
        address exact = IENSv2UniversalResolver(deployment.topUniversalResolver).findExactRegistry(parentDns);

        console2.log("deploymentProfile", deployment.name);
        console2.log("topUniversalResolver", deployment.topUniversalResolver);
        console2.log("topImplementation", topImplementation);
        console2.log("managedImplementation", managedImplementation);
        console2.log("resolverRootRegistry", root);
        console2.log("nomadicOwner", owner);
        console2.log("nomadicExactRegistry", exact);
        console2.log("RESULT: Explorer-r2 routing guard PASSED");
    }
}
