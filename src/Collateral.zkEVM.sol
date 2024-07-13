// SPDX-License-Identifier: MIT
// ETH as a Collateral
// Integrate Chronicle oracle eth/usd price feed
pragma solidity ^0.8.13;

contract Collateral {

    mapping(address => uint256) ethStakedAmount;
    
    event Deposit(address indexed sender, uint amount);

    fallback() external payable {}

    receive() external payable {
        if(msg.value == 0) revert();
        ethStakedAmount[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function liquidate(address _user, uint _amount) public {
        require(ethStakedAmount[_user] >= _amount, "Insufficient balance");
        ethStakedAmount[_user] -= _amount;
    }

    function getBalance(address _user) public view returns (uint) {
        return ethStakedAmount[_user];
    }

}