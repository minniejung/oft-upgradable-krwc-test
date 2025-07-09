// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IComplianceModule {
    /**
     * @notice Returns true if the given user passes compliance checks
     * @param user The address to check
     */
    function isCompliant(address user) external view returns (bool);
}
