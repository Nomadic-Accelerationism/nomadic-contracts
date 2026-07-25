// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IRegistry} from "ensv2/registry/interfaces/IRegistry.sol";
import {IPermissionedRegistry} from "ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {ENSv2DeploymentProfiles} from "../../src/ensv2/ENSv2DeploymentProfiles.sol";
import {SepoliaENSv2} from "../../src/ensv2/SepoliaENSv2.sol";
import {ENSv2ExecutionBase} from "./ENSv2ExecutionBase.sol";

/// @notice Read-only Sepolia ENSv2 deployment verification. Never broadcasts.
contract VerifyDeploymentScript is ENSv2ExecutionBase {
    using stdJson for string;

    function run() external {
        ENSv2DeploymentProfiles.Profile memory deployment = _loadProfile();
        _requireCurrent(deployment);
        uint256 chainId = block.chainid;
        console2.log("chainId", chainId);
        require(chainId == SepoliaENSv2.CHAIN_ID, "wrong chain: expected Sepolia 11155111");

        _assertAddressFileMatchesLibrary();
        _assertUpstreamMdContainsAddresses();
        _assertBytecodeEverywhere();
        _probeInterfacesAndState();

        console2.log("RESULT: Sepolia ENSv2 deployment verification PASSED");
        console2.log("upstreamCommit", SepoliaENSv2.UPSTREAM_COMMIT);
        console2.log("deployedAt", SepoliaENSv2.DEPLOYED_AT);
    }

    function _assertAddressFileMatchesLibrary() internal view {
        string memory raw = vm.readFile(SepoliaENSv2.ADDRESS_FILE);
        require(raw.readUint(".chainId") == SepoliaENSv2.CHAIN_ID, "json chainId mismatch");
        require(
            keccak256(bytes(raw.readString(".upstreamCommit"))) == keccak256(bytes(SepoliaENSv2.UPSTREAM_COMMIT)),
            "json upstreamCommit mismatch"
        );
        require(
            keccak256(bytes(raw.readString(".deployedAt"))) == keccak256(bytes(SepoliaENSv2.DEPLOYED_AT)),
            "json deployedAt mismatch"
        );

        string[] memory names = SepoliaENSv2.requiredNames();
        address[] memory addrs = SepoliaENSv2.requiredAddresses();
        for (uint256 i = 0; i < names.length; i++) {
            string memory path = string.concat(".addresses.", names[i]);
            address fromJson = raw.readAddress(path);
            require(fromJson == addrs[i], string.concat("json/library mismatch: ", names[i]));
        }
        console2.log("address file matches SepoliaENSv2 library");
    }

    function _assertUpstreamMdContainsAddresses() internal view {
        string memory md = vm.readFile(SepoliaENSv2.SOURCE_MD);
        address[] memory addrs = SepoliaENSv2.requiredAddresses();
        string[] memory names = SepoliaENSv2.requiredNames();
        for (uint256 i = 0; i < addrs.length; i++) {
            string memory lower = _toLowerHex(addrs[i]);
            require(
                _contains(md, lower) || _contains(md, vm.toString(addrs[i])),
                string.concat("upstream md missing ", names[i])
            );
        }
        console2.log("pinned upstream sepolia.md contains required addresses");
    }

    function _assertBytecodeEverywhere() internal view {
        string[] memory names = SepoliaENSv2.requiredNames();
        address[] memory addrs = SepoliaENSv2.requiredAddresses();
        for (uint256 i = 0; i < addrs.length; i++) {
            uint256 size;
            address a = addrs[i];
            assembly {
                size := extcodesize(a)
            }
            require(size > 0, string.concat("empty bytecode: ", names[i]));
            console2.log(names[i], a, size);
        }
    }

    function _probeInterfacesAndState() internal view {
        // Root / ETH registries expose IRegistry / IERC165.
        require(
            IERC165(SepoliaENSv2.ROOT_REGISTRY).supportsInterface(type(IRegistry).interfaceId),
            "RootRegistry missing IRegistry"
        );
        require(
            IERC165(SepoliaENSv2.ETH_REGISTRY).supportsInterface(type(IRegistry).interfaceId),
            "ETHRegistry missing IRegistry"
        );
        require(
            IERC165(SepoliaENSv2.ROOT_REGISTRY).supportsInterface(type(IPermissionedRegistry).interfaceId),
            "RootRegistry missing IPermissionedRegistry"
        );

        IRegistry eth = IRegistry(SepoliaENSv2.ROOT_REGISTRY).getSubregistry("eth");
        require(address(eth) == SepoliaENSv2.ETH_REGISTRY, "RootRegistry.eth subregistry mismatch");

        (IRegistry ethParent, string memory ethLabel) = IRegistry(SepoliaENSv2.ETH_REGISTRY).getParent();
        require(address(ethParent) == SepoliaENSv2.ROOT_REGISTRY, "ETHRegistry parent mismatch");
        require(keccak256(bytes(ethLabel)) == keccak256("eth"), "ETHRegistry parent label mismatch");

        console2.log("VerifiableFactory", SepoliaENSv2.VERIFIABLE_FACTORY);

        uint256 urSize;
        uint256 proxySize;
        address ur = SepoliaENSv2.UNIVERSAL_RESOLVER_V2;
        address proxy = SepoliaENSv2.UPGRADABLE_UNIVERSAL_RESOLVER_PROXY;
        assembly {
            urSize := extcodesize(ur)
            proxySize := extcodesize(proxy)
        }
        require(urSize > 0 && proxySize > 0, "UR or proxy missing bytecode");
        console2.log("UniversalResolverV2 size", urSize);
        console2.log("UpgradableUniversalResolverProxy size", proxySize);
        console2.log("direct UR and proxy both available");
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length == 0 || n.length > h.length) return false;
        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool ok = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return true;
        }
        return false;
    }

    function _toLowerHex(address a) internal pure returns (string memory) {
        bytes20 data = bytes20(a);
        bytes16 hexSymbols = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = hexSymbols[uint8(data[i] >> 4)];
            str[3 + i * 2] = hexSymbols[uint8(data[i]) & 0x0f];
        }
        return string(str);
    }
}
