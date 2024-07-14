// SPDX-License-Identifier: MIT
// Deployed at: 0x950650fda9c97c24aa90c6f0c3e8d9ddba4a48fb
pragma solidity ^0.8.13;

import "lib/fhenix-contracts/contracts/FHE.sol";

contract Journey {
    // check if we can encrypt this...
    struct NewJourney {
       eaddress user;
       euint256 budget;
       string city;
       euint256 startDate;
       euint256 endDate;
    }

    mapping(eaddress => NewJourney) public hackerJourney;

    function createJourney(
        address _user,
        uint256 _budget,
        string memory _city,
        uint _startDate,
        uint _endDate
    ) public {
        eaddress eUser = FHE.asEaddress(_user);
    
        NewJourney memory newJourney = NewJourney({
            user: eUser,
            budget: FHE.asEuint256(_budget),
            city: _city,
            startDate: FHE.asEuint256(_startDate),
            endDate: FHE.asEuint256(_endDate)
        });
        hackerJourney[eUser] = newJourney;
    }

    function getJourney(address _user) public view returns (NewJourney memory) {
        return hackerJourney[FHE.asEaddress(_user)];
    }
}