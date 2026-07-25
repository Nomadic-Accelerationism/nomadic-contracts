// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2} from "forge-std/Script.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";

import {NomadicRecords} from "../../src/ensv2/NomadicRecords.sol";
import {ENSv2DeploymentProfiles} from "../../src/ensv2/ENSv2DeploymentProfiles.sol";
import {ENSv2ExecutionBase, IENSv2R2Factory, IENSv2R2Registry, IENSv2R2Resolver} from "./ENSv2ExecutionBase.sol";

/// @notice Emits an ordered, frontend-consumable Magic wallet call bundle. Never broadcasts.
contract BuildMagicBundleExplorerR2Script is ENSv2ExecutionBase {
    struct Call {
        string label;
        address to;
        bytes data;
        uint256 value;
    }

    struct TransactionGroup {
        string label;
        address to;
        bytes data;
        uint256 value;
        bool atomic;
        uint256 estimatedGas;
        string precondition;
        string postcondition;
        Call[] calls;
    }

    function run() external view {
        ENSv2DeploymentProfiles.Profile memory deployment = _loadProfile();
        _requireSepolia(deployment);
        _requireExplorerR2(deployment);
        _assertExplorerRouting(deployment);
        require(!vm.envOr("ENSV2_BROADCAST", false), "bundle builder never broadcasts");

        address platform = _platform();
        address user = _passportOwner();
        address issuer = _issuer();
        _assertDistinctActors(platform, user, issuer);

        (address passportRegistry, address passportResolver) = _predictedPassportContracts(deployment, platform);

        // The bundle is valid before deployment (deterministic addresses) and after deployment.
        if (passportRegistry.code.length > 0) {
            require(
                IENSv2R2Factory(deployment.verifiableFactory)
                    .verifyContract(passportRegistry, deployment.userRegistryImpl),
                "unexpected Passport registry"
            );
        }
        if (passportResolver.code.length > 0) {
            require(
                IENSv2R2Factory(deployment.verifiableFactory)
                    .verifyContract(passportResolver, deployment.permissionedResolverImpl),
                "unexpected Passport resolver"
            );
        }

        string memory issuedAt = vm.envOr("ENSV2_ISSUED_AT", vm.toString(block.timestamp));
        Call[] memory logicalCalls =
            _buildLogicalCalls(deployment, user, issuer, passportRegistry, passportResolver, issuedAt);
        TransactionGroup[] memory groups = _groupCalls(passportRegistry, passportResolver, logicalCalls);

        console2.log("passportRegistry", passportRegistry);
        console2.log("passportResolver", passportResolver);
        console2.log("expectedSigner", user);
        console2.log(string.concat("logicalContractCalls=", vm.toString(logicalCalls.length)));
        console2.log(string.concat("onchainTransactions=", vm.toString(groups.length)));
        console2.log(string.concat("expectedMagicConfirmations=", vm.toString(groups.length)));
        console2.log(_toJson(user, issuer, passportRegistry, passportResolver, issuedAt, logicalCalls.length, groups));
        console2.log("RESULT: Magic transaction bundle generated (read-only)");
    }

    function _buildLogicalCalls(
        ENSv2DeploymentProfiles.Profile memory deployment,
        address user,
        address issuer,
        address passportRegistry,
        address passportResolver,
        string memory issuedAt
    ) internal view returns (Call[] memory calls) {
        calls = new Call[](19);
        uint256 i;

        bytes memory passportDns = NameCoder.encode(PASSPORT_NAME);
        bytes memory credentialDns = NameCoder.encode(CREDENTIAL_NAME);
        bytes32 passportNode = NameCoder.namehash(passportDns, 0);
        bytes32 credentialNode = NameCoder.namehash(credentialDns, 0);

        calls[i++] = Call({
            label: "Configure Passport registry parent",
            to: passportRegistry,
            data: abi.encodeCall(IENSv2R2Registry.setParent, (deployment.nomadicRegistry, PASSPORT_LABEL)),
            value: 0
        });
        calls[i++] = Call({
            label: "Set Passport address",
            to: passportResolver,
            data: abi.encodeCall(IENSv2R2Resolver.setAddr, (passportNode, user)),
            value: 0
        });
        calls[i++] = _textCall(
            passportResolver, passportNode, NomadicRecords.TYPE_KEY, NomadicRecords.TYPE_PASSPORT, "Set Passport type"
        );
        calls[i++] = _textCall(
            passportResolver,
            passportNode,
            NomadicRecords.PROFILE_KEY,
            "https://nomadic-front-rosy.vercel.app/p/victor.nomadic-passport.eth",
            "Set Passport profile"
        );
        calls[i++] = _textCall(
            passportResolver, passportNode, NomadicRecords.CURRENT_JOURNEY_KEY, CREDENTIAL_LABEL, "Set current journey"
        );
        calls[i++] = _textCall(
            passportResolver, passportNode, NomadicRecords.CREDENTIALS_KEY, CREDENTIAL_NAME, "Link Lisbon credential"
        );
        calls[i++] = Call({
            label: "Register Lisbon credential",
            to: passportRegistry,
            data: abi.encodeCall(
                IENSv2R2Registry.register,
                (CREDENTIAL_LABEL, user, address(0), passportResolver, _credentialOwnerRoles(), type(uint64).max)
            ),
            value: 0
        });
        calls[i++] = _textCall(
            passportResolver,
            credentialNode,
            NomadicRecords.TYPE_KEY,
            NomadicRecords.TYPE_JOURNEY_ELIGIBILITY,
            "Set credential type"
        );
        calls[i++] = _textCall(
            passportResolver, credentialNode, NomadicRecords.ISSUER_KEY, vm.toString(issuer), "Set credential issuer"
        );
        calls[i++] = _textCall(
            passportResolver, credentialNode, NomadicRecords.JOURNEY_KEY, CREDENTIAL_LABEL, "Set credential journey"
        );
        calls[i++] = _textCall(
            passportResolver,
            credentialNode,
            NomadicRecords.POLICY_KEY,
            "lisbon_house_policy_v1",
            "Set credential policy"
        );
        calls[i++] =
            _textCall(passportResolver, credentialNode, NomadicRecords.STATUS_KEY, "active", "Activate credential");
        calls[i++] = _textCall(
            passportResolver, credentialNode, NomadicRecords.ISSUED_AT_KEY, issuedAt, "Set credential issuedAt"
        );
        calls[i++] =
            _textCall(passportResolver, credentialNode, NomadicRecords.EXPIRES_AT_KEY, "", "Set empty expiresAt");
        calls[i++] = _textCall(passportResolver, credentialNode, NomadicRecords.METADATA_KEY, "", "Set empty metadata");

        string[] memory keys = NomadicRecords.issuerAllowlistedKeys();
        for (uint256 j; j < keys.length; ++j) {
            calls[i++] = Call({
                label: string.concat("Authorize issuer: ", keys[j]),
                to: passportResolver,
                data: abi.encodeCall(IENSv2R2Resolver.authorizeTextRoles, (credentialDns, keys[j], issuer, true)),
                value: 0
            });
        }
        require(i == calls.length, "Magic bundle call count");
    }

    function _groupCalls(address passportRegistry, address passportResolver, Call[] memory logicalCalls)
        internal
        pure
        returns (TransactionGroup[] memory groups)
    {
        require(logicalCalls.length == 19, "expected 19 logical calls");
        groups = new TransactionGroup[](5);

        Call[] memory parentCalls = _slice(logicalCalls, 0, 1);
        groups[0] = TransactionGroup({
            label: "Configure Passport registry",
            to: passportRegistry,
            data: logicalCalls[0].data,
            value: 0,
            atomic: true,
            estimatedGas: 76_565,
            precondition: "Passport registry deployed; Magic owns victor",
            postcondition: "Passport registry canonical parent is Nomadic registry",
            calls: parentCalls
        });

        Call[] memory passportRecordCalls = _slice(logicalCalls, 1, 5);
        groups[1] = TransactionGroup({
            label: "Set Passport records",
            to: passportResolver,
            data: abi.encodeCall(
                IENSv2R2Resolver.multicallWithNodeCheck,
                (NameCoder.namehash(NameCoder.encode(PASSPORT_NAME), 0), _callData(passportRecordCalls))
            ),
            value: 0,
            atomic: true,
            estimatedGas: 305_394,
            precondition: "Magic is Passport resolver root admin",
            postcondition: "Passport addr and four text records are readable",
            calls: passportRecordCalls
        });

        Call[] memory credentialRegistrationCalls = _slice(logicalCalls, 6, 1);
        groups[2] = TransactionGroup({
            label: "Register Lisbon credential",
            to: passportRegistry,
            data: logicalCalls[6].data,
            value: 0,
            atomic: true,
            estimatedGas: 162_012,
            precondition: "Passport registry parent configured; Magic has ROLE_REGISTRAR",
            postcondition: "Credential ERC-1155 owner is Magic",
            calls: credentialRegistrationCalls
        });

        Call[] memory credentialRecordCalls = _slice(logicalCalls, 7, 8);
        groups[3] = TransactionGroup({
            label: "Set credential records",
            to: passportResolver,
            data: abi.encodeCall(
                IENSv2R2Resolver.multicallWithNodeCheck,
                (NameCoder.namehash(NameCoder.encode(CREDENTIAL_NAME), 0), _callData(credentialRecordCalls))
            ),
            value: 0,
            atomic: true,
            estimatedGas: 304_997,
            precondition: "Credential registration succeeded",
            postcondition: "Eight credential text records are readable",
            calls: credentialRecordCalls
        });

        Call[] memory authorizationCalls = _slice(logicalCalls, 15, 4);
        groups[4] = TransactionGroup({
            label: "Authorize scoped issuer keys",
            to: passportResolver,
            data: abi.encodeCall(IENSv2R2Resolver.multicall, (_callData(authorizationCalls))),
            value: 0,
            atomic: true,
            estimatedGas: 267_596,
            precondition: "Credential records initialized; issuer distinct from platform and Magic",
            postcondition: "Issuer has only four exact per-key text permissions",
            calls: authorizationCalls
        });
    }

    function _slice(Call[] memory source, uint256 start, uint256 count) private pure returns (Call[] memory result) {
        result = new Call[](count);
        for (uint256 i; i < count; ++i) {
            result[i] = source[start + i];
        }
    }

    function _callData(Call[] memory calls) private pure returns (bytes[] memory data) {
        data = new bytes[](calls.length);
        for (uint256 i; i < calls.length; ++i) {
            data[i] = calls[i].data;
        }
    }

    function _textCall(address resolver, bytes32 node, string memory key, string memory value, string memory label)
        private
        pure
        returns (Call memory)
    {
        return Call({
            label: label, to: resolver, data: abi.encodeCall(IENSv2R2Resolver.setText, (node, key, value)), value: 0
        });
    }

    function _toJson(
        address user,
        address issuer,
        address passportRegistry,
        address passportResolver,
        string memory issuedAt,
        uint256 logicalCallCount,
        TransactionGroup[] memory groups
    ) private view returns (string memory json) {
        json = string.concat(
            '{"chainId":11155111,"deploymentProfile":"explorer-v1-r2",',
            '"passport":"',
            PASSPORT_NAME,
            '","expectedSigner":"',
            vm.toString(user),
            '","issuer":"',
            vm.toString(issuer),
            '","passportRegistry":"',
            vm.toString(passportRegistry),
            '","passportResolver":"',
            vm.toString(passportResolver),
            '","issuedAt":"',
            issuedAt,
            '","logicalContractCalls":',
            vm.toString(logicalCallCount),
            ',"onchainTransactions":',
            vm.toString(groups.length),
            ',"expectedMagicConfirmations":',
            vm.toString(groups.length),
            ',"transactionGroups":['
        );
        for (uint256 i; i < groups.length; ++i) {
            if (i != 0) json = string.concat(json, ",");
            json = string.concat(
                json,
                '{"index":',
                vm.toString(i + 1),
                ',"label":"',
                groups[i].label,
                '","to":"',
                vm.toString(groups[i].to),
                '","data":"',
                vm.toString(groups[i].data),
                '","value":"',
                vm.toString(groups[i].value),
                '","atomic":',
                groups[i].atomic ? "true" : "false",
                ',"estimatedGas":',
                vm.toString(groups[i].estimatedGas),
                ',"preconditions":["',
                groups[i].precondition,
                '"],"postconditions":["',
                groups[i].postcondition,
                '"],"calls":',
                _callsJson(groups[i].calls),
                "}"
            );
        }
        return string.concat(json, "]}");
    }

    function _callsJson(Call[] memory calls) private view returns (string memory json) {
        json = "[";
        for (uint256 i; i < calls.length; ++i) {
            if (i != 0) json = string.concat(json, ",");
            json = string.concat(
                json,
                '{"label":"',
                calls[i].label,
                '","to":"',
                vm.toString(calls[i].to),
                '","data":"',
                vm.toString(calls[i].data),
                '","value":"',
                vm.toString(calls[i].value),
                '"}'
            );
        }
        return string.concat(json, "]");
    }
}
