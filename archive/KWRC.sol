// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { OFTUpgradeable } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTUpgradeable.sol";
import { OFTCore } from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { TransferLimiter, TransferLimit } from "contracts/KRWC/TransferLimiter.sol";
import { IFeeManager } from "contracts/interfaces/IFeeManager.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract KWRC is TransferLimiter, AccessControl, Ownable, OFT, Pausable, OFTUpgradeable, OwnableUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    address public feeManager;
    address public feeCollector;

    // Transfer/Mint/Burn fee state (basis points, e.g. 100 = 1%)
    uint256 public feeRate;
    uint256 public mintFee;
    uint256 public burnFee;

    // Oracle for Proof of Reserve (PoR)
    address public reserveOracle;

    // Events
    event MintFeePaid(address indexed minter, uint256 fee);
    event BurnFeePaid(address indexed burner, uint256 fee);
    event ReserveOracleUpdated(address indexed newOracle);
    event MintFeeUpdated(uint256 newFee);
    event BurnFeeUpdated(uint256 newFee);
    event FeeCollectorUpdated(address indexed newCollector);

    // Modifier for PoR check (placeholder logic)
    modifier onlyIfReserveSufficient(uint256 /*amount*/) {
        // TODO: Integrate actual PoR oracle logic here
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address lzEndpoint,
        address delegate_,
        address feeManager_,
        uint256 feeRate_,
        TransferLimit[] memory limitConfigs,
        address admin_,
        address owner_,
        uint256 mintFee_,
        uint256 burnFee_,
        address feeCollector_,
        address reserveOracle_
    ) OFT(name_, symbol_, lzEndpoint, delegate_) Ownable(owner_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);
        _grantRole(MINTER_ROLE, admin_);
        _grantRole(BURNER_ROLE, admin_);

        feeManager = feeManager_;
        feeRate = feeRate_;
        mintFee = mintFee_;
        burnFee = burnFee_;
        feeCollector = feeCollector_;
        reserveOracle = reserveOracle_;

        _setTransferLimitConfigs(limitConfigs);
    }

    function initialize(string memory name, string memory symbol, address lzEndpoint) public initializer {
        __OFTUpgradeable_init(name, symbol, lzEndpoint);
        __Ownable_init();
    }

    // Setters (admin only)
    function setMintFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        mintFee = newFee;
        emit MintFeeUpdated(newFee);
    }
    function setBurnFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        burnFee = newFee;
        emit BurnFeeUpdated(newFee);
    }
    function setFeeCollector(address newCollector) external onlyRole(ADMIN_ROLE) {
        feeCollector = newCollector;
        emit FeeCollectorUpdated(newCollector);
    }
    function setReserveOracle(address newOracle) external onlyRole(ADMIN_ROLE) {
        reserveOracle = newOracle;
        emit ReserveOracleUpdated(newOracle);
    }

    // Mint function: only MINTER_ROLE, with fee and PoR check
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) onlyIfReserveSufficient(amount) {
        uint256 fee = (amount * mintFee) / 10_000;
        if (fee > 0 && feeCollector != address(0)) {
            _mint(feeCollector, fee);
            emit MintFeePaid(msg.sender, fee);
        }
        _mint(to, amount - fee);
    }

    // Burn function: only MINTER_ROLE, with fee and PoR check
    function burn(address from, uint256 amount) public onlyRole(MINTER_ROLE) onlyIfReserveSufficient(amount) {
        uint256 fee = (amount * burnFee) / 10_000;
        if (fee > 0 && feeCollector != address(0)) {
            _transfer(from, feeCollector, fee);
            emit BurnFeePaid(msg.sender, fee);
        }
        _burn(from, amount - fee);
    }

    // Pause function: only ADMIN_ROLE
    function pause() public onlyRole(ADMIN_ROLE) {
        _pause();
    }

    // Unpause function: only ADMIN_ROLE
    function unpause() public onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // Override _update to include pause check and fee logic
    function _update(address from, address to, uint256 value) internal override {
        require(!paused(), "Pausable: token transfer while paused");
        uint256 fee = (value * feeRate) / 10_000;
        uint256 valueAfterFee = value - fee;

        if (fee > 0 && feeManager != address(0)) {
            require(IFeeManager(feeManager).handleFee(from, fee) == fee, "fee mismatch");
        }

        super._update(from, to, valueAfterFee);
    }

    function _removeDust(uint256 amount) internal pure override(OFTCore, TransferLimiter) returns (uint256) {
        return amount;
    }

    function _debit(
        address from,
        uint256 amountLD,
        uint256 minAmountLD,
        uint32 dstEid
    ) internal override returns (uint256, uint256) {
        uint256 cleaned = _removeDust(amountLD);
        _checkAndUpdateTransferLimit(dstEid, cleaned, from);
        return super._debit(from, amountLD, minAmountLD, dstEid);
    }
}
