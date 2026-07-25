// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";

import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {GatewayProvider} from "@ens/contracts/ccipRead/GatewayProvider.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";
import {VerifiableFactory} from "@ensdomains/verifiable-factory/VerifiableFactory.sol";

import {EACBaseRolesLib} from "ensv2/access-control/libraries/EACBaseRolesLib.sol";
import {PermissionedRegistry} from "ensv2/registry/PermissionedRegistry.sol";
import {RegistryRolesLib} from "ensv2/registry/libraries/RegistryRolesLib.sol";
import {IRegistry} from "ensv2/registry/interfaces/IRegistry.sol";
import {UserRegistry} from "ensv2/registry/UserRegistry.sol";
import {PermissionedResolver} from "ensv2/resolver/PermissionedResolver.sol";
import {PermissionedResolverLib} from "ensv2/resolver/libraries/PermissionedResolverLib.sol";
import {ContractNamer} from "ensv2/utils/ContractNamer.sol";
import {LabelStore} from "ensv2/utils/LabelStore.sol";
import {UniversalResolverV2} from "ensv2/universalResolver/UniversalResolverV2.sol";

import {NomadicRecords} from "../../src/ensv2/NomadicRecords.sol";

/// @notice Local ENSv2 fixture for Nomadic Passport + Journey credential tests.
abstract contract NomadicENSv2Fixture is Test, ERC1155Holder {
    address internal platform = makeAddr("platform");
    address internal user = makeAddr("user");
    address internal issuer = makeAddr("issuer");
    address internal attacker = makeAddr("attacker");

    ContractNamer internal contractNamer;
    VerifiableFactory internal verifiableFactory;
    LabelStore internal labelStore;
    UserRegistry internal userRegistryImpl;
    PermissionedResolver internal permissionedResolverImpl;
    PermissionedRegistry internal rootRegistry;
    PermissionedRegistry internal ethRegistry;
    UserRegistry internal parentRegistry;
    GatewayProvider internal batchGatewayProvider;
    UniversalResolverV2 internal universalResolver;

    UserRegistry internal passportRegistry;
    PermissionedResolver internal passportResolver;
    uint256 internal passportTokenId;
    uint256 internal credentialTokenId;

    string internal constant PARENT_LABEL = "nomadic-passport-test";
    string internal constant PASSPORT_LABEL = "victor";
    string internal constant CREDENTIAL_LABEL = "lisbon-house";

    bytes internal parentDnsName;
    bytes internal passportDnsName;
    bytes internal credentialDnsName;
    bytes32 internal passportNode;
    bytes32 internal credentialNode;

    uint64 internal constant NAME_EXPIRY = type(uint64).max;

    function setUp() public virtual {
        _deployBaseStack();
        _deployParentNamespace();
        _provisionPassportAndCredential();
    }

    function _rootRegistryRootRoles() internal pure returns (uint256) {
        return RegistryRolesLib.ROLE_REGISTRAR | RegistryRolesLib.ROLE_REGISTRAR_ADMIN
            | RegistryRolesLib.ROLE_REGISTER_RESERVED | RegistryRolesLib.ROLE_REGISTER_RESERVED_ADMIN
            | RegistryRolesLib.ROLE_SET_PARENT | RegistryRolesLib.ROLE_SET_PARENT_ADMIN | RegistryRolesLib.ROLE_RENEW
            | RegistryRolesLib.ROLE_RENEW_ADMIN | RegistryRolesLib.ROLE_CAN_NAME | RegistryRolesLib.ROLE_CAN_NAME_ADMIN;
    }

    function _ethRegistryRootRoles() internal pure returns (uint256) {
        return RegistryRolesLib.ROLE_REGISTRAR_ADMIN | RegistryRolesLib.ROLE_REGISTER_RESERVED_ADMIN
            | RegistryRolesLib.ROLE_SET_PARENT | RegistryRolesLib.ROLE_SET_PARENT_ADMIN
            | RegistryRolesLib.ROLE_RENEW_ADMIN | RegistryRolesLib.ROLE_CAN_NAME | RegistryRolesLib.ROLE_CAN_NAME_ADMIN;
    }

    function _ethTokenRoles() internal pure returns (uint256) {
        return RegistryRolesLib.ROLE_SET_SUBREGISTRY | RegistryRolesLib.ROLE_SET_SUBREGISTRY_ADMIN
            | RegistryRolesLib.ROLE_SET_RESOLVER | RegistryRolesLib.ROLE_SET_RESOLVER_ADMIN;
    }

    function _passportOwnerRoles() internal pure returns (uint256) {
        return RegistryRolesLib.ROLE_SET_SUBREGISTRY | RegistryRolesLib.ROLE_SET_SUBREGISTRY_ADMIN
            | RegistryRolesLib.ROLE_SET_RESOLVER | RegistryRolesLib.ROLE_SET_RESOLVER_ADMIN
            | RegistryRolesLib.ROLE_RENEW | RegistryRolesLib.ROLE_RENEW_ADMIN | RegistryRolesLib.ROLE_UNREGISTER
            | RegistryRolesLib.ROLE_UNREGISTER_ADMIN | RegistryRolesLib.ROLE_CAN_TRANSFER_ADMIN;
    }

    function _passportRegistryRootRoles() internal pure returns (uint256) {
        return RegistryRolesLib.ROLE_REGISTRAR | RegistryRolesLib.ROLE_REGISTRAR_ADMIN
            | RegistryRolesLib.ROLE_SET_PARENT | RegistryRolesLib.ROLE_SET_PARENT_ADMIN | RegistryRolesLib.ROLE_UPGRADE
            | RegistryRolesLib.ROLE_UPGRADE_ADMIN | RegistryRolesLib.ROLE_CAN_NAME
            | RegistryRolesLib.ROLE_CAN_NAME_ADMIN;
    }

    function _deployBaseStack() internal {
        contractNamer = ContractNamer(
            address(
                new ERC1967Proxy(
                    address(new ContractNamer()), abi.encodeCall(ContractNamer.initialize, (address(this)))
                )
            )
        );
        verifiableFactory = new VerifiableFactory();
        labelStore = new LabelStore(contractNamer);
        userRegistryImpl = new UserRegistry(labelStore, address(this));
        permissionedResolverImpl = new PermissionedResolver(address(this));

        rootRegistry = new PermissionedRegistry(labelStore, address(this), _rootRegistryRootRoles());
        ethRegistry = new PermissionedRegistry(labelStore, address(this), _ethRegistryRootRoles());
        rootRegistry.register("eth", address(this), ethRegistry, address(0), _ethTokenRoles(), NAME_EXPIRY);
        ethRegistry.setParent(rootRegistry, "eth");
        ethRegistry.grantRootRoles(RegistryRolesLib.ROLE_REGISTRAR, address(this));

        batchGatewayProvider = new GatewayProvider(address(this), new string[](0));
        universalResolver = new UniversalResolverV2(rootRegistry, batchGatewayProvider, contractNamer);
    }

    function _deployParentNamespace() internal {
        parentRegistry = UserRegistry(
            verifiableFactory.deployProxy(
                address(userRegistryImpl),
                uint256(keccak256("parent-registry")),
                abi.encodeCall(
                    UserRegistry.initialize,
                    (
                        platform,
                        RegistryRolesLib.ROLE_REGISTRAR | RegistryRolesLib.ROLE_REGISTRAR_ADMIN
                            | RegistryRolesLib.ROLE_SET_PARENT | RegistryRolesLib.ROLE_SET_PARENT_ADMIN
                            | RegistryRolesLib.ROLE_UPGRADE | RegistryRolesLib.ROLE_UPGRADE_ADMIN
                    )
                )
            )
        );

        ethRegistry.register(
            PARENT_LABEL,
            platform,
            IRegistry(address(parentRegistry)),
            address(0),
            _ethTokenRoles() | RegistryRolesLib.ROLE_CAN_TRANSFER_ADMIN,
            NAME_EXPIRY
        );

        vm.prank(platform);
        parentRegistry.setParent(ethRegistry, PARENT_LABEL);

        parentDnsName = NameCoder.encode(string.concat(PARENT_LABEL, ".eth"));
    }

    function _provisionPassportAndCredential() internal {
        // 1) Passport UserRegistry owned/adminned by user (not platform).
        passportRegistry = UserRegistry(
            verifiableFactory.deployProxy(
                address(userRegistryImpl),
                uint256(keccak256(abi.encodePacked("passport", user, PASSPORT_LABEL))),
                abi.encodeCall(UserRegistry.initialize, (user, _passportRegistryRootRoles()))
            )
        );

        // 2) PermissionedResolver owned/adminned by user.
        bytes memory resolverInit =
            abi.encodeCall(PermissionedResolver.initialize, (user, EACBaseRolesLib.ALL_ROLES, new bytes[](0)));
        passportResolver = PermissionedResolver(
            verifiableFactory.deployProxy(
                address(permissionedResolverImpl),
                uint256(keccak256(abi.encodePacked("resolver", user, PASSPORT_LABEL))),
                resolverInit
            )
        );

        // 3) Platform provisions Passport under parent; ownership assigned to user.
        vm.prank(platform);
        passportTokenId = parentRegistry.register(
            PASSPORT_LABEL,
            user,
            IRegistry(address(passportRegistry)),
            address(passportResolver),
            _passportOwnerRoles(),
            NAME_EXPIRY
        );

        // 4) Canonical parent linkage on Passport registry.
        vm.prank(user);
        passportRegistry.setParent(parentRegistry, PASSPORT_LABEL);

        passportDnsName = NameCoder.encode(string.concat(PASSPORT_LABEL, ".", PARENT_LABEL, ".eth"));
        passportNode = NameCoder.namehash(passportDnsName, 0);

        // 5) Credential child inside Passport registry (no separate UserRegistry).
        vm.prank(user);
        credentialTokenId = passportRegistry.register(
            CREDENTIAL_LABEL, user, IRegistry(address(0)), address(passportResolver), _passportOwnerRoles(), NAME_EXPIRY
        );

        credentialDnsName =
            NameCoder.encode(string.concat(CREDENTIAL_LABEL, ".", PASSPORT_LABEL, ".", PARENT_LABEL, ".eth"));
        credentialNode = NameCoder.namehash(credentialDnsName, 0);

        _seedPassportRecords();
        _seedCredentialRecords();
        _authorizeIssuerAllowlist();
    }

    function _seedPassportRecords() internal {
        vm.startPrank(user);
        passportResolver.setAddr(passportNode, user);
        passportResolver.setText(passportNode, NomadicRecords.TYPE_KEY, NomadicRecords.TYPE_PASSPORT);
        passportResolver.setText(passportNode, NomadicRecords.PROFILE_KEY, "https://example.invalid/p/victor");
        passportResolver.setText(passportNode, NomadicRecords.CURRENT_JOURNEY_KEY, "lisbon-house-2026");
        passportResolver.setText(
            passportNode,
            NomadicRecords.CREDENTIALS_KEY,
            string.concat(CREDENTIAL_LABEL, ".", PASSPORT_LABEL, ".", PARENT_LABEL, ".eth")
        );
        vm.stopPrank();
    }

    function _seedCredentialRecords() internal {
        vm.startPrank(user);
        passportResolver.setAddr(credentialNode, user);
        passportResolver.setText(credentialNode, NomadicRecords.TYPE_KEY, NomadicRecords.TYPE_JOURNEY_ELIGIBILITY);
        passportResolver.setText(credentialNode, NomadicRecords.ISSUER_KEY, "nomadic-lisbon-house");
        passportResolver.setText(credentialNode, NomadicRecords.JOURNEY_KEY, "lisbon-house-2026");
        passportResolver.setText(credentialNode, NomadicRecords.POLICY_KEY, "lisbon_house_policy_v1");
        passportResolver.setText(credentialNode, NomadicRecords.STATUS_KEY, "eligible");
        passportResolver.setText(credentialNode, NomadicRecords.ISSUED_AT_KEY, "0");
        passportResolver.setText(credentialNode, NomadicRecords.EXPIRES_AT_KEY, "0");
        passportResolver.setText(credentialNode, NomadicRecords.METADATA_KEY, "https://example.invalid/credential");
        vm.stopPrank();
    }

    function _authorizeIssuerAllowlist() internal {
        string[] memory keys = NomadicRecords.issuerAllowlistedKeys();
        vm.startPrank(user);
        for (uint256 i = 0; i < keys.length; i++) {
            passportResolver.authorizeTextRoles(credentialDnsName, keys[i], issuer, true);
        }
        vm.stopPrank();
    }

    function _findResolver(bytes memory name) internal view returns (address resolver) {
        (resolver,,) = universalResolver.findResolver(name);
    }
}
