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
        Call[] memory calls = _buildCalls(deployment, user, issuer, passportRegistry, passportResolver, issuedAt);

        console2.log("passportRegistry", passportRegistry);
        console2.log("passportResolver", passportResolver);
        console2.log("expectedSigner", user);
        console2.log(string.concat("callCount=", vm.toString(calls.length)));
        console2.log(_toJson(user, issuer, passportRegistry, passportResolver, issuedAt, calls));
        console2.log("RESULT: Magic transaction bundle generated (read-only)");
    }

    function _buildCalls(
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
        Call[] memory calls
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
            '","calls":['
        );
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
        return string.concat(json, "]}");
    }
}
