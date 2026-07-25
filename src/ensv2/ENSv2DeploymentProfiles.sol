// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @notice Explicit, non-interchangeable ENSv2 Sepolia deployment profiles.
/// @dev Deployment addresses may be hardcoded; user/operator addresses must remain environment supplied.
library ENSv2DeploymentProfiles {
    bytes32 internal constant CURRENT_ID = keccak256("current");
    bytes32 internal constant EXPLORER_R2_ID = keccak256("explorer-v1-r2");

    string internal constant UPSTREAM_COMMIT = "48b3e2d39513b9dd32ef1850877a29009bc807b9";

    struct Profile {
        bytes32 id;
        string name;
        string addressFile;
        string artifactNamespace;
        uint256 chainId;
        address rootRegistry;
        address ethRegistry;
        address ethRegistrar;
        address verifiableFactory;
        address userRegistryImpl;
        address permissionedResolverImpl;
        address publicResolver;
        address universalResolver;
        address managedUniversalResolver;
        address topUniversalResolver;
        address nomadicRegistry;
        address nomadicResolver;
        address mockUSDC;
        address mockDAI;
        bool historicalResolverInitializer;
    }

    function current() internal pure returns (Profile memory p) {
        p.id = CURRENT_ID;
        p.name = "current";
        p.addressFile = "addresses/sepolia.ensv2.current.json";
        p.artifactNamespace = "lib/ens-contracts-v2/contracts/deployments/sepolia";
        p.chainId = 11155111;
        p.rootRegistry = 0x11b5BfbE9078D826b1eDBDd1cFC12f5828D9F50C;
        p.ethRegistry = 0x67b728a792e789a8978b30cF1b3b641f19354b43;
        p.ethRegistrar = 0xa4449a0dD2b83007553D9b1d28b583A46A805a30;
        p.verifiableFactory = 0x118Bc31A50d559F7015a8Da26d54B3b030CdB70F;
        p.userRegistryImpl = 0x840Fa461059862Ea466A711E8C98c8dE732061C0;
        p.permissionedResolverImpl = 0x7E4B2d59938930168024201752EE5503df402303;
        p.publicResolver = 0xd25f66Dd4fF61486c2c5c1E6201A23576698D3df;
        p.universalResolver = 0x85eDf8B6b7D4211e2b07AA687506B746357B92cf;
        p.managedUniversalResolver = 0x6d80F2172CFdEc5730fE683860C33d26fC42e6F1;
        p.topUniversalResolver = 0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe;
        p.mockUSDC = 0xD3322B29a7BdEe707D1684676f149bf41Aa3422f;
        p.mockDAI = 0xE33a01a41eE4a68616B5278183aa88808326ED8E;
    }

    function explorerR2() internal pure returns (Profile memory p) {
        p.id = EXPLORER_R2_ID;
        p.name = "explorer-v1-r2";
        p.addressFile = "addresses/sepolia.ensv2.explorer-v1-r2.json";
        p.artifactNamespace = "lib/ens-contracts-v2/contracts/deployments/sepolia-official-v1-20260525-r2";
        p.chainId = 11155111;
        p.rootRegistry = 0xc960F7217d3643B525Ef36Bec8Adf86953CD9aB8;
        p.ethRegistry = 0xDEDB92913A25abE1f7BCDD85D8A344a43B398B67;
        p.ethRegistrar = 0x8c2E866B439358c41AE05De9cbE8A00BFEFafFcA;
        p.verifiableFactory = 0xD2a632D8a8b67c2c4398c255CbD7aF8dd7236198;
        p.userRegistryImpl = 0x0F99e7Ea74903AfCB7224d0354fD7428A6f92917;
        p.permissionedResolverImpl = 0xdcE5205A553573FFd47629327DDdf36186022FfA;
        p.publicResolver = 0x5239A812ec9A62F46dbb5de8f346C8eFe7553A9f;
        p.universalResolver = 0x2F8A180604c42457Cb56C7c4f708748fF1F91DF1;
        p.managedUniversalResolver = 0x6d80F2172CFdEc5730fE683860C33d26fC42e6F1;
        p.topUniversalResolver = 0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe;
        p.nomadicRegistry = 0x8fB12e7Ab9B192503d7d02a43e0507c484e27280;
        p.nomadicResolver = 0xa39e2EC60d8b34F88c16A5829ae5759C0C34CC4B;
        p.mockUSDC = 0xBA11ebdB3f9a2c5946D8629517f06364E53A2E10;
        p.mockDAI = 0x2922bCD677Af690fCD1eCC699519e4bfaBc73fF8;
        p.historicalResolverInitializer = true;
    }

    function coreAddresses(Profile memory p) internal pure returns (address[] memory addrs) {
        addrs = new address[](10);
        addrs[0] = p.rootRegistry;
        addrs[1] = p.ethRegistry;
        addrs[2] = p.ethRegistrar;
        addrs[3] = p.verifiableFactory;
        addrs[4] = p.userRegistryImpl;
        addrs[5] = p.permissionedResolverImpl;
        addrs[6] = p.publicResolver;
        addrs[7] = p.universalResolver;
        addrs[8] = p.managedUniversalResolver;
        addrs[9] = p.topUniversalResolver;
    }

    function coreNames() internal pure returns (string[] memory names) {
        names = new string[](10);
        names[0] = "RootRegistry";
        names[1] = "ETHRegistry";
        names[2] = "ETHRegistrar";
        names[3] = "VerifiableFactory";
        names[4] = "UserRegistryImpl";
        names[5] = "PermissionedResolverImpl";
        names[6] = "PublicResolverV2";
        names[7] = "UniversalResolverV2";
        names[8] = "ManagedUniversalResolverProxy";
        names[9] = "UpgradableUniversalResolverProxy";
    }
}
