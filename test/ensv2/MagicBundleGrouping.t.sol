// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";

import {ENSv2DeploymentProfiles} from "../../src/ensv2/ENSv2DeploymentProfiles.sol";
import {BuildMagicBundleExplorerR2Script} from "../../script/ensv2/10_BuildMagicBundleExplorerR2.s.sol";
import {IENSv2R2Registry, IENSv2R2Resolver} from "../../script/ensv2/ENSv2ExecutionBase.sol";

contract MagicBundleGroupingHarness is BuildMagicBundleExplorerR2Script {
    function summary()
        external
        view
        returns (
            uint256 logicalCallCount,
            uint256 transactionCount,
            uint256[5] memory innerCallCounts,
            bytes4[5] memory selectors,
            uint256 totalEstimatedGas
        )
    {
        ENSv2DeploymentProfiles.Profile memory p = ENSv2DeploymentProfiles.explorerR2();
        address registry = 0x40776D16B117b04FD5C08458E14ff8CF6518a40E;
        address resolver = 0x467B72a46F578a47878137883Ce35c980393Bffe;
        Call[] memory logicalCalls = _buildLogicalCalls(
            p,
            0xd114FA765bA4811219AAe364c93CE8A81Ad39B17,
            0x3333333333333333333333333333333333333333,
            registry,
            resolver,
            "RUNTIME_TIMESTAMP"
        );
        TransactionGroup[] memory groups = _groupCalls(registry, resolver, logicalCalls);

        logicalCallCount = logicalCalls.length;
        transactionCount = groups.length;
        for (uint256 i; i < groups.length; ++i) {
            innerCallCounts[i] = groups[i].calls.length;
            selectors[i] = bytes4(groups[i].data);
            totalEstimatedGas += groups[i].estimatedGas;
        }
    }
}

contract MagicBundleGroupingTest is Test {
    MagicBundleGroupingHarness internal harness;

    function setUp() public {
        harness = new MagicBundleGroupingHarness();
    }

    function test_groupsNineteenLogicalCallsIntoFiveTransactions() public view {
        (
            uint256 logicalCallCount,
            uint256 transactionCount,
            uint256[5] memory innerCallCounts,
            bytes4[5] memory selectors,
            uint256 totalEstimatedGas
        ) = harness.summary();

        assertEq(logicalCallCount, 19);
        assertEq(transactionCount, 5);
        assertEq(innerCallCounts[0], 1);
        assertEq(innerCallCounts[1], 5);
        assertEq(innerCallCounts[2], 1);
        assertEq(innerCallCounts[3], 8);
        assertEq(innerCallCounts[4], 4);
        assertEq(selectors[0], IENSv2R2Registry.setParent.selector);
        assertEq(selectors[1], IENSv2R2Resolver.multicallWithNodeCheck.selector);
        assertEq(selectors[2], IENSv2R2Registry.register.selector);
        assertEq(selectors[3], IENSv2R2Resolver.multicallWithNodeCheck.selector);
        assertEq(selectors[4], IENSv2R2Resolver.multicall.selector);
        assertEq(totalEstimatedGas, 1_116_564);
    }
}
