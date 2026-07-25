// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";
import {VerifiableFactory} from "@ensdomains/verifiable-factory/VerifiableFactory.sol";

import {EACBaseRolesLib} from "ensv2/access-control/libraries/EACBaseRolesLib.sol";
import {IEnhancedAccessControl} from "ensv2/access-control/interfaces/IEnhancedAccessControl.sol";
import {ETHRegistrar} from "ensv2/registrar/ETHRegistrar.sol";
import {IETHRegistrar} from "ensv2/registrar/interfaces/IETHRegistrar.sol";
import {IRegistry} from "ensv2/registry/interfaces/IRegistry.sol";
import {IOwnedRegistry} from "ensv2/registry/interfaces/IOwnedRegistry.sol";
import {RegistryRolesLib} from "ensv2/registry/libraries/RegistryRolesLib.sol";
import {UserRegistry} from "ensv2/registry/UserRegistry.sol";
import {PermissionedResolver} from "ensv2/resolver/PermissionedResolver.sol";
import {PermissionedResolverLib} from "ensv2/resolver/libraries/PermissionedResolverLib.sol";
import {IUniversalResolverV2} from "ensv2/universalResolver/interfaces/IUniversalResolverV2.sol";

import {NomadicRecords} from "../../src/ensv2/NomadicRecords.sol";
import {ENSv2DeploymentProfiles} from "../../src/ensv2/ENSv2DeploymentProfiles.sol";
import {SepoliaENSv2} from "../../src/ensv2/SepoliaENSv2.sol";
import {ENSv2ExecutionBase} from "./ENSv2ExecutionBase.sol";

interface IMockUSDC {
    function mint(address to, uint256 amount) external;
}

/// @notice Full Sepolia-fork simulation of Nomadic Passport issuance. Never broadcasts.
/// @dev forge script script/ensv2/06_SimulateIssuanceFork.s.sol --fork-url $SEPOLIA_RPC_URL -vvv
contract SimulateIssuanceForkScript is ENSv2ExecutionBase {
    address internal constant MOCK_USDC = 0xD3322B29a7BdEe707D1684676f149bf41Aa3422f;

    // Empty-code Sepolia EOAs for defaults. Do NOT use forge-std makeAddr("user"):
    // on live Sepolia that address is EIP-7702 delegated (ef0100…) and ERC-1155 mint reverts.
    address internal constant DEFAULT_PLATFORM = 0x723d360EA1f6eFb71c3798C267EFddE1604bf4a4;
    address internal constant DEFAULT_USER = 0x263d44bE3B07686a0f6CcF2Bc81d2b6d89eBeB5b;
    address internal constant DEFAULT_ISSUER = 0xc0b76553a2A5DD6D5Ba5f6AefD178615C079f64b;

    uint64 internal constant REGISTER_DURATION = 365 days;

    struct Actors {
        address platform;
        address user;
        address issuer;
    }

    struct Hierarchy {
        UserRegistry parentRegistry;
        PermissionedResolver parentResolver;
        UserRegistry passportRegistry;
        PermissionedResolver passportResolver;
        uint256 passportTokenId;
        uint256 credentialTokenId;
        bytes passportDns;
        bytes credentialDns;
        bytes32 passportNode;
        bytes32 credentialNode;
    }

    uint256 internal totalGasEstimate;
    uint256 internal txCount;

    function run() external {
        ENSv2DeploymentProfiles.Profile memory deployment = _loadProfile();
        _requireCurrent(deployment);
        require(!vm.envOr("ENSV2_BROADCAST", false), "ENSV2_BROADCAST must be false");
        require(block.chainid == SepoliaENSv2.CHAIN_ID, "fork must be Sepolia (11155111)");

        Actors memory a = _actors();
        console2.log("=== FORK SIMULATION: Nomadic Passport issuance ===");
        console2.log("platform", a.platform);
        console2.log("user", a.user);
        console2.log("issuer", a.issuer);
        if (a.platform == a.issuer) {
            console2.log("WARNING: platform == issuer; scoped-permission demo clearer with distinct issuer");
        }

        _assertLiveDeployment();
        Hierarchy memory h = _acquireParentAndIssue(a);
        _assertFinalState(a, h);
        _demoIssuerPermissionsAndRevocation(a, h);

        _ulog("approx_total_gas_metered", totalGasEstimate);
        _ulog("approx_tx_count_metered", txCount);
        console2.log("RESULT: Sepolia fork issuance simulation PASSED");
    }

    function _ulog(string memory label, uint256 value) internal view {
        console2.log(string.concat(label, "=", vm.toString(value)));
    }

    function _actors() internal returns (Actors memory a) {
        a.platform = vm.envOr("NOMADIC_PARENT_OWNER_ADDRESS", address(0));
        if (a.platform == address(0)) {
            a.platform = vm.envOr("ENSV2_PLATFORM_ADDRESS", DEFAULT_PLATFORM);
        }
        a.user = vm.envOr("PASSPORT_OWNER_ADDRESS", address(0));
        if (a.user == address(0)) {
            a.user = vm.envOr("ENSV2_PASSPORT_OWNER_ADDRESS", DEFAULT_USER);
        }
        a.issuer = vm.envOr("LISBON_HOUSE_ISSUER_ADDRESS", address(0));
        if (a.issuer == address(0)) {
            a.issuer = vm.envOr("ENSV2_ISSUER_ADDRESS", DEFAULT_ISSUER);
        }

        // ERC-1155 singleton safe-mint requires EOA (no code) or IERC1155Receiver.
        // EIP-7702 delegated accounts have code and will revert unless they implement the receiver.
        require(
            a.user.code.length == 0,
            "PASSPORT_OWNER_ADDRESS has code (EIP-7702/contract); must be empty-code EOA or IERC1155Receiver"
        );
        require(a.platform.code.length == 0, "NOMADIC_PARENT_OWNER_ADDRESS has code");
        require(a.issuer.code.length == 0, "LISBON_HOUSE_ISSUER_ADDRESS has code");

        vm.deal(a.platform, 10 ether);
        vm.deal(a.user, 1 ether);
        vm.deal(a.issuer, 1 ether);
    }

    function _assertLiveDeployment() internal view {
        require(IETHRegistrar(SepoliaENSv2.ETH_REGISTRAR).isAvailable(PARENT_LABEL), "parent not available");
        require(SepoliaENSv2.VERIFIABLE_FACTORY.code.length > 0, "VerifiableFactory missing");
        require(SepoliaENSv2.USER_REGISTRY_IMPL.code.length > 0, "UserRegistryImpl missing");
        require(SepoliaENSv2.PERMISSIONED_RESOLVER_IMPL.code.length > 0, "PermissionedResolverImpl missing");
        require(SepoliaENSv2.ETH_REGISTRAR.code.length > 0, "ETHRegistrar missing");
        require(MOCK_USDC.code.length > 0, "MockUSDC missing");
    }

    function _meter(string memory label, uint256 gasBefore) internal returns (uint256 used) {
        used = gasBefore - gasleft();
        totalGasEstimate += used;
        txCount += 1;
        _ulog(label, used);
    }

    function _acquireParentAndIssue(Actors memory a) internal returns (Hierarchy memory h) {
        VerifiableFactory factory = VerifiableFactory(SepoliaENSv2.VERIFIABLE_FACTORY);
        ETHRegistrar registrar = ETHRegistrar(SepoliaENSv2.ETH_REGISTRAR);

        uint256 g0 = gasleft();
        vm.startPrank(a.platform);
        h.parentRegistry = UserRegistry(
            factory.deployProxy(
                SepoliaENSv2.USER_REGISTRY_IMPL,
                uint256(keccak256(abi.encodePacked("nomadic-parent", a.platform, block.number))),
                abi.encodeCall(
                    UserRegistry.initialize,
                    (
                        a.platform,
                        RegistryRolesLib.ROLE_REGISTRAR | RegistryRolesLib.ROLE_REGISTRAR_ADMIN
                            | RegistryRolesLib.ROLE_SET_PARENT | RegistryRolesLib.ROLE_SET_PARENT_ADMIN
                            | RegistryRolesLib.ROLE_UPGRADE | RegistryRolesLib.ROLE_UPGRADE_ADMIN
                    )
                )
            )
        );
        h.parentResolver = PermissionedResolver(
            factory.deployProxy(
                SepoliaENSv2.PERMISSIONED_RESOLVER_IMPL,
                uint256(keccak256(abi.encodePacked("nomadic-parent-res", a.platform, block.number))),
                abi.encodeCall(PermissionedResolver.initialize, (a.platform, EACBaseRolesLib.ALL_ROLES, new bytes[](0)))
            )
        );
        _meter("gas_parent_proxies", g0);

        bytes32 secret = keccak256("nomadic-preflight-secret");
        bytes32 referrer = bytes32(0);
        bytes32 commitment = registrar.makeCommitment(
            PARENT_LABEL,
            a.platform,
            secret,
            IRegistry(address(h.parentRegistry)),
            address(h.parentResolver),
            REGISTER_DURATION,
            referrer
        );

        g0 = gasleft();
        registrar.commit(commitment);
        _meter("gas_commit", g0);
        vm.stopPrank();

        vm.warp(block.timestamp + uint256(registrar.MIN_COMMITMENT_AGE()) + 1);

        (uint256 base, uint256 premium) = registrar.getRegisterPrice(PARENT_LABEL, REGISTER_DURATION, IERC20(MOCK_USDC));
        uint256 due = base + premium;
        _ulog("usdc_due_raw_units", due);

        vm.startPrank(a.platform);
        IMockUSDC(MOCK_USDC).mint(a.platform, due);
        IERC20(MOCK_USDC).approve(address(registrar), due);

        g0 = gasleft();
        uint256 parentTokenId = registrar.register(
            PARENT_LABEL,
            a.platform,
            secret,
            IRegistry(address(h.parentRegistry)),
            address(h.parentResolver),
            REGISTER_DURATION,
            IERC20(MOCK_USDC),
            referrer
        );
        _meter("gas_register_parent", g0);
        console2.log(string.concat("parentTokenId=", vm.toString(parentTokenId)));

        address parentOwnerNow = IOwnedRegistry(SepoliaENSv2.ETH_REGISTRY).findOwner(PARENT_LABEL);
        require(parentOwnerNow == a.platform, "parent owner not platform");
        console2.log("parentOwner", parentOwnerNow);

        g0 = gasleft();
        h.parentRegistry.setParent(IRegistry(SepoliaENSv2.ETH_REGISTRY), PARENT_LABEL);
        _meter("gas_parent_setParent", g0);

        // Passport proxies (user admin) + register under parent.
        h.passportRegistry = UserRegistry(
            factory.deployProxy(
                SepoliaENSv2.USER_REGISTRY_IMPL,
                uint256(keccak256(abi.encodePacked("passport", a.user, PASSPORT_LABEL, block.number))),
                abi.encodeCall(
                    UserRegistry.initialize,
                    (
                        a.user,
                        RegistryRolesLib.ROLE_REGISTRAR | RegistryRolesLib.ROLE_REGISTRAR_ADMIN
                            | RegistryRolesLib.ROLE_SET_PARENT | RegistryRolesLib.ROLE_SET_PARENT_ADMIN
                            | RegistryRolesLib.ROLE_UPGRADE | RegistryRolesLib.ROLE_UPGRADE_ADMIN
                    )
                )
            )
        );
        h.passportResolver = PermissionedResolver(
            factory.deployProxy(
                SepoliaENSv2.PERMISSIONED_RESOLVER_IMPL,
                uint256(keccak256(abi.encodePacked("passport-res", a.user, PASSPORT_LABEL, block.number))),
                abi.encodeCall(PermissionedResolver.initialize, (a.user, EACBaseRolesLib.ALL_ROLES, new bytes[](0)))
            )
        );

        g0 = gasleft();
        h.passportTokenId = h.parentRegistry
            .register(
                PASSPORT_LABEL,
                a.user,
                IRegistry(address(h.passportRegistry)),
                address(h.passportResolver),
                RegistryRolesLib.ROLE_SET_SUBREGISTRY | RegistryRolesLib.ROLE_SET_SUBREGISTRY_ADMIN
                    | RegistryRolesLib.ROLE_SET_RESOLVER | RegistryRolesLib.ROLE_SET_RESOLVER_ADMIN
                    | RegistryRolesLib.ROLE_RENEW | RegistryRolesLib.ROLE_RENEW_ADMIN | RegistryRolesLib.ROLE_UNREGISTER
                    | RegistryRolesLib.ROLE_UNREGISTER_ADMIN | RegistryRolesLib.ROLE_CAN_TRANSFER_ADMIN,
                type(uint64).max
            );
        _meter("gas_register_passport", g0);
        vm.stopPrank();

        require(h.parentRegistry.ownerOf(h.passportTokenId) == a.user, "passport owner");
        require(
            !h.passportRegistry.hasRootRoles(RegistryRolesLib.ROLE_REGISTRAR, a.platform),
            "platform must not retain passport registrar"
        );

        h.passportDns = NameCoder.encode(string.concat(PASSPORT_LABEL, ".", PARENT_NAME));
        h.passportNode = NameCoder.namehash(h.passportDns, 0);
        h.credentialDns = NameCoder.encode(string.concat(CREDENTIAL_LABEL, ".", PASSPORT_LABEL, ".", PARENT_NAME));
        h.credentialNode = NameCoder.namehash(h.credentialDns, 0);

        string memory passportFqdn = string.concat(PASSPORT_LABEL, ".", PARENT_NAME);
        string memory credentialFqdn = string.concat(CREDENTIAL_LABEL, ".", PASSPORT_LABEL, ".", PARENT_NAME);
        string memory profile = string.concat("https://nomadic-front-rosy.vercel.app/p/", passportFqdn);
        string memory issuerId = vm.toString(a.issuer);
        string memory issuedAt = vm.toString(block.timestamp);

        vm.startPrank(a.user);
        g0 = gasleft();
        h.passportRegistry.setParent(IRegistry(address(h.parentRegistry)), PASSPORT_LABEL);
        _meter("gas_passport_setParent", g0);

        g0 = gasleft();
        h.passportResolver.setAddr(h.passportNode, a.user);
        h.passportResolver.setText(h.passportNode, NomadicRecords.TYPE_KEY, NomadicRecords.TYPE_PASSPORT);
        h.passportResolver.setText(h.passportNode, NomadicRecords.PROFILE_KEY, profile);
        h.passportResolver.setText(h.passportNode, NomadicRecords.CURRENT_JOURNEY_KEY, "lisbon-house");
        h.passportResolver.setText(h.passportNode, NomadicRecords.CREDENTIALS_KEY, credentialFqdn);
        _meter("gas_passport_records", g0);

        g0 = gasleft();
        h.credentialTokenId = h.passportRegistry
            .register(
                CREDENTIAL_LABEL,
                a.user,
                IRegistry(address(0)),
                address(h.passportResolver),
                RegistryRolesLib.ROLE_SET_RESOLVER | RegistryRolesLib.ROLE_SET_RESOLVER_ADMIN
                    | RegistryRolesLib.ROLE_CAN_TRANSFER_ADMIN,
                type(uint64).max
            );
        _meter("gas_register_credential", g0);

        g0 = gasleft();
        h.passportResolver.setAddr(h.credentialNode, a.user);
        h.passportResolver.setText(h.credentialNode, NomadicRecords.TYPE_KEY, NomadicRecords.TYPE_JOURNEY_ELIGIBILITY);
        h.passportResolver.setText(h.credentialNode, NomadicRecords.ISSUER_KEY, issuerId);
        h.passportResolver.setText(h.credentialNode, NomadicRecords.JOURNEY_KEY, "lisbon-house");
        h.passportResolver.setText(h.credentialNode, NomadicRecords.POLICY_KEY, "lisbon_house_policy_v1");
        h.passportResolver.setText(h.credentialNode, NomadicRecords.STATUS_KEY, "active");
        h.passportResolver.setText(h.credentialNode, NomadicRecords.ISSUED_AT_KEY, issuedAt);
        h.passportResolver.setText(h.credentialNode, NomadicRecords.EXPIRES_AT_KEY, "");
        h.passportResolver.setText(h.credentialNode, NomadicRecords.METADATA_KEY, "");
        _meter("gas_credential_records", g0);

        g0 = gasleft();
        string[] memory keys = NomadicRecords.issuerAllowlistedKeys();
        for (uint256 i = 0; i < keys.length; i++) {
            h.passportResolver.authorizeTextRoles(h.credentialDns, keys[i], a.issuer, true);
        }
        _meter("gas_authorize_issuer", g0);
        vm.stopPrank();
    }

    function _assertFinalState(Actors memory a, Hierarchy memory h) internal view {
        require(h.parentRegistry.ownerOf(h.passportTokenId) == a.user, "passport ownership");
        require(h.passportRegistry.ownerOf(h.credentialTokenId) == a.user, "credential ownership");
        require(h.passportResolver.addr(h.passportNode) == a.user, "passport addr");
        require(
            keccak256(bytes(h.passportResolver.text(h.passportNode, NomadicRecords.TYPE_KEY)))
                == keccak256(bytes(NomadicRecords.TYPE_PASSPORT)),
            "passport type"
        );
        require(
            keccak256(bytes(h.passportResolver.text(h.credentialNode, NomadicRecords.STATUS_KEY)))
                == keccak256("active"),
            "credential status"
        );

        IUniversalResolverV2 ur = IUniversalResolverV2(SepoliaENSv2.UNIVERSAL_RESOLVER_V2);
        require(ur.findOwner(h.passportDns) == a.user, "UR passport owner");
        require(ur.findOwner(h.credentialDns) == a.user, "UR credential owner");
        console2.log("assert_ownership_and_records OK");
    }

    function _demoIssuerPermissionsAndRevocation(Actors memory a, Hierarchy memory h) internal {
        vm.prank(a.issuer);
        h.passportResolver.setText(h.credentialNode, NomadicRecords.STATUS_KEY, "renewed");
        require(
            keccak256(bytes(h.passportResolver.text(h.credentialNode, NomadicRecords.STATUS_KEY)))
                == keccak256("renewed"),
            "issuer update"
        );

        uint256 nodeResource = PermissionedResolverLib.resource(h.credentialNode, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                IEnhancedAccessControl.EACUnauthorizedAccountRoles.selector,
                nodeResource,
                PermissionedResolverLib.ROLE_SET_TEXT,
                a.issuer
            )
        );
        vm.prank(a.issuer);
        h.passportResolver.setText(h.credentialNode, NomadicRecords.TYPE_KEY, "hack");

        // Passport owner / resolver admin must sign revocation.
        vm.prank(a.user);
        h.passportResolver.authorizeTextRoles(h.credentialDns, NomadicRecords.STATUS_KEY, a.issuer, false);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEnhancedAccessControl.EACUnauthorizedAccountRoles.selector,
                nodeResource,
                PermissionedResolverLib.ROLE_SET_TEXT,
                a.issuer
            )
        );
        vm.prank(a.issuer);
        h.passportResolver.setText(h.credentialNode, NomadicRecords.STATUS_KEY, "should-fail");

        require(h.parentRegistry.ownerOf(h.passportTokenId) == a.user, "ownership unchanged");
        require(h.passportRegistry.ownerOf(h.credentialTokenId) == a.user, "cred ownership unchanged");
        console2.log("assert_permissions_and_revocation OK");
        console2.log("revocationSigner", a.user);
    }
}
