// SPDX-License-Identifier: MIT
// Deployed at: 0x2A19790B6Dd1fC70e45e6F0D64A1a61C79a5Da0c
pragma solidity ^0.8.13;

import "fhenix-contracts/contracts/FHE.sol";

contract Users {

    // check if we can encrypt this...
    struct NewHacker {
       eaddress owner;
       euint32 age;
        bytes32 poap;
        bytes32 nouns;
        bytes32 ape;
        bytes32 talent;
        bytes32 financial;
        bytes32 identity;
        bytes32 farcaster;
        bytes32 ens;
    }

    mapping(eaddress => NewHacker) public hackers;

    function createHacker(address _owner, uint32 _age, bytes32 _poap, bytes32 _nouns, bytes32 _ape, bytes32 _talent, bytes32 _financial, bytes32 _identity, bytes32 _farcaster, bytes32 _ens) public {
        eaddress eOwner = FHE.asEaddress(_owner);
    
        NewHacker memory newHacker = NewHacker({
            owner: eOwner,
            age: FHE.asEuint32(_age),
            poap: _poap,
            nouns: _nouns,
            ape: _ape,
            talent: _talent,
            financial: _financial,
            identity: _identity,
            farcaster: _farcaster,
            ens: _ens
        });
        hackers[eOwner] = newHacker;
    }

    function getHacker(address _owner) public view returns (NewHacker memory) {
        return hackers[FHE.asEaddress(_owner)];
    }
}