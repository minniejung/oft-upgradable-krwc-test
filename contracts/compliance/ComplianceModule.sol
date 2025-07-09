// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "contracts/interfaces/IComplianceModule.sol";

contract ComplianceModule is Initializable, OwnableUpgradeable, UUPSUpgradeable, IComplianceModule {
    mapping(address => bool) public allowlist;
    mapping(address => bool) public blocklist;
    mapping(address => bool) public sanctionsList;

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function setAllowlist(address user, bool value) external onlyOwner {
        allowlist[user] = value;
    }

    function setBlocklist(address user, bool value) external onlyOwner {
        blocklist[user] = value;
    }

    function setSanctions(address user, bool value) external onlyOwner {
        sanctionsList[user] = value;
    }

    function isCompliant(address user) external view override returns (bool) {
        if (blocklist[user]) return false;
        if (sanctionsList[user]) return false;
        if (!allowlist[user]) return false;
        return true;
    }
}
