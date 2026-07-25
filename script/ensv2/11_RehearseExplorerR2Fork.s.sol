// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2} from "forge-std/Script.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";

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

/// @notice Full stateful Explorer-r2 rehearsal against a Sepolia fork. Never broadcasts.
contract RehearseExplorerR2ForkScript is ENSv2ExecutionBase {
    address internal constant SYNTHETIC_ISSUER = 0x3333333333333333333333333333333333333333;

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

    function run() external {
        ENSv2DeploymentProfiles.Profile memory deployment = _loadProfile();
        _requireSepolia(deployment);
        _requireExplorerR2(deployment);
        require(!vm.envOr("ENSV2_BROADCAST", false), "rehearsal never broadcasts");

        Actors memory actors = _actors();
        _assertDistinctActors(actors.platform, actors.user, actors.issuer);
        require(actors.user.code.length == 0, "Passport owner must be EOA or IERC1155Receiver");

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

        g0 = gasleft();
        _configureMagicBundle(deployment, actors, hierarchy);
        userGas += g0 - gasleft() + 19 * 21_000;

        _assertResolution(deployment, actors, hierarchy);
        _permissionDemo(actors, hierarchy);
        _assertCurrentNotInPath();

        console2.log(string.concat("platform_gas_estimate=", vm.toString(platformGas)));
        console2.log(string.concat("magic_gas_estimate=", vm.toString(userGas)));
        console2.log(string.concat("issuer_demo_gas_estimate=", vm.toString(issuerGas)));
        console2.log("syntheticIssuer", actors.issuer);
        console2.log("passportRegistry", hierarchy.passportRegistry);
        console2.log("passportResolver", hierarchy.passportResolver);
        console2.log("RESULT: Explorer-r2 full fork rehearsal PASSED");
    }

    function _actors() internal view returns (Actors memory actors) {
        actors.platform = _platform();
        actors.user = _passportOwner();
        actors.issuer = vm.envOr("LISBON_HOUSE_ISSUER_ADDRESS", SYNTHETIC_ISSUER);
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

        vm.startPrank(actors.user);
        passportRegistry.setParent(deployment.nomadicRegistry, PASSPORT_LABEL);
        resolver.setAddr(hierarchy.passportNode, actors.user);
        resolver.setText(hierarchy.passportNode, NomadicRecords.TYPE_KEY, NomadicRecords.TYPE_PASSPORT);
        resolver.setText(
            hierarchy.passportNode,
            NomadicRecords.PROFILE_KEY,
            "https://nomadic-front-rosy.vercel.app/p/victor.nomadic-passport.eth"
        );
        resolver.setText(hierarchy.passportNode, NomadicRecords.CURRENT_JOURNEY_KEY, CREDENTIAL_LABEL);
        resolver.setText(hierarchy.passportNode, NomadicRecords.CREDENTIALS_KEY, CREDENTIAL_NAME);

        hierarchy.credentialTokenId = passportRegistry.register(
            CREDENTIAL_LABEL,
            actors.user,
            address(0),
            hierarchy.passportResolver,
            _credentialOwnerRoles(),
            type(uint64).max
        );
        resolver.setText(hierarchy.credentialNode, NomadicRecords.TYPE_KEY, NomadicRecords.TYPE_JOURNEY_ELIGIBILITY);
        resolver.setText(hierarchy.credentialNode, NomadicRecords.ISSUER_KEY, vm.toString(actors.issuer));
        resolver.setText(hierarchy.credentialNode, NomadicRecords.JOURNEY_KEY, CREDENTIAL_LABEL);
        resolver.setText(hierarchy.credentialNode, NomadicRecords.POLICY_KEY, "lisbon_house_policy_v1");
        resolver.setText(hierarchy.credentialNode, NomadicRecords.STATUS_KEY, "active");
        resolver.setText(hierarchy.credentialNode, NomadicRecords.ISSUED_AT_KEY, vm.toString(block.timestamp));
        resolver.setText(hierarchy.credentialNode, NomadicRecords.EXPIRES_AT_KEY, "");
        resolver.setText(hierarchy.credentialNode, NomadicRecords.METADATA_KEY, "");

        string[] memory keys = NomadicRecords.issuerAllowlistedKeys();
        for (uint256 i; i < keys.length; ++i) {
            resolver.authorizeTextRoles(hierarchy.credentialDns, keys[i], actors.issuer, true);
        }
        vm.stopPrank();

        require(passportRegistry.ownerOf(hierarchy.credentialTokenId) == actors.user, "credential owner");
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
        userGas += g0 - gasleft() + 21_000;

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
