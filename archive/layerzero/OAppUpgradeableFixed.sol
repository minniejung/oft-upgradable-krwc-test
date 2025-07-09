// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./OAppCoreUpgradeableFixed.sol";
import { OAppSenderUpgradeable, MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppSenderUpgradeable.sol";
import { OAppReceiverUpgradeable, Origin } from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppReceiverUpgradeable.sol";

abstract contract OAppUpgradeableFixed is OAppSenderUpgradeable, OAppReceiverUpgradeable, OAppCoreUpgradeableFixed {
    function __OApp_init(address delegate, address endpoint) internal onlyInitializing {
        __OAppCore_init(delegate, endpoint);
        __OAppReceiver_init_unchained();
        __OAppSender_init_unchained();
    }

    function __OApp_init_unchained() internal onlyInitializing {}

    function oAppVersion()
        public
        pure
        virtual
        override(OAppSenderUpgradeable, OAppReceiverUpgradeable)
        returns (uint64 senderVersion, uint64 receiverVersion)
    {
        return (SENDER_VERSION, RECEIVER_VERSION);
    }

    function _getOAppCoreStorage()
        internal
        pure
        override(OAppCoreUpgradeableFixed, OAppSenderUpgradeable, OAppReceiverUpgradeable)
        returns (OAppCoreUpgradeableFixed.OAppCoreStorage storage $)
    {
        return OAppCoreUpgradeableFixed._getOAppCoreStorage();
    }

    function _getPeerOrRevert(
        uint32 _eid
    )
        internal
        view
        override(OAppCoreUpgradeableFixed, OAppSenderUpgradeable, OAppReceiverUpgradeable)
        returns (bytes32)
    {
        return OAppCoreUpgradeableFixed._getPeerOrRevert(_eid);
    }

    function peers(
        uint32 _eid
    ) public view override(OAppCoreUpgradeableFixed, OAppSenderUpgradeable, OAppReceiverUpgradeable) returns (bytes32) {
        return OAppCoreUpgradeableFixed.peers(_eid);
    }

    function setDelegate(
        address _delegate
    ) public override(OAppCoreUpgradeableFixed, OAppSenderUpgradeable, OAppReceiverUpgradeable) {
        OAppCoreUpgradeableFixed.setDelegate(_delegate);
    }

    function setPeer(
        uint32 _eid,
        bytes32 _peer
    ) public override(OAppCoreUpgradeableFixed, OAppSenderUpgradeable, OAppReceiverUpgradeable) {
        OAppCoreUpgradeableFixed.setPeer(_eid, _peer);
    }
}
