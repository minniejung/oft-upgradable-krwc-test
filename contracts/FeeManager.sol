// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FeeManager is Ownable {
    address public lpReceiver;
    address public treasuryReceiver;

    constructor(address _lpReceiver, address _treasuryReceiver, address _owner) Ownable(_owner) {
        require(_lpReceiver != address(0) && _treasuryReceiver != address(0), "invalid address");
        lpReceiver = _lpReceiver;
        treasuryReceiver = _treasuryReceiver;
    }

    function setReceivers(address _lpReceiver, address _treasuryReceiver) external onlyOwner {
        require(_lpReceiver != address(0) && _treasuryReceiver != address(0), "invalid address");
        lpReceiver = _lpReceiver;
        treasuryReceiver = _treasuryReceiver;
    }

    function handleFee(address from, uint256 amount) external returns (uint256) {
        uint256 lpAmount = (amount * 70) / 100;
        uint256 treasuryAmount = amount - lpAmount;

        require(lpAmount + treasuryAmount == amount, "math error");

        require(IERC20(msg.sender).transferFrom(from, lpReceiver, lpAmount), "LP fee transfer failed");
        require(
            IERC20(msg.sender).transferFrom(from, treasuryReceiver, treasuryAmount),
            "Treasury fee transfer failed"
        );

        return amount;
    }
}
