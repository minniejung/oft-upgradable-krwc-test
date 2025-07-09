// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { OAppUpgradeable, Origin } from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import { OAppOptionsType3Upgradeable } from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";
import { IOAppMsgInspector } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppMsgInspector.sol";

import { OAppPreCrimeSimulatorUpgradeable } from "@layerzerolabs/oapp-evm-upgradeable/contracts/precrime/OAppPreCrimeSimulatorUpgradeable.sol";

import { IOFT, SendParam, OFTLimit, OFTReceipt, OFTFeeDetail, MessagingReceipt, MessagingFee } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

abstract contract OFTCoreUpgradeable is
    IOFT,
    OAppUpgradeable,
    OAppPreCrimeSimulatorUpgradeable,
    OAppOptionsType3Upgradeable
{
    using OFTMsgCodec for bytes;
    using OFTMsgCodec for bytes32;

    struct OFTCoreStorage {
        address msgInspector;
        uint256 decimalConversionRate;
    }

    bytes32 private constant OFT_CORE_STORAGE_LOCATION =
        0x41db8a78b0206aba5c54bcbfc2bda0d84082a84eb88e680379a57b9e9f653c00;

    uint16 public constant SEND = 1;
    uint16 public constant SEND_AND_CALL = 2;

    event MsgInspectorSet(address inspector);

    function _getOFTCoreStorage() internal pure returns (OFTCoreStorage storage $) {
        assembly {
            $.slot := OFT_CORE_STORAGE_LOCATION
        }
    }

    function __OFTCore_init(uint8 _localDecimals, address _endpoint, address _delegate) internal onlyInitializing {
        __OApp_init(_delegate);
        __OAppPreCrimeSimulator_init();
        __OAppOptionsType3_init();

        uint8 _sharedDecimals = sharedDecimals();
        if (_localDecimals < _sharedDecimals) revert("InvalidLocalDecimals");
        _getOFTCoreStorage().decimalConversionRate = 10 ** (_localDecimals - _sharedDecimals);
    }

    function sharedDecimals() public pure virtual returns (uint8) {
        return 6;
    }

    function decimalConversionRate() public view returns (uint256) {
        return _getOFTCoreStorage().decimalConversionRate;
    }

    function msgInspector() public view returns (address) {
        return _getOFTCoreStorage().msgInspector;
    }

    function setMsgInspector(address _inspector) public virtual onlyOwner {
        _getOFTCoreStorage().msgInspector = _inspector;
        emit MsgInspectorSet(_inspector);
    }

    // Leave _debit and _credit abstract
    function _debit(
        address from,
        uint256 amountLD,
        uint256 minAmountLD,
        uint32 dstEid
    ) internal virtual returns (uint256 amountSentLD, uint256 amountReceivedLD);

    function _credit(address to, uint256 amountLD, uint32 srcEid) internal virtual returns (uint256 amountReceivedLD);

    function _removeDust(uint256 _amountLD) internal view virtual returns (uint256 amountLD) {
        return (_amountLD / decimalConversionRate()) * decimalConversionRate();
    }

    function _toLD(uint64 amountSD) internal view virtual returns (uint256) {
        return amountSD * decimalConversionRate();
    }

    function _toSD(uint256 amountLD) internal view virtual returns (uint64) {
        return uint64(amountLD / decimalConversionRate());
    }

    function _debitView(
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 /*_dstEid*/
    ) internal view virtual returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        amountSentLD = _removeDust(_amountLD);
        amountReceivedLD = amountSentLD;
        if (amountReceivedLD < _minAmountLD) {
            revert("SlippageExceeded");
        }
    }
}
