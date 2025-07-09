// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "contracts/interfaces/IComplianceModule.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract ComplianceClientUpgradeable is Initializable {
    IComplianceModule public compliance;

    event ComplianceModuleSet(address oldModule, address newModule);

    function __ComplianceClient_init(address _module) internal onlyInitializing {
        _setComplianceModule(_module);
    }

    function _setComplianceModule(address _module) internal {
        require(_module != address(0), "Compliance: zero address");
        address old = address(compliance);
        compliance = IComplianceModule(_module);
        emit ComplianceModuleSet(old, _module);
    }

    function _isCompliant(address user) internal view returns (bool) {
        return compliance.isCompliant(user);
    }

    uint256[50] private __gap;
}
