// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFeeManager {
    function handleFee(address from, uint256 amount) external returns (uint256);
}
