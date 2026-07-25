// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {ENSv2DeploymentProfiles} from "../../src/ensv2/ENSv2DeploymentProfiles.sol";
import {ENSv2ExecutionBase} from "../../script/ensv2/ENSv2ExecutionBase.sol";

contract DeploymentProfileHarness is ENSv2ExecutionBase {
    function load() external view returns (ENSv2DeploymentProfiles.Profile memory) {
        return _loadProfile();
    }

    function requireBroadcastUnlocked() external view {
        _requireBroadcastUnlocked(_loadProfile());
    }
}

contract DeploymentProfilesTest is Test {
    using stdJson for string;

    DeploymentProfileHarness internal harness;

    function setUp() public {
        harness = new DeploymentProfileHarness();
    }

    function test_profileIsRequired() public {
        vm.setEnv("ENSV2_DEPLOYMENT_PROFILE", "");
        vm.expectRevert(ENSv2ExecutionBase.ENSV2_DEPLOYMENT_PROFILE_REQUIRED.selector);
        harness.load();
    }

    function test_invalidProfileRejected() public {
        vm.setEnv("ENSV2_DEPLOYMENT_PROFILE", "mixed");
        vm.expectRevert(ENSv2ExecutionBase.ENSV2_DEPLOYMENT_PROFILE_INVALID.selector);
        harness.load();
    }

    function test_currentProfileUsesOnlyCurrentAddresses() public {
        vm.setEnv("ENSV2_DEPLOYMENT_PROFILE", "current");
        ENSv2DeploymentProfiles.Profile memory p = harness.load();
        assertEq(p.name, "current");
        assertEq(p.rootRegistry, 0x11b5BfbE9078D826b1eDBDd1cFC12f5828D9F50C);
        assertEq(p.ethRegistry, 0x67b728a792e789a8978b30cF1b3b641f19354b43);
        assertEq(p.nomadicRegistry, address(0));
        assertFalse(p.historicalResolverInitializer);
    }

    function test_explorerProfileUsesHistoricalArtifactsOnly() public {
        vm.setEnv("ENSV2_DEPLOYMENT_PROFILE", "explorer-v1-r2");
        ENSv2DeploymentProfiles.Profile memory p = harness.load();
        assertEq(p.name, "explorer-v1-r2");
        assertEq(p.rootRegistry, 0xc960F7217d3643B525Ef36Bec8Adf86953CD9aB8);
        assertEq(p.ethRegistry, 0xDEDB92913A25abE1f7BCDD85D8A344a43B398B67);
        assertEq(p.nomadicRegistry, 0x8fB12e7Ab9B192503d7d02a43e0507c484e27280);
        assertTrue(p.historicalResolverInitializer);
    }

    function test_profileLibrariesMatchSplitJsonFiles() public view {
        _assertJsonMatches(ENSv2DeploymentProfiles.current());
        _assertJsonMatches(ENSv2DeploymentProfiles.explorerR2());
    }

    function test_broadcastRequiresBooleanLock() public {
        vm.setEnv("ENSV2_DEPLOYMENT_PROFILE", "explorer-v1-r2");
        vm.setEnv("ENSV2_BROADCAST", "false");
        vm.setEnv("ENSV2_ROUTING_ACK", "explorer-v1-r2-confirmed");
        vm.expectRevert(ENSv2ExecutionBase.ENSV2_BROADCAST_LOCKED.selector);
        harness.requireBroadcastUnlocked();
    }

    function test_broadcastRequiresExactRoutingAck() public {
        vm.setEnv("ENSV2_DEPLOYMENT_PROFILE", "explorer-v1-r2");
        vm.setEnv("ENSV2_BROADCAST", "true");
        vm.setEnv("ENSV2_ROUTING_ACK", "not-confirmed");
        vm.expectRevert(ENSv2ExecutionBase.ENSV2_ROUTING_ACK_REQUIRED.selector);
        harness.requireBroadcastUnlocked();
    }

    function test_broadcastLocksOpenOnlyWithBothExactValues() public {
        vm.setEnv("ENSV2_DEPLOYMENT_PROFILE", "explorer-v1-r2");
        vm.setEnv("ENSV2_BROADCAST", "true");
        vm.setEnv("ENSV2_ROUTING_ACK", "explorer-v1-r2-confirmed");
        harness.requireBroadcastUnlocked();
    }

    function _assertJsonMatches(ENSv2DeploymentProfiles.Profile memory p) private view {
        string memory raw = vm.readFile(p.addressFile);
        assertEq(raw.readString(".profile"), p.name);
        assertEq(raw.readUint(".chainId"), p.chainId);
        assertEq(raw.readAddress(".addresses.RootRegistry"), p.rootRegistry);
        assertEq(raw.readAddress(".addresses.ETHRegistry"), p.ethRegistry);
        assertEq(raw.readAddress(".addresses.ETHRegistrar"), p.ethRegistrar);
        assertEq(raw.readAddress(".addresses.VerifiableFactory"), p.verifiableFactory);
        assertEq(raw.readAddress(".addresses.UserRegistryImpl"), p.userRegistryImpl);
        assertEq(raw.readAddress(".addresses.PermissionedResolverImpl"), p.permissionedResolverImpl);
        assertEq(raw.readAddress(".addresses.UniversalResolverV2"), p.universalResolver);
        assertEq(raw.readAddress(".addresses.ManagedUniversalResolverProxy"), p.managedUniversalResolver);
        assertEq(raw.readAddress(".addresses.UpgradableUniversalResolverProxy"), p.topUniversalResolver);
        if (p.id == ENSv2DeploymentProfiles.EXPLORER_R2_ID) {
            assertEq(raw.readAddress(".addresses.NomadicUserRegistry"), p.nomadicRegistry);
            assertEq(raw.readAddress(".addresses.NomadicResolver"), p.nomadicResolver);
        }
    }
}
