// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./OFTCoreUpgradeable.sol";

abstract contract OFTUpgradeable is OFTCoreUpgradeable, ERC20Upgradeable {
    function __OFTUpgradeable_init(
        string memory _name,
        string memory _symbol,
        uint8 _localDecimals,
        address _lzEndpoint,
        address _delegate
    ) internal onlyInitializing {
        __ERC20_init(_name, _symbol);
        __OFTCore_init(_localDecimals, _lzEndpoint, _delegate);
    }

    function __OFTUpgradeable_init_unchained() internal onlyInitializing {}

    function token() public view returns (address) {
        return address(this);
    }

    function approvalRequired() external pure virtual returns (bool) {
        return false;
    }

    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        _burn(_from, amountSentLD);
    }

    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    ) internal virtual override returns (uint256 amountReceivedLD) {
        if (_to == address(0)) _to = address(0xdead);
        _mint(_to, _amountLD);
        return _amountLD;
    }
}
