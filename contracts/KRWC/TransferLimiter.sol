// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TransferLimit } from "contracts/types/TransferLimitTypes.sol";

abstract contract TransferLimiter {
    mapping(uint32 => TransferLimit) public transferLimitConfigs;
    mapping(uint32 => uint256) public dailyTransferAmount;
    mapping(uint32 => uint256) public lastUpdatedTime;
    mapping(uint32 => mapping(address => uint256)) public userDailyTransferAmount;
    mapping(uint32 => mapping(address => uint256)) public userDailyAttempt;
    mapping(uint32 => mapping(address => uint256)) public lastUserUpdatedTime;

    error TransferLimitExceeded();
    error TransferLimitNotSet();

    function _setTransferLimitConfigs(TransferLimit[] memory configs) internal {
        for (uint256 i = 0; i < configs.length; i++) {
            TransferLimit memory l = configs[i];
            transferLimitConfigs[l.dstEid] = l;
        }
    }

    function _checkAndUpdateTransferLimit(uint32 dstEid, uint256 amount, address user) internal {
        TransferLimit memory limit = transferLimitConfigs[dstEid];
        if (limit.dstEid == 0) revert TransferLimitNotSet();

        if (block.timestamp - lastUpdatedTime[dstEid] >= 1 days) {
            dailyTransferAmount[dstEid] = 0;
        }
        if (block.timestamp - lastUserUpdatedTime[dstEid][user] >= 1 days) {
            userDailyTransferAmount[dstEid][user] = 0;
            userDailyAttempt[dstEid][user] = 0;
        }

        if (
            amount < limit.singleTransferLowerLimit ||
            amount > limit.singleTransferUpperLimit ||
            dailyTransferAmount[dstEid] + amount > limit.maxDailyTransferAmount ||
            userDailyTransferAmount[dstEid][user] + amount > limit.dailyTransferAmountPerAddress ||
            userDailyAttempt[dstEid][user] >= limit.dailyTransferAttemptPerAddress
        ) revert TransferLimitExceeded();

        dailyTransferAmount[dstEid] += amount;
        userDailyTransferAmount[dstEid][user] += amount;
        userDailyAttempt[dstEid][user] += 1;

        lastUpdatedTime[dstEid] = block.timestamp;
        lastUserUpdatedTime[dstEid][user] = block.timestamp;
    }

    // override in KRWC contract
    function _removeDust(uint256 value) internal view virtual returns (uint256) {
        return value; // 정제 로직 필요시 구현
    }
}
