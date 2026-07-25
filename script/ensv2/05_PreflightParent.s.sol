// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {NameCoder} from "@ens/contracts/utils/NameCoder.sol";

import {ETHRegistrar} from "ensv2/registrar/ETHRegistrar.sol";
import {IETHRegistrar} from "ensv2/registrar/interfaces/IETHRegistrar.sol";
import {IRegistry} from "ensv2/registry/interfaces/IRegistry.sol";
import {ITemporalRegistry} from "ensv2/registry/interfaces/ITemporalRegistry.sol";
import {IPermissionedRegistry} from "ensv2/registry/interfaces/IPermissionedRegistry.sol";
import {RegistryRolesLib} from "ensv2/registry/libraries/RegistryRolesLib.sol";
import {IUniversalResolverV2} from "ensv2/universalResolver/interfaces/IUniversalResolverV2.sol";
import {UniversalResolverV2} from "ensv2/universalResolver/UniversalResolverV2.sol";

import {SepoliaENSv2} from "../../src/ensv2/SepoliaENSv2.sol";

/// @notice Read-only preflight for `nomadic-passport.eth` and registrar path. Never broadcasts.
contract PreflightParentScript is Script {
    // Sepolia mock payment tokens from pinned deployments.
    address internal constant MOCK_USDC = 0xD3322B29a7BdEe707D1684676f149bf41Aa3422f;
    address internal constant MOCK_DAI = 0xE33a01a41eE4a68616B5278183aa88808326ED8E;

    function run() external view {
        require(block.chainid == SepoliaENSv2.CHAIN_ID, "wrong chain: expected Sepolia 11155111");

        string memory parentName = vm.envOr("ENSV2_PARENT_NAME", string("nomadic-passport.eth"));
        address parentOwner = vm.envOr("NOMADIC_PARENT_OWNER_ADDRESS", address(0));
        if (parentOwner == address(0)) {
            parentOwner = vm.envOr("ENSV2_PLATFORM_ADDRESS", address(0));
        }
        address passportOwner = vm.envOr("PASSPORT_OWNER_ADDRESS", address(0));
        if (passportOwner == address(0)) {
            passportOwner = vm.envOr("ENSV2_PASSPORT_OWNER_ADDRESS", address(0));
        }
        address issuer = vm.envOr("LISBON_HOUSE_ISSUER_ADDRESS", address(0));
        if (issuer == address(0)) {
            issuer = vm.envOr("ENSV2_ISSUER_ADDRESS", address(0));
        }

        console2.log("=== PREFLIGHT: parent + registrar ===");
        console2.log("upstreamCommit", SepoliaENSv2.UPSTREAM_COMMIT);
        console2.log("parentName", parentName);
        console2.log("NOMADIC_PARENT_OWNER_ADDRESS", parentOwner);
        console2.log("PASSPORT_OWNER_ADDRESS", passportOwner);
        console2.log("LISBON_HOUSE_ISSUER_ADDRESS", issuer);
        if (parentOwner != address(0) && issuer != address(0) && parentOwner == issuer) {
            console2.log("WARNING: parent owner == issuer; scoped-permission demo clearer with distinct issuer");
        }

        string memory label = _firstLabel(parentName);
        bytes memory dnsName = NameCoder.encode(parentName);
        console2.log("label", label);
        console2.logBytes(dnsName);

        ETHRegistrar registrar = ETHRegistrar(SepoliaENSv2.ETH_REGISTRAR);
        bool available = registrar.isAvailable(label);
        console2.log("ETHRegistrar.isAvailable", available ? "true" : "false");
        console2.log(string.concat("MIN_COMMITMENT_AGE=", vm.toString(uint256(registrar.MIN_COMMITMENT_AGE()))));
        console2.log(string.concat("MAX_COMMITMENT_AGE=", vm.toString(uint256(registrar.MAX_COMMITMENT_AGE()))));
        console2.log(string.concat("MIN_REGISTER_DURATION=", vm.toString(uint256(registrar.MIN_REGISTER_DURATION()))));

        uint64 duration1y = 365 days;
        (uint256 usdcBase, uint256 usdcPremium) =
            IETHRegistrar(address(registrar)).getRegisterPrice(label, duration1y, IERC20(MOCK_USDC));
        (uint256 daiBase, uint256 daiPremium) =
            IETHRegistrar(address(registrar)).getRegisterPrice(label, duration1y, IERC20(MOCK_DAI));
        console2.log(string.concat("price_1y_USDC_base=", vm.toString(usdcBase)));
        console2.log(string.concat("price_1y_USDC_premium=", vm.toString(usdcPremium)));
        console2.log(string.concat("price_1y_DAI_base=", vm.toString(daiBase)));
        console2.log(string.concat("price_1y_DAI_premium=", vm.toString(daiPremium)));

        (uint256 usdcMinBase,) = IETHRegistrar(address(registrar))
            .getRegisterPrice(label, registrar.MIN_REGISTER_DURATION(), IERC20(MOCK_USDC));
        console2.log(string.concat("price_minDuration_USDC_base=", vm.toString(usdcMinBase)));

        IUniversalResolverV2 ur = IUniversalResolverV2(SepoliaENSv2.UNIVERSAL_RESOLVER_V2);
        UniversalResolverV2 urConcrete = UniversalResolverV2(SepoliaENSv2.UNIVERSAL_RESOLVER_V2);
        IRegistry exact = ur.findExactRegistry(dnsName);
        IRegistry canonical = ur.findCanonicalRegistry(dnsName);
        IRegistry containing = ur.findParentRegistry(dnsName);
        (address resolver,,) = urConcrete.findResolver(dnsName);
        address owner = ur.findOwner(dnsName);
        uint64 expiry = ITemporalRegistry(SepoliaENSv2.ETH_REGISTRY).findExpiry(label);
        address sub = address(IRegistry(SepoliaENSv2.ETH_REGISTRY).getSubregistry(label));

        console2.log("exactRegistry", address(exact));
        console2.log("canonicalRegistry", address(canonical));
        console2.log("containingRegistry", address(containing));
        console2.log("resolver", resolver);
        console2.log("owner", owner);
        console2.log(string.concat("expiry=", vm.toString(uint256(expiry))));
        console2.log("subregistry", sub);

        string memory state;
        if (available && owner == address(0) && expiry == 0) {
            state = "AVAILABLE_UNREGISTERED";
        } else if (owner != address(0) && block.timestamp < expiry) {
            state = "REGISTERED_ACTIVE";
        } else if (expiry != 0 && block.timestamp >= expiry) {
            state = "EXPIRED_OR_GRACE";
        } else {
            state = "UNKNOWN";
        }
        console2.log("parentState", state);

        if (parentOwner != address(0) && address(exact) != address(0)) {
            bool canRegister =
                IPermissionedRegistry(address(exact)).hasRootRoles(RegistryRolesLib.ROLE_REGISTRAR, parentOwner);
            console2.log("platformHasRegistrarOnExact", canRegister ? "true" : "false");
        }

        // Alternatives if unavailable (still report even when available).
        console2.log(
            "alt_nomadic-passport-test_available", registrar.isAvailable("nomadic-passport-test") ? "true" : "false"
        );
        console2.log(
            "alt_nomadic-lisbon-passport_available", registrar.isAvailable("nomadic-lisbon-passport") ? "true" : "false"
        );
        console2.log(
            "alt_nomadic-ethglobal-lisbon_available",
            registrar.isAvailable("nomadic-ethglobal-lisbon") ? "true" : "false"
        );

        console2.log("RESULT: preflight parent inspection complete (read-only)");
    }

    function _firstLabel(string memory name) internal pure returns (string memory) {
        bytes memory b = bytes(name);
        uint256 end = b.length;
        for (uint256 i = 0; i < b.length; i++) {
            // forge-lint: disable-next-line(unsafe-typecast)
            if (b[i] == bytes1(".")) {
                end = i;
                break;
            }
        }
        bytes memory out = new bytes(end);
        for (uint256 j = 0; j < end; j++) {
            out[j] = b[j];
        }
        return string(out);
    }
}
