// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2} from "forge-std/Script.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";

import {IRegistry} from "ensv2/registry/interfaces/IRegistry.sol";
import {IOwnedRegistry} from "ensv2/registry/interfaces/IOwnedRegistry.sol";
import {ITemporalRegistry} from "ensv2/registry/interfaces/ITemporalRegistry.sol";
import {IPermissionedRegistry} from "ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {RegistryRolesLib} from "ensv2/registry/libraries/RegistryRolesLib.sol";
import {IUniversalResolverV2} from "ensv2/universalResolver/interfaces/IUniversalResolverV2.sol";
import {UniversalResolverV2} from "ensv2/universalResolver/UniversalResolverV2.sol";

import {ENSv2DeploymentProfiles} from "../../src/ensv2/ENSv2DeploymentProfiles.sol";
import {ENSv2ExecutionBase} from "./ENSv2ExecutionBase.sol";

/// @notice Read-only parent namespace inspection. Never broadcasts. Never hardcodes a parent name.
contract InspectParentScript is ENSv2ExecutionBase {
    function run() external view {
        ENSv2DeploymentProfiles.Profile memory deployment = _loadProfile();
        _requireSepolia(deployment);

        string memory parentName = vm.envOr("ENSV2_PARENT_NAME", string(""));
        require(
            bytes(parentName).length > 0, "ENSV2_PARENT_NAME is required (no hardcoded parent; set env before running)"
        );

        address platform = vm.envOr("ENSV2_PLATFORM_ADDRESS", address(0));

        bytes memory dnsName = NameCoder.encode(parentName);
        console2.log("deploymentProfile", deployment.name);
        console2.log("parentName", parentName);
        console2.logBytes(dnsName);

        IUniversalResolverV2 ur = IUniversalResolverV2(deployment.universalResolver);
        UniversalResolverV2 urConcrete = UniversalResolverV2(deployment.universalResolver);

        IRegistry exact = ur.findExactRegistry(dnsName);
        IRegistry canonical = ur.findCanonicalRegistry(dnsName);
        IRegistry containing = ur.findParentRegistry(dnsName);
        console2.log("exactRegistry", address(exact));
        console2.log("canonicalRegistry", address(canonical));
        console2.log("containingRegistry", address(containing));

        (address resolver,,) = urConcrete.findResolver(dnsName);
        console2.log("resolver", resolver);

        address owner;
        try ur.findOwner(dnsName) returns (address o) {
            owner = o;
            console2.log("owner", owner);
        } catch {
            console2.log("owner: unreadable via UniversalResolverV2.findOwner");
        }

        string memory label = _firstLabel(parentName);
        console2.log("label", label);

        if (address(containing) != address(0)) {
            try IOwnedRegistry(address(containing)).findOwner(label) returns (address labelOwner) {
                console2.log("labelOwner", labelOwner);
                if (owner == address(0)) owner = labelOwner;
            } catch {
                console2.log("findOwner(label) unavailable on containing registry");
            }

            try ITemporalRegistry(address(containing)).findExpiry(label) returns (uint64 expiry) {
                console2.log("expiry", uint256(expiry));
            } catch {
                console2.log("findExpiry(label) unavailable");
            }

            try IRegistry(containing).getSubregistry(label) returns (IRegistry sub) {
                console2.log("subregistry", address(sub));
            } catch {
                console2.log("getSubregistry(label) unavailable");
            }

            try IRegistry(containing).getResolver(label) returns (address res) {
                console2.log("labelResolver", res);
            } catch {}
        }

        if (address(exact) != address(0)) {
            try IRegistry(exact).getParent() returns (IRegistry p, string memory plabel) {
                console2.log("exact.getParent registry", address(p));
                console2.log("exact.getParent label", plabel);
            } catch {
                console2.log("exact.getParent unavailable");
            }
        }

        IRegistry childRegistry = address(canonical) != address(0) ? canonical : exact;
        bool platformCanCreateChild = false;
        if (platform != address(0) && address(childRegistry) != address(0)) {
            try IPermissionedRegistry(address(childRegistry))
                .hasRootRoles(RegistryRolesLib.ROLE_REGISTRAR, platform) returns (
                bool ok
            ) {
                platformCanCreateChild = ok;
            } catch {
                console2.log("hasRootRoles(ROLE_REGISTRAR) unavailable on child registry");
            }
        } else if (platform == address(0)) {
            console2.log("ENSV2_PLATFORM_ADDRESS unset; cannot assess child-creation ability");
        }
        console2.log("childRegistry", address(childRegistry));
        console2.log("platformAppearsAbleToCreateChild", platformCanCreateChild ? "true" : "false");

        bool canonicalReady = address(canonical) == address(childRegistry) && address(canonical) != address(0);
        console2.log("canonicalParentReady", canonicalReady ? "true" : "false");

        bool suitable = canonicalReady && owner != address(0) && (platform == address(0) || platformCanCreateChild);
        console2.log("parentSuitableForPrototype", suitable ? "true" : "false");

        if (!suitable) {
            revert("parent not suitable: require canonical registry, owner, and platform registrar");
        }
        console2.log("RESULT: parent inspection PASSED (read-only)");
    }

    function _firstLabel(string memory name) internal pure returns (string memory) {
        bytes memory b = bytes(name);
        uint256 end = b.length;
        for (uint256 i = 0; i < b.length; i++) {
            // ASCII '.' fits in one byte.
            // forge-lint: disable-next-line(unsafe-typecast)
            if (b[i] == bytes1(".")) {
                end = i;
                break;
            }
        }
        bytes memory out = new bytes(end);
        for (uint256 j = 0; j < end; j++) {
            out[j] = b[j];
        }
        return string(out);
    }
}
