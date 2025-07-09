// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "contracts/interfaces/IFeeManager.sol";

contract FeeManager is Initializable, OwnableUpgradeable, IFeeManager {
    address public lpReceiver;
    address public treasuryReceiver;
    address public token; // KRWC token address

    uint256 public lpShare; // e.g., 7000 = 70%
    uint256 public treasuryShare; // e.g., 3000 = 30%

    error InvalidSplit();
    error InvalidToken();
    error TransferFailed(string target);

    function initialize(address _token, address _lpReceiver, address _treasuryReceiver) public initializer {
        __Ownable_init(msg.sender);
        if (_lpReceiver == address(0) || _treasuryReceiver == address(0)) revert InvalidToken();

        token = _token;
        lpReceiver = _lpReceiver;
        treasuryReceiver = _treasuryReceiver;
        lpShare = 7000;
        treasuryShare = 3000;
    }

    modifier onlyToken() {
        require(msg.sender == token, "Only token can call");
        _;
    }

    function handleMintFee(address minter, uint256 feeAmount) external override onlyToken returns (uint256) {
        _distributeFee(minter, feeAmount);
        return feeAmount;
    }

    function handleBurnFee(address from, uint256 feeAmount) external override onlyToken returns (uint256) {
        _distributeFee(from, feeAmount);
        return feeAmount;
    }

    function _distributeFee(address from, uint256 amount) internal {
        if (lpShare + treasuryShare != 10_000) revert InvalidSplit();

        uint256 lpAmount = (amount * lpShare) / 10_000;
        uint256 treasuryAmount = amount - lpAmount;

        if (!IERC20(token).transferFrom(from, lpReceiver, lpAmount)) revert TransferFailed("lp");
        if (!IERC20(token).transferFrom(from, treasuryReceiver, treasuryAmount)) revert TransferFailed("treasury");
    }

    function updateReceivers(address _lp, address _treasury) external onlyOwner {
        if (_lp == address(0) || _treasury == address(0)) revert InvalidToken();
        lpReceiver = _lp;
        treasuryReceiver = _treasury;
    }

    function updateShares(uint256 _lpShare, uint256 _treasuryShare) external onlyOwner {
        if (_lpShare + _treasuryShare != 10_000) revert InvalidSplit();
        lpShare = _lpShare;
        treasuryShare = _treasuryShare;
    }

    function updateToken(address newToken) external onlyOwner {
        token = newToken;
    }
}
