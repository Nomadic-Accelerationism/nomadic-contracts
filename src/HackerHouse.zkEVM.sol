// SPDX-License-Identifier: MIT
// Owner must be encrypted
// Owner should have zk proof of budget
pragma solidity ^0.8.13;

contract HackerHouse {
    enum HouseStatus {
        Pending,
        Active,
        Inactive,
        Canceled
    }

    struct NewHackerHouse {
        address owner;
        string city;
        uint256 startDate;
        uint256 endDate;
        uint256 budget; // get from collateral deposited
        uint256 hackers;
        HouseStatus status;
    }

    mapping(address => NewHackerHouse) public hackerHouses;

    function createHackerHouse(address _owner, string memory _city, uint _startDate, uint _endDate, uint _budget, uint _hackers) public {
        require(_startDate < _endDate && _startDate > block.timestamp, "Invalid date range");
        require(_budget > 0, "Invalid budget"); // get proof from collateral deposited
        require(_hackers > 0, "Invalid hackers");
        NewHackerHouse memory newHackerHouse = NewHackerHouse({
            owner: _owner,
            city: _city,
            startDate: _startDate,
            endDate: _endDate,
            budget: _budget,
            hackers: _hackers,
            status: HouseStatus.Pending
        });
        hackerHouses[msg.sender] = newHackerHouse;
    }

    function approveHackerHouse(address _owner) public {
        require(hackerHouses[_owner].status == HouseStatus.Pending, "House is not pending");
        hackerHouses[_owner].status = HouseStatus.Active;
    }

    function cancelHackHouse(address _owner) public {
        require(hackerHouses[_owner].status == HouseStatus.Canceled, "House is already Canceled");
        hackerHouses[_owner].status = HouseStatus.Canceled;
    }

    function getHackerHouse(address _owner) public view returns (NewHackerHouse memory) {
        return hackerHouses[_owner];
    }
}