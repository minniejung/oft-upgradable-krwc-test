// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct TransferLimit {
    uint32 dstEid;
    uint256 maxDailyTransferAmount;
    uint256 singleTransferUpperLimit;
    uint256 singleTransferLowerLimit;
    uint256 dailyTransferAmountPerAddress;
    uint256 dailyTransferAttemptPerAddress;
}
