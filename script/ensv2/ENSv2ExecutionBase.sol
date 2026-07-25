// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";
import {CloneProxyBytecode} from "@ensdomains/verifiable-factory/CloneProxyBytecode.sol";

import {EACBaseRolesLib} from "ensv2/access-control/libraries/EACBaseRolesLib.sol";
import {RegistryRolesLib} from "ensv2/registry/libraries/RegistryRolesLib.sol";

import {ENSv2DeploymentProfiles} from "../../src/ensv2/ENSv2DeploymentProfiles.sol";

interface IENSv2Proxy {
    function implementation() external view returns (address);
}

/// @dev Exact common subset of the historical r2 VerifiableFactory ABI.
interface IENSv2R2Factory {
    function deployProxy(address implementation, uint256 salt, bytes calldata data) external returns (address proxy);
    function proxyLogic() external view returns (address);
    function verifyContract(address proxy, address implementation) external view returns (bool);
}

/// @dev Exact operational subset shared by the historical r2 registry artifacts.
interface IENSv2R2Registry {
    function getParent() external view returns (address parent, string memory label);
    function getSubregistry(string calldata label) external view returns (address);
    function getResolver(string calldata label) external view returns (address);
    function findOwner(string calldata label) external view returns (address);
    function findExpiry(string calldata label) external view returns (uint64);
    function findTokenId(string calldata label) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function roles(uint256 resource, address account) external view returns (uint256);
    function hasRootRoles(uint256 roleBitmap, address account) external view returns (bool);
    function setParent(address parent, string calldata label) external;
    function register(
        string calldata label,
        address owner,
        address registry,
        address resolver,
        uint256 roleBitmap,
        uint64 expiry
    ) external returns (uint256 tokenId);
}

/// @dev Exact operational subset of the historical r2 PermissionedResolver ABI.
interface IENSv2R2Resolver {
    function addr(bytes32 node) external view returns (address);
    function text(bytes32 node, string calldata key) external view returns (string memory);
    function roles(uint256 resource, address account) external view returns (uint256);
    function setAddr(bytes32 node, address account) external;
    function setText(bytes32 node, string calldata key, string calldata value) external;
    function authorizeTextRoles(bytes calldata name, string calldata key, address account, bool grant)
        external
        returns (bool);
    function multicall(bytes[] calldata calls) external returns (bytes[] memory results);
    function multicallWithNodeCheck(bytes32 node, bytes[] calldata calls) external returns (bytes[] memory results);
}

interface IENSv2UniversalResolver {
    function ROOT_REGISTRY() external view returns (address);
    function findOwner(bytes calldata name) external view returns (address);
    function findExactRegistry(bytes calldata name) external view returns (address);
    function findCanonicalRegistry(bytes calldata name) external view returns (address);
    function findCanonicalName(address registry) external view returns (bytes memory);
    function findResolver(bytes calldata name) external view returns (address resolver, bytes32 node, uint256 offset);
    function resolve(bytes calldata name, bytes calldata data)
        external
        view
        returns (bytes memory result, address resolver);
}

/// @notice Shared profile, routing, deterministic deployment, and broadcast-lock safety.
abstract contract ENSv2ExecutionBase is Script {
    using ENSv2DeploymentProfiles for ENSv2DeploymentProfiles.Profile;

    error ENSV2_DEPLOYMENT_PROFILE_REQUIRED();
    error ENSV2_DEPLOYMENT_PROFILE_INVALID();
    error ENSV2_EXPLORER_R2_PROFILE_REQUIRED();
    error ENSV2_CURRENT_PROFILE_REQUIRED();
    error ENSV2_ROUTING_PROFILE_MISMATCH();
    error ENSV2_BROADCAST_LOCKED();
    error ENSV2_ROUTING_ACK_REQUIRED();

    uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;

    string internal constant PARENT_LABEL = "nomadic-passport";
    string internal constant PARENT_NAME = "nomadic-passport.eth";
    string internal constant PASSPORT_LABEL = "victor";
    string internal constant PASSPORT_NAME = "victor.nomadic-passport.eth";
    string internal constant CREDENTIAL_LABEL = "lisbon-house";
    string internal constant CREDENTIAL_NAME = "lisbon-house.victor.nomadic-passport.eth";

    uint256 internal constant PASSPORT_REGISTRY_SALT =
        uint256(keccak256("nomadic:explorer-v1-r2:victor:user-registry:v1"));
    uint256 internal constant PASSPORT_RESOLVER_SALT =
        uint256(keccak256("nomadic:explorer-v1-r2:victor:permissioned-resolver:v1"));

    function _loadProfile() internal view returns (ENSv2DeploymentProfiles.Profile memory p) {
        string memory value = vm.envOr("ENSV2_DEPLOYMENT_PROFILE", string(""));
        if (bytes(value).length == 0) revert ENSV2_DEPLOYMENT_PROFILE_REQUIRED();

        bytes32 id = keccak256(bytes(value));
        if (id == ENSv2DeploymentProfiles.CURRENT_ID) {
            return ENSv2DeploymentProfiles.current();
        }
        if (id == ENSv2DeploymentProfiles.EXPLORER_R2_ID) {
            return ENSv2DeploymentProfiles.explorerR2();
        }
        revert ENSV2_DEPLOYMENT_PROFILE_INVALID();
    }

    function _requireSepolia(ENSv2DeploymentProfiles.Profile memory p) internal view {
        if (block.chainid != p.chainId || p.chainId != SEPOLIA_CHAIN_ID) {
            revert("wrong chain: expected Sepolia 11155111");
        }
    }

    function _requireExplorerR2(ENSv2DeploymentProfiles.Profile memory p) internal pure {
        if (p.id != ENSv2DeploymentProfiles.EXPLORER_R2_ID) {
            revert ENSV2_EXPLORER_R2_PROFILE_REQUIRED();
        }
    }

    function _requireCurrent(ENSv2DeploymentProfiles.Profile memory p) internal pure {
        if (p.id != ENSv2DeploymentProfiles.CURRENT_ID) {
            revert ENSV2_CURRENT_PROFILE_REQUIRED();
        }
    }

    /// @notice Reverts with a stable selector if the public routing no longer serves Explorer-r2.
    function _assertExplorerRouting(ENSv2DeploymentProfiles.Profile memory p) internal view {
        _requireExplorerR2(p);

        address topImplementation = _readAddress(p.topUniversalResolver, abi.encodeCall(IENSv2Proxy.implementation, ()));
        address managedImplementation =
            _readAddress(p.managedUniversalResolver, abi.encodeCall(IENSv2Proxy.implementation, ()));
        address directRoot =
            _readAddress(p.universalResolver, abi.encodeCall(IENSv2UniversalResolver.ROOT_REGISTRY, ()));

        bytes memory parentDns = NameCoder.encode(PARENT_NAME);
        address owner =
            _readAddress(p.topUniversalResolver, abi.encodeCall(IENSv2UniversalResolver.findOwner, (parentDns)));
        address exact = _readAddress(
            p.topUniversalResolver, abi.encodeCall(IENSv2UniversalResolver.findExactRegistry, (parentDns))
        );
        address resolver =
            _readAddress(p.topUniversalResolver, abi.encodeCall(IENSv2UniversalResolver.findResolver, (parentDns)));

        if (
            topImplementation != p.managedUniversalResolver || managedImplementation != p.universalResolver
                || directRoot != p.rootRegistry || owner == address(0) || exact != p.nomadicRegistry
                || resolver == address(0)
        ) {
            revert ENSV2_ROUTING_PROFILE_MISMATCH();
        }
    }

    function _requireBroadcastUnlocked(ENSv2DeploymentProfiles.Profile memory p) internal view {
        _requireExplorerR2(p);
        if (!vm.envOr("ENSV2_BROADCAST", false)) revert ENSV2_BROADCAST_LOCKED();
        string memory ack = vm.envOr("ENSV2_ROUTING_ACK", string(""));
        if (keccak256(bytes(ack)) != keccak256("explorer-v1-r2-confirmed")) {
            revert ENSV2_ROUTING_ACK_REQUIRED();
        }
    }

    function _platform() internal view returns (address account) {
        account = vm.envAddress("NOMADIC_PARENT_OWNER_ADDRESS");
        require(account != address(0), "NOMADIC_PARENT_OWNER_ADDRESS required");
    }

    function _passportOwner() internal view returns (address account) {
        account = vm.envAddress("PASSPORT_OWNER_ADDRESS");
        require(account != address(0), "PASSPORT_OWNER_ADDRESS required");
    }

    function _issuer() internal view returns (address account) {
        account = vm.envAddress("LISBON_HOUSE_ISSUER_ADDRESS");
        require(account != address(0), "LISBON_HOUSE_ISSUER_ADDRESS required");
    }

    function _assertDistinctActors(address platform, address user, address issuer) internal pure {
        require(platform != user, "platform must differ from Passport owner");
        require(platform != issuer, "issuer must differ from platform");
        require(user != issuer, "issuer must differ from Passport owner");
    }

    function _historicalInitialize(address rootAccount) internal pure returns (bytes memory) {
        // Both r2 UserRegistry and PermissionedResolver use initialize(address,uint256).
        return abi.encodeWithSelector(
            bytes4(keccak256("initialize(address,uint256)")), rootAccount, EACBaseRolesLib.ALL_ROLES
        );
    }

    function _passportOwnerRoles() internal pure returns (uint256) {
        return RegistryRolesLib.ROLE_SET_SUBREGISTRY | RegistryRolesLib.ROLE_SET_SUBREGISTRY_ADMIN
            | RegistryRolesLib.ROLE_SET_RESOLVER | RegistryRolesLib.ROLE_SET_RESOLVER_ADMIN
            | RegistryRolesLib.ROLE_RENEW | RegistryRolesLib.ROLE_RENEW_ADMIN | RegistryRolesLib.ROLE_UNREGISTER
            | RegistryRolesLib.ROLE_UNREGISTER_ADMIN | RegistryRolesLib.ROLE_CAN_TRANSFER_ADMIN;
    }

    function _credentialOwnerRoles() internal pure returns (uint256) {
        return RegistryRolesLib.ROLE_SET_RESOLVER | RegistryRolesLib.ROLE_SET_RESOLVER_ADMIN
            | RegistryRolesLib.ROLE_CAN_TRANSFER_ADMIN;
    }

    function _predictProxy(ENSv2DeploymentProfiles.Profile memory p, address deployer, uint256 userSalt)
        internal
        view
        returns (address)
    {
        bytes32 outerSalt = keccak256(abi.encode(deployer, userSalt));
        address proxyLogic = IENSv2R2Factory(p.verifiableFactory).proxyLogic();
        bytes memory creationCode = CloneProxyBytecode.creationCode(proxyLogic, outerSalt);
        return Create2.computeAddress(outerSalt, keccak256(creationCode), p.verifiableFactory);
    }

    function _predictedPassportContracts(ENSv2DeploymentProfiles.Profile memory p, address platform)
        internal
        view
        returns (address passportRegistry, address passportResolver)
    {
        passportRegistry = _predictProxy(p, platform, PASSPORT_REGISTRY_SALT);
        passportResolver = _predictProxy(p, platform, PASSPORT_RESOLVER_SALT);
    }

    function _readAddress(address target, bytes memory data) private view returns (address value) {
        (bool ok, bytes memory result) = target.staticcall(data);
        if (!ok || result.length < 32) revert ENSV2_ROUTING_PROFILE_MISMATCH();
        assembly ("memory-safe") {
            value := mload(add(result, 0x20))
        }
    }
}
