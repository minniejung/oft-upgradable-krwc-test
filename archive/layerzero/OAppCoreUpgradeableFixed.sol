// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IOAppCore, ILayerZeroEndpointV2 } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";

/**
 * @title OAppCoreUpgradeableFixed
 * @dev 프록시 업그레이더블 호환을 위해 수정된 버전 (immutable 제거)
 */
abstract contract OAppCoreUpgradeableFixed is IOAppCore, OwnableUpgradeable {
    struct OAppCoreStorage {
        mapping(uint32 => bytes32) peers;
        address endpoint; // 기존 immutable → storage로 변경
    }

    // keccak256(abi.encode(uint256(keccak256("layerzerov2.storage.oappcore")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OAPP_CORE_STORAGE_LOCATION =
        0x72ab1bc1039b79dc4724ffca13de82c96834302d3c7e0d4252232d4b2dd8f900;

    function _getOAppCoreStorage() internal pure returns (OAppCoreStorage storage $) {
        assembly {
            $.slot := OAPP_CORE_STORAGE_LOCATION
        }
    }

    function getEndpoint() public view returns (ILayerZeroEndpointV2) {
        return ILayerZeroEndpointV2(_getOAppCoreStorage().endpoint);
    }

    function __OAppCore_init(address _delegate, address _endpoint) internal onlyInitializing {
        __OAppCore_init_unchained(_delegate, _endpoint);
    }

    function __OAppCore_init_unchained(address _delegate, address _endpoint) internal onlyInitializing {
        if (_delegate == address(0)) revert InvalidDelegate();
        if (_endpoint == address(0)) revert(); // optional
        _getOAppCoreStorage().endpoint = _endpoint;
        ILayerZeroEndpointV2(_endpoint).setDelegate(_delegate);
    }

    function peers(uint32 _eid) public view override returns (bytes32) {
        return _getOAppCoreStorage().peers[_eid];
    }

    function setPeer(uint32 _eid, bytes32 _peer) public virtual onlyOwner {
        _getOAppCoreStorage().peers[_eid] = _peer;
        emit PeerSet(_eid, _peer);
    }

    function _getPeerOrRevert(uint32 _eid) internal view virtual returns (bytes32) {
        bytes32 peer = _getOAppCoreStorage().peers[_eid];
        if (peer == bytes32(0)) revert NoPeer(_eid);
        return peer;
    }

    function setDelegate(address _delegate) public onlyOwner {
        ILayerZeroEndpointV2(getEndpoint()).setDelegate(_delegate);
    }
}
