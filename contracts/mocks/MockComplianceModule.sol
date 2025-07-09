// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "contracts/interfaces/IComplianceModule.sol";

contract MockComplianceModule is IComplianceModule {
    bool public allowed = true;

    function setAllowed(bool _allowed) external {
        allowed = _allowed;
    }

    function isCompliant(address) external view override returns (bool) {
        return allowed;
    }
}
