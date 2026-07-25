// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2} from "forge-std/Script.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {EACBaseRolesLib} from "ensv2/access-control/libraries/EACBaseRolesLib.sol";
import {IEnhancedAccessControl} from "ensv2/access-control/interfaces/IEnhancedAccessControl.sol";
import {PermissionedResolverLib} from "ensv2/resolver/libraries/PermissionedResolverLib.sol";
import {RegistryRolesLib} from "ensv2/registry/libraries/RegistryRolesLib.sol";

import {NomadicRecords} from "../../src/ensv2/NomadicRecords.sol";
import {ENSv2DeploymentProfiles} from "../../src/ensv2/ENSv2DeploymentProfiles.sol";
import {
    ENSv2ExecutionBase,
    IENSv2R2Factory,
    IENSv2R2Registry,
    IENSv2R2Resolver,
    IENSv2UniversalResolver
} from "./ENSv2ExecutionBase.sol";

interface IAlchemySemiModularAccount7702 {
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    function executeBatch(Call[] calldata calls) external payable returns (bytes[] memory results);
}

/// @notice Full stateful Explorer-r2 rehearsal against a Sepolia fork. Never broadcasts.
contract RehearseExplorerR2ForkScript is ENSv2ExecutionBase {
    address internal constant SYNTHETIC_ISSUER = 0x3333333333333333333333333333333333333333;
    address internal constant ALCHEMY_SEMI_MODULAR_ACCOUNT_7702 = 0x69007702764179f14F51cdce752f4f775d74E139;

    struct Actors {
        address platform;
        address user;
        address issuer;
    }

    struct Hierarchy {
        address passportRegistry;
        address passportResolver;
        uint256 passportTokenId;
        uint256 credentialTokenId;
        bytes passportDns;
        bytes credentialDns;
        bytes32 passportNode;
        bytes32 credentialNode;
    }

    uint256 internal platformGas;
    uint256 internal userGas;
    uint256 internal issuerGas;
    uint256 internal revocationGas;
    uint256[5] internal magicGroupGas;
    bool internal useMagic7702;

    function run() external {
        ENSv2DeploymentProfiles.Profile memory deployment = _loadProfile();
        _requireSepolia(deployment);
        _requireExplorerR2(deployment);
        require(!vm.envOr("ENSV2_BROADCAST", false), "rehearsal never broadcasts");

        Actors memory actors = _actors();
        _assertDistinctActors(actors.platform, actors.user, actors.issuer);
        _configureOptionalMagic7702(actors.user);

        vm.deal(actors.platform, 1 ether);
        vm.deal(actors.user, 1 ether);
        vm.deal(actors.issuer, 1 ether);

        _assertExplorerRouting(deployment);
        _assertCurrentNotInPath();

        uint256 g0 = gasleft();
        _setParent(deployment, actors.platform);
        platformGas += g0 - gasleft() + 21_000;

        g0 = gasleft();
        Hierarchy memory hierarchy = _issuePassport(deployment, actors);
        platformGas += g0 - gasleft() + 3 * 21_000;

        _configureMagicBundle(deployment, actors, hierarchy);

        _assertResolution(deployment, actors, hierarchy);
        _permissionDemo(actors, hierarchy);
        _assertCurrentNotInPath();

        console2.log(string.concat("platform_gas_estimate=", vm.toString(platformGas)));
        console2.log(string.concat("magic_gas_estimate=", vm.toString(userGas)));
        console2.log(string.concat("issuer_demo_gas_estimate=", vm.toString(issuerGas)));
        console2.log(string.concat("magic_revocation_gas_estimate=", vm.toString(revocationGas)));
        console2.log("logical_contract_calls=19");
        console2.log(string.concat("magic_onchain_transactions=", useMagic7702 ? "1" : "5"));
        console2.log(string.concat("magic_confirmation_prompts=", useMagic7702 ? "1" : "5"));
        for (uint256 i; i < magicGroupGas.length; ++i) {
            console2.log(string.concat("magic_group_", vm.toString(i + 1), "_gas=", vm.toString(magicGroupGas[i])));
        }
        console2.log("issuer", actors.issuer);
        console2.log("magic7702Enabled", useMagic7702 ? "true" : "false");
        console2.log("passportRegistry", hierarchy.passportRegistry);
        console2.log("passportResolver", hierarchy.passportResolver);
        console2.log("RESULT: Explorer-r2 full fork rehearsal PASSED");
    }

    function _actors() internal view returns (Actors memory actors) {
        actors.platform = _platform();
        actors.user = _passportOwner();
        actors.issuer = vm.envOr("LISBON_HOUSE_ISSUER_ADDRESS", SYNTHETIC_ISSUER);
    }

    function _configureOptionalMagic7702(address user) internal {
        address delegate = vm.envOr("ENSV2_MAGIC_7702_DELEGATE", address(0));
        if (delegate == address(0)) {
            require(user.code.length == 0, "Passport owner must be undelegated EOA");
            return;
        }

        require(delegate == ALCHEMY_SEMI_MODULAR_ACCOUNT_7702, "only exact Alchemy SemiModularAccount7702 is audited");
        require(delegate.code.length > 0, "Alchemy 7702 implementation missing");
        require(IERC165(delegate).supportsInterface(0x4e2312e0), "Alchemy delegate missing IERC1155Receiver");

        // Exact EIP-7702 designator: 0xef0100 || implementation address.
        vm.etch(user, abi.encodePacked(hex"ef0100", delegate));
        require(user.code.length == 23, "invalid EIP-7702 designator");
        require(IERC165(user).supportsInterface(0x4e2312e0), "delegated Magic cannot receive ERC1155");
        useMagic7702 = true;
    }

    function _setParent(ENSv2DeploymentProfiles.Profile memory deployment, address platform) internal {
        IENSv2R2Registry nomadic = IENSv2R2Registry(deployment.nomadicRegistry);
        IENSv2R2Registry ethRegistry = IENSv2R2Registry(deployment.ethRegistry);
        (address parent, string memory label) = nomadic.getParent();

        if (parent == address(0)) {
            require(bytes(label).length == 0, "unexpected empty-parent label");
            require(
                nomadic.hasRootRoles(RegistryRolesLib.ROLE_SET_PARENT, platform), "platform missing ROLE_SET_PARENT"
            );
            uint256 rolesBefore = nomadic.roles(0, platform);
            address ownerBefore = ethRegistry.findOwner(PARENT_LABEL);
            address resolverBefore = ethRegistry.getResolver(PARENT_LABEL);
            address subregistryBefore = ethRegistry.getSubregistry(PARENT_LABEL);

            vm.prank(platform);
            nomadic.setParent(deployment.ethRegistry, PARENT_LABEL);

            require(nomadic.roles(0, platform) == rolesBefore, "setParent changed roles");
            require(ethRegistry.findOwner(PARENT_LABEL) == ownerBefore, "setParent changed owner");
            require(ethRegistry.getResolver(PARENT_LABEL) == resolverBefore, "setParent changed resolver");
            require(ethRegistry.getSubregistry(PARENT_LABEL) == subregistryBefore, "setParent changed subregistry");
        } else {
            require(parent == deployment.ethRegistry, "wrong existing parent");
            require(keccak256(bytes(label)) == keccak256(bytes(PARENT_LABEL)), "wrong existing label");
        }

        require(
            IENSv2UniversalResolver(deployment.topUniversalResolver)
                    .findCanonicalRegistry(NameCoder.encode(PARENT_NAME)) == deployment.nomadicRegistry,
            "Nomadic registry not canonical"
        );
    }

    function _issuePassport(ENSv2DeploymentProfiles.Profile memory deployment, Actors memory actors)
        internal
        returns (Hierarchy memory hierarchy)
    {
        IENSv2R2Factory factory = IENSv2R2Factory(deployment.verifiableFactory);
        IENSv2R2Registry nomadic = IENSv2R2Registry(deployment.nomadicRegistry);
        (address predictedRegistry, address predictedResolver) =
            _predictedPassportContracts(deployment, actors.platform);
        require(predictedRegistry.code.length == 0, "registry salt collision");
        require(predictedResolver.code.length == 0, "resolver salt collision");

        bytes memory init = _historicalInitialize(actors.user);
        vm.startPrank(actors.platform);
        hierarchy.passportRegistry = factory.deployProxy(deployment.userRegistryImpl, PASSPORT_REGISTRY_SALT, init);
        hierarchy.passportResolver =
            factory.deployProxy(deployment.permissionedResolverImpl, PASSPORT_RESOLVER_SALT, init);
        hierarchy.passportTokenId = nomadic.register(
            PASSPORT_LABEL,
            actors.user,
            hierarchy.passportRegistry,
            hierarchy.passportResolver,
            _passportOwnerRoles(),
            type(uint64).max
        );
        vm.stopPrank();

        require(hierarchy.passportRegistry == predictedRegistry, "registry prediction");
        require(hierarchy.passportResolver == predictedResolver, "resolver prediction");
        require(factory.verifyContract(hierarchy.passportRegistry, deployment.userRegistryImpl), "registry clone");
        require(
            factory.verifyContract(hierarchy.passportResolver, deployment.permissionedResolverImpl), "resolver clone"
        );
        require(nomadic.ownerOf(hierarchy.passportTokenId) == actors.user, "Passport owner");
        require(
            !IENSv2R2Registry(hierarchy.passportRegistry)
                .hasRootRoles(RegistryRolesLib.ROLE_REGISTRAR, actors.platform),
            "platform retained Passport registrar"
        );

        hierarchy.passportDns = NameCoder.encode(PASSPORT_NAME);
        hierarchy.credentialDns = NameCoder.encode(CREDENTIAL_NAME);
        hierarchy.passportNode = NameCoder.namehash(hierarchy.passportDns, 0);
        hierarchy.credentialNode = NameCoder.namehash(hierarchy.credentialDns, 0);
    }

    function _configureMagicBundle(
        ENSv2DeploymentProfiles.Profile memory deployment,
        Actors memory actors,
        Hierarchy memory hierarchy
    ) internal {
        IENSv2R2Registry passportRegistry = IENSv2R2Registry(hierarchy.passportRegistry);
        IENSv2R2Resolver resolver = IENSv2R2Resolver(hierarchy.passportResolver);

        if (useMagic7702) {
            _configureMagicBundle7702(deployment, actors, hierarchy);
            return;
        }

        uint256 g0 = gasleft();
        vm.prank(actors.user);
        passportRegistry.setParent(deployment.nomadicRegistry, PASSPORT_LABEL);
        _recordMagicGas(0, g0);

        bytes[] memory passportRecordCalls = new bytes[](5);
        passportRecordCalls[0] = abi.encodeCall(IENSv2R2Resolver.setAddr, (hierarchy.passportNode, actors.user));
        passportRecordCalls[1] = abi.encodeCall(
            IENSv2R2Resolver.setText, (hierarchy.passportNode, NomadicRecords.TYPE_KEY, NomadicRecords.TYPE_PASSPORT)
        );
        passportRecordCalls[2] = abi.encodeCall(
            IENSv2R2Resolver.setText,
            (
                hierarchy.passportNode,
                NomadicRecords.PROFILE_KEY,
                "https://nomadic-front-rosy.vercel.app/p/victor.nomadic-passport.eth"
            )
        );
        passportRecordCalls[3] = abi.encodeCall(
            IENSv2R2Resolver.setText, (hierarchy.passportNode, NomadicRecords.CURRENT_JOURNEY_KEY, CREDENTIAL_LABEL)
        );
        passportRecordCalls[4] = abi.encodeCall(
            IENSv2R2Resolver.setText, (hierarchy.passportNode, NomadicRecords.CREDENTIALS_KEY, CREDENTIAL_NAME)
        );

        // Historical multicall is atomic and propagates the first inner revert.
        bytes[] memory invalidCalls = new bytes[](2);
        invalidCalls[0] = passportRecordCalls[0];
        invalidCalls[1] = hex"deadbeef";
        vm.expectRevert();
        vm.prank(actors.user);
        resolver.multicallWithNodeCheck(hierarchy.passportNode, invalidCalls);
        require(resolver.addr(hierarchy.passportNode) == address(0), "multicall was not atomic");

        g0 = gasleft();
        vm.prank(actors.user);
        resolver.multicallWithNodeCheck(hierarchy.passportNode, passportRecordCalls);
        _recordMagicGas(1, g0);

        g0 = gasleft();
        vm.prank(actors.user);
        hierarchy.credentialTokenId = passportRegistry.register(
            CREDENTIAL_LABEL,
            actors.user,
            address(0),
            hierarchy.passportResolver,
            _credentialOwnerRoles(),
            type(uint64).max
        );
        _recordMagicGas(2, g0);

        bytes[] memory credentialRecordCalls = new bytes[](8);
        credentialRecordCalls[0] = abi.encodeCall(
            IENSv2R2Resolver.setText,
            (hierarchy.credentialNode, NomadicRecords.TYPE_KEY, NomadicRecords.TYPE_JOURNEY_ELIGIBILITY)
        );
        credentialRecordCalls[1] = abi.encodeCall(
            IENSv2R2Resolver.setText, (hierarchy.credentialNode, NomadicRecords.ISSUER_KEY, vm.toString(actors.issuer))
        );
        credentialRecordCalls[2] = abi.encodeCall(
            IENSv2R2Resolver.setText, (hierarchy.credentialNode, NomadicRecords.JOURNEY_KEY, CREDENTIAL_LABEL)
        );
        credentialRecordCalls[3] = abi.encodeCall(
            IENSv2R2Resolver.setText, (hierarchy.credentialNode, NomadicRecords.POLICY_KEY, "lisbon_house_policy_v1")
        );
        credentialRecordCalls[4] =
            abi.encodeCall(IENSv2R2Resolver.setText, (hierarchy.credentialNode, NomadicRecords.STATUS_KEY, "active"));
        credentialRecordCalls[5] = abi.encodeCall(
            IENSv2R2Resolver.setText,
            (hierarchy.credentialNode, NomadicRecords.ISSUED_AT_KEY, vm.toString(block.timestamp))
        );
        credentialRecordCalls[6] =
            abi.encodeCall(IENSv2R2Resolver.setText, (hierarchy.credentialNode, NomadicRecords.EXPIRES_AT_KEY, ""));
        credentialRecordCalls[7] =
            abi.encodeCall(IENSv2R2Resolver.setText, (hierarchy.credentialNode, NomadicRecords.METADATA_KEY, ""));

        g0 = gasleft();
        vm.prank(actors.user);
        resolver.multicallWithNodeCheck(hierarchy.credentialNode, credentialRecordCalls);
        _recordMagicGas(3, g0);

        bytes[] memory authorizationCalls = new bytes[](4);
        string[] memory keys = NomadicRecords.issuerAllowlistedKeys();
        for (uint256 i; i < keys.length; ++i) {
            authorizationCalls[i] = abi.encodeCall(
                IENSv2R2Resolver.authorizeTextRoles, (hierarchy.credentialDns, keys[i], actors.issuer, true)
            );
        }

        g0 = gasleft();
        vm.prank(actors.user);
        resolver.multicall(authorizationCalls);
        _recordMagicGas(4, g0);

        require(passportRegistry.ownerOf(hierarchy.credentialTokenId) == actors.user, "credential owner");
    }

    function _recordMagicGas(uint256 group, uint256 gasBefore) private {
        uint256 used = gasBefore - gasleft() + 21_000;
        magicGroupGas[group] = used;
        userGas += used;
    }

    function _configureMagicBundle7702(
        ENSv2DeploymentProfiles.Profile memory deployment,
        Actors memory actors,
        Hierarchy memory hierarchy
    ) private {
        bytes[] memory passportRecordCalls = new bytes[](5);
        passportRecordCalls[0] = abi.encodeCall(IENSv2R2Resolver.setAddr, (hierarchy.passportNode, actors.user));
        passportRecordCalls[1] = abi.encodeCall(
            IENSv2R2Resolver.setText, (hierarchy.passportNode, NomadicRecords.TYPE_KEY, NomadicRecords.TYPE_PASSPORT)
        );
        passportRecordCalls[2] = abi.encodeCall(
            IENSv2R2Resolver.setText,
            (
                hierarchy.passportNode,
                NomadicRecords.PROFILE_KEY,
                "https://nomadic-front-rosy.vercel.app/p/victor.nomadic-passport.eth"
            )
        );
        passportRecordCalls[3] = abi.encodeCall(
            IENSv2R2Resolver.setText, (hierarchy.passportNode, NomadicRecords.CURRENT_JOURNEY_KEY, CREDENTIAL_LABEL)
        );
        passportRecordCalls[4] = abi.encodeCall(
            IENSv2R2Resolver.setText, (hierarchy.passportNode, NomadicRecords.CREDENTIALS_KEY, CREDENTIAL_NAME)
        );

        bytes[] memory credentialRecordCalls = new bytes[](8);
        credentialRecordCalls[0] = abi.encodeCall(
            IENSv2R2Resolver.setText,
            (hierarchy.credentialNode, NomadicRecords.TYPE_KEY, NomadicRecords.TYPE_JOURNEY_ELIGIBILITY)
        );
        credentialRecordCalls[1] = abi.encodeCall(
            IENSv2R2Resolver.setText, (hierarchy.credentialNode, NomadicRecords.ISSUER_KEY, vm.toString(actors.issuer))
        );
        credentialRecordCalls[2] = abi.encodeCall(
            IENSv2R2Resolver.setText, (hierarchy.credentialNode, NomadicRecords.JOURNEY_KEY, CREDENTIAL_LABEL)
        );
        credentialRecordCalls[3] = abi.encodeCall(
            IENSv2R2Resolver.setText, (hierarchy.credentialNode, NomadicRecords.POLICY_KEY, "lisbon_house_policy_v1")
        );
        credentialRecordCalls[4] =
            abi.encodeCall(IENSv2R2Resolver.setText, (hierarchy.credentialNode, NomadicRecords.STATUS_KEY, "active"));
        credentialRecordCalls[5] = abi.encodeCall(
            IENSv2R2Resolver.setText,
            (hierarchy.credentialNode, NomadicRecords.ISSUED_AT_KEY, vm.toString(block.timestamp))
        );
        credentialRecordCalls[6] =
            abi.encodeCall(IENSv2R2Resolver.setText, (hierarchy.credentialNode, NomadicRecords.EXPIRES_AT_KEY, ""));
        credentialRecordCalls[7] =
            abi.encodeCall(IENSv2R2Resolver.setText, (hierarchy.credentialNode, NomadicRecords.METADATA_KEY, ""));

        bytes[] memory authorizationCalls = new bytes[](4);
        string[] memory keys = NomadicRecords.issuerAllowlistedKeys();
        for (uint256 i; i < keys.length; ++i) {
            authorizationCalls[i] = abi.encodeCall(
                IENSv2R2Resolver.authorizeTextRoles, (hierarchy.credentialDns, keys[i], actors.issuer, true)
            );
        }

        IAlchemySemiModularAccount7702.Call[] memory accountCalls = new IAlchemySemiModularAccount7702.Call[](5);
        accountCalls[0] = IAlchemySemiModularAccount7702.Call({
            target: hierarchy.passportRegistry,
            value: 0,
            data: abi.encodeCall(IENSv2R2Registry.setParent, (deployment.nomadicRegistry, PASSPORT_LABEL))
        });
        accountCalls[1] = IAlchemySemiModularAccount7702.Call({
            target: hierarchy.passportResolver,
            value: 0,
            data: abi.encodeCall(IENSv2R2Resolver.multicallWithNodeCheck, (hierarchy.passportNode, passportRecordCalls))
        });
        accountCalls[2] = IAlchemySemiModularAccount7702.Call({
            target: hierarchy.passportRegistry,
            value: 0,
            data: abi.encodeCall(
                IENSv2R2Registry.register,
                (
                    CREDENTIAL_LABEL,
                    actors.user,
                    address(0),
                    hierarchy.passportResolver,
                    _credentialOwnerRoles(),
                    type(uint64).max
                )
            )
        });
        accountCalls[3] = IAlchemySemiModularAccount7702.Call({
            target: hierarchy.passportResolver,
            value: 0,
            data: abi.encodeCall(
                IENSv2R2Resolver.multicallWithNodeCheck, (hierarchy.credentialNode, credentialRecordCalls)
            )
        });
        accountCalls[4] = IAlchemySemiModularAccount7702.Call({
            target: hierarchy.passportResolver,
            value: 0,
            data: abi.encodeCall(IENSv2R2Resolver.multicall, (authorizationCalls))
        });

        uint256 g0 = gasleft();
        vm.prank(actors.user);
        IAlchemySemiModularAccount7702(actors.user).executeBatch(accountCalls);
        userGas = g0 - gasleft() + 21_000;
        magicGroupGas[0] = userGas;

        hierarchy.credentialTokenId = IENSv2R2Registry(hierarchy.passportRegistry).findTokenId(CREDENTIAL_LABEL);
        require(
            IENSv2R2Registry(hierarchy.passportRegistry).ownerOf(hierarchy.credentialTokenId) == actors.user,
            "delegated credential owner"
        );
        require(
            IENSv2R2Resolver(hierarchy.passportResolver).addr(hierarchy.passportNode) == actors.user,
            "delegated call msg.sender/records"
        );
    }

    function _assertResolution(
        ENSv2DeploymentProfiles.Profile memory deployment,
        Actors memory actors,
        Hierarchy memory hierarchy
    ) internal view {
        address[3] memory resolvers = [
            deployment.topUniversalResolver, deployment.managedUniversalResolver, deployment.universalResolver
        ];
        for (uint256 i; i < resolvers.length; ++i) {
            IENSv2UniversalResolver universalResolver = IENSv2UniversalResolver(resolvers[i]);
            require(universalResolver.findOwner(hierarchy.passportDns) == actors.user, "UR Passport owner");
            require(universalResolver.findOwner(hierarchy.credentialDns) == actors.user, "UR credential owner");
            require(
                universalResolver.findCanonicalRegistry(hierarchy.passportDns) == hierarchy.passportRegistry,
                "UR Passport canonical registry"
            );

            (bytes memory addrResult, address passportResolver) = universalResolver.resolve(
                hierarchy.passportDns, abi.encodeCall(IENSv2R2Resolver.addr, (hierarchy.passportNode))
            );
            require(passportResolver == hierarchy.passportResolver, "UR Passport resolver");
            require(abi.decode(addrResult, (address)) == actors.user, "UR Passport addr");

            (bytes memory statusResult, address credentialResolver) = universalResolver.resolve(
                hierarchy.credentialDns,
                abi.encodeCall(IENSv2R2Resolver.text, (hierarchy.credentialNode, NomadicRecords.STATUS_KEY))
            );
            require(credentialResolver == hierarchy.passportResolver, "UR credential resolver");
            require(keccak256(bytes(abi.decode(statusResult, (string)))) == keccak256("active"), "UR credential status");
        }
    }

    function _permissionDemo(Actors memory actors, Hierarchy memory hierarchy) internal {
        IENSv2R2Resolver resolver = IENSv2R2Resolver(hierarchy.passportResolver);

        uint256 g0 = gasleft();
        vm.prank(actors.issuer);
        resolver.setText(hierarchy.credentialNode, NomadicRecords.STATUS_KEY, "renewed");
        issuerGas += g0 - gasleft() + 21_000;

        uint256 nodeResource = PermissionedResolverLib.resource(hierarchy.credentialNode, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                IEnhancedAccessControl.EACUnauthorizedAccountRoles.selector,
                nodeResource,
                PermissionedResolverLib.ROLE_SET_TEXT,
                actors.issuer
            )
        );
        vm.prank(actors.issuer);
        resolver.setText(hierarchy.credentialNode, NomadicRecords.TYPE_KEY, "hack");

        g0 = gasleft();
        vm.prank(actors.user);
        resolver.authorizeTextRoles(hierarchy.credentialDns, NomadicRecords.STATUS_KEY, actors.issuer, false);
        revocationGas = g0 - gasleft() + 21_000;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEnhancedAccessControl.EACUnauthorizedAccountRoles.selector,
                nodeResource,
                PermissionedResolverLib.ROLE_SET_TEXT,
                actors.issuer
            )
        );
        vm.prank(actors.issuer);
        resolver.setText(hierarchy.credentialNode, NomadicRecords.STATUS_KEY, "should-fail");

        require(
            IENSv2R2Registry(hierarchy.passportRegistry).ownerOf(hierarchy.credentialTokenId) == actors.user,
            "credential owner changed"
        );
    }

    function _assertCurrentNotInPath() internal view {
        ENSv2DeploymentProfiles.Profile memory current = ENSv2DeploymentProfiles.current();
        require(
            IENSv2UniversalResolver(current.universalResolver).findOwner(NameCoder.encode(PASSPORT_NAME)) == address(0),
            "current direct resolver unexpectedly sees Passport"
        );

        (bool ok,) = current.universalResolver
            .staticcall(
                abi.encodeCall(
                    IENSv2UniversalResolver.resolve,
                    (
                        NameCoder.encode(PASSPORT_NAME),
                        abi.encodeCall(IENSv2R2Resolver.addr, (NameCoder.namehash(NameCoder.encode(PASSPORT_NAME), 0)))
                    )
                )
            );
        require(!ok, "current direct resolver entered execution path");
    }
}
