// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFeeManager {
    function handleMintFee(address minter, uint256 feeAmount) external returns (uint256);
    function handleBurnFee(address from, uint256 feeAmount) external returns (uint256);
}
