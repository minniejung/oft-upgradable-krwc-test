// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { IFeeManager } from "./interfaces/IFeeManager.sol";

contract MockFeeManager is IFeeManager {
    function handleFee(address /* from */, uint256 amount) external pure returns (uint256) {
        return amount; // Return the same amount for testing
    }
}
