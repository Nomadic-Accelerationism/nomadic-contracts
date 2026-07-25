// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @notice Central Sepolia ENSv2 deployment constants for Nomadic scripts.
/// @dev Generated from `addresses/sepolia.ensv2.json`, itself derived from
///      `lib/ens-contracts-v2/contracts/docs/addresses/sepolia.md` at the pinned
///      upstream commit. Do not hand-edit addresses here — regenerate the JSON
///      and update this library together.
library SepoliaENSv2 {
    string internal constant NETWORK = "sepolia";
    uint256 internal constant CHAIN_ID = 11155111;
    string internal constant DEPLOYED_AT = "2026-06-29T05:35:12.452Z";
    string internal constant UPSTREAM_COMMIT = "48b3e2d39513b9dd32ef1850877a29009bc807b9";
    string internal constant SOURCE_MD = "lib/ens-contracts-v2/contracts/docs/addresses/sepolia.md";
    string internal constant ADDRESS_FILE = "addresses/sepolia.ensv2.json";

    address internal constant ROOT_REGISTRY = 0x11b5BfbE9078D826b1eDBDd1cFC12f5828D9F50C;
    address internal constant ETH_REGISTRY = 0x67b728a792e789a8978b30cF1b3b641f19354b43;
    address internal constant ETH_REGISTRAR = 0xa4449a0dD2b83007553D9b1d28b583A46A805a30;
    address internal constant BATCH_REGISTRAR = 0xFE2AAb6Df1cbfF84534ce65D9E4a755Ba02D6795;
    address internal constant VERIFIABLE_FACTORY = 0x118Bc31A50d559F7015a8Da26d54B3b030CdB70F;
    address internal constant USER_REGISTRY_IMPL = 0x840Fa461059862Ea466A711E8C98c8dE732061C0;
    address internal constant PERMISSIONED_RESOLVER_IMPL = 0x7E4B2d59938930168024201752EE5503df402303;
    address internal constant PUBLIC_RESOLVER_V2 = 0xd25f66Dd4fF61486c2c5c1E6201A23576698D3df;
    address internal constant UNIVERSAL_RESOLVER_V2 = 0x85eDf8B6b7D4211e2b07AA687506B746357B92cf;
    address internal constant UPGRADABLE_UNIVERSAL_RESOLVER_PROXY = 0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe;
    address internal constant MANAGED_UNIVERSAL_RESOLVER_PROXY = 0x6d80F2172CFdEc5730fE683860C33d26fC42e6F1;
    address internal constant REVERSE_REGISTRAR_ADAPTER = 0x94E64e29e25533F93Ba0a430646Ae42CB47bf8F3;
    address internal constant DEFAULT_REVERSE_REGISTRAR_ADAPTER = 0x1F7B9461D17D5cF43553253C6b78d252D9575954;

    function requiredAddresses() internal pure returns (address[] memory addrs) {
        addrs = new address[](13);
        addrs[0] = ROOT_REGISTRY;
        addrs[1] = ETH_REGISTRY;
        addrs[2] = ETH_REGISTRAR;
        addrs[3] = BATCH_REGISTRAR;
        addrs[4] = VERIFIABLE_FACTORY;
        addrs[5] = USER_REGISTRY_IMPL;
        addrs[6] = PERMISSIONED_RESOLVER_IMPL;
        addrs[7] = PUBLIC_RESOLVER_V2;
        addrs[8] = UNIVERSAL_RESOLVER_V2;
        addrs[9] = UPGRADABLE_UNIVERSAL_RESOLVER_PROXY;
        addrs[10] = MANAGED_UNIVERSAL_RESOLVER_PROXY;
        addrs[11] = REVERSE_REGISTRAR_ADAPTER;
        addrs[12] = DEFAULT_REVERSE_REGISTRAR_ADAPTER;
    }

    function requiredNames() internal pure returns (string[] memory names) {
        names = new string[](13);
        names[0] = "RootRegistry";
        names[1] = "ETHRegistry";
        names[2] = "ETHRegistrar";
        names[3] = "BatchRegistrar";
        names[4] = "VerifiableFactory";
        names[5] = "UserRegistryImpl";
        names[6] = "PermissionedResolverImpl";
        names[7] = "PublicResolverV2";
        names[8] = "UniversalResolverV2";
        names[9] = "UpgradableUniversalResolverProxy";
        names[10] = "ManagedUniversalResolverProxy";
        names[11] = "ReverseRegistrarAdapter";
        names[12] = "DefaultReverseRegistrarAdapter";
    }
}
