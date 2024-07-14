// SPDX-License-Identifier: MIT
// POF (Proof of Financial)
// staking: APE, Nouns, ETH
// Deployed at: 0x950650FdA9C97c24aA90C6f0C3e8d9DDbA4a48Fb
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Staking {

    address constant apeCoinAddress = 0xa0289cBbEB673b8787C9C61Bf03914068A033651;
    address constant ethAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping(address => uint256) apeStakedAmount;
    mapping(address => uint256) ethStakedAmount;

    function stakeApe(uint256 amount) public {
        if(amount == 0) revert();
        IERC20 apeCoin = IERC20(apeCoinAddress);
        require(apeCoin.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        apeStakedAmount[msg.sender] += amount;
    }

    function stakeEth() public payable {
        if(msg.value == 0) revert();
        ethStakedAmount[msg.sender] += msg.value;
    }

    function getUserBalance(address _user) public view returns (uint, uint) {
        return (apeStakedAmount[_user], ethStakedAmount[_user]);
    }
}