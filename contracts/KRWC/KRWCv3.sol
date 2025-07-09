// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// import "contracts/oft/OFTUpgradeable.sol";
import "contracts/interfaces/IComplianceModule.sol";
import "contracts/interfaces/IFeeManager.sol";
import "contracts/compliance/ComplianceClientUpgradeable.sol";
import "contracts/KRWC/TransferLimiter.sol";

contract KRWC is
    Initializable,
    ERC20PermitUpgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    ERC165Upgradeable,
    AccessControlUpgradeable,
    ComplianceClientUpgradeable,
    TransferLimiter
{
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 public mintFee;
    uint256 public burnFee;
    address public feeCollector;
    address public feeManager;
    address public reserveOracle;

    event MintFeePaid(address indexed minter, uint256 fee);
    event BurnFeePaid(address indexed burner, uint256 fee);
    event MintFeeUpdated(uint256 newFee);
    event BurnFeeUpdated(uint256 newFee);
    event FeeCollectorUpdated(address indexed newCollector);
    event FeeManagerUpdated(address indexed newManager);
    event ReserveOracleUpdated(address indexed newOracle);

    // TODO PoR
    modifier onlyIfReserveSufficient(uint256 amount) {
        // require(reserveOracle != address(0), "No reserve oracle");
        // require(IReserveOracle(reserveOracle).isSufficient(amount), "Insufficient reserve");
        _;
    }

    function initialize(string memory name, string memory symbol, address complianceModule) public initializer {
        // __OFTUpgradeable_init(name, symbol, 18, lzEndpoint, msg.sender);
        __ERC20_init(name, symbol);
        __ERC165_init();
        __ERC20Permit_init(name);
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __ComplianceClient_init(complianceModule);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    // ERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControlUpgradeable, ERC165Upgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // grantRole (optional)
    // function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
    //     _grantRole(role, account);
    // }

    // Transfers
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(_isCompliant(msg.sender), "KRWC: sender not compliant");
        require(_isCompliant(to), "KRWC: recipient not compliant");
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(_isCompliant(from), "KRWC: sender not compliant");
        require(_isCompliant(to), "KRWC: recipient not compliant");
        return super.transferFrom(from, to, amount);
    }

    // Mint & Burn
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) onlyIfReserveSufficient(amount) {
        require(_isCompliant(to), "KRWC: recipient not compliant");

        uint256 fee = (amount * mintFee) / 10_000;
        uint256 netAmount = amount - fee;

        if (fee > 0 && address(feeManager) != address(0)) {
            uint256 actualFeeHandled = IFeeManager(feeManager).handleMintFee(msg.sender, fee);
            require(actualFeeHandled == fee, "KRWC: mint fee mismatch");
            emit MintFeePaid(msg.sender, fee);
        }

        _mint(to, netAmount);
    }

    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) onlyIfReserveSufficient(amount) {
        require(_isCompliant(from), "KRWC: account not compliant");

        uint256 fee = (amount * burnFee) / 10_000;
        uint256 netAmount = amount - fee;

        if (fee > 0 && address(feeManager) != address(0)) {
            uint256 actualFeeHandled = IFeeManager(feeManager).handleBurnFee(from, fee);
            require(actualFeeHandled == fee, "KRWC: burn fee mismatch");
            emit BurnFeePaid(msg.sender, fee);
        }

        _burn(from, netAmount);
    }

    /**
     * @notice Burn tokens on behalf of another account, using allowance
     * @dev Only accounts with BURNER_ROLE can call this
     * The account must have approved enough allowance to msg.sender
     */
    // function burnFrom(address account, uint256 amount) public override onlyRole(BURNER_ROLE) {
    //     _spendAllowance(account, msg.sender, amount);
    //     _burn(account, amount);
    // }

    // Pause Control
    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
    }

    function isPaused() external view returns (bool) {
        return paused();
    }

    function isFrozen(address account) external view returns (bool) {
        return !_isCompliant(account);
    }

    // Fee & Oracle setters
    function setMintFee(uint256 newFee) external onlyRole(OPERATOR_ROLE) {
        mintFee = newFee;
        emit MintFeeUpdated(newFee);
    }

    function setBurnFee(uint256 newFee) external onlyRole(OPERATOR_ROLE) {
        burnFee = newFee;
        emit BurnFeeUpdated(newFee);
    }

    function setFeeCollector(address newCollector) external onlyRole(OPERATOR_ROLE) {
        feeCollector = newCollector;
        emit FeeCollectorUpdated(newCollector);
    }

    function setFeeManager(address newManager) external onlyRole(OPERATOR_ROLE) {
        feeManager = newManager;
        emit FeeManagerUpdated(newManager);
    }

    function setReserveOracle(address newOracle) external onlyRole(OPERATOR_ROLE) {
        reserveOracle = newOracle;
        emit ReserveOracleUpdated(newOracle);
    }

    // LayerZero + TransferLimiter
    // function _removeDust(uint256 amount) internal view override(OFTCoreUpgradeable, TransferLimiter) returns (uint256) {
    //     return amount;
    // }

    // function _debit(
    //     address from,
    //     uint256 amountLD,
    //     uint256 minAmountLD,
    //     uint32 dstEid
    // ) internal override returns (uint256, uint256) {
    //     uint256 cleaned = _removeDust(amountLD);
    //     _checkAndUpdateTransferLimit(dstEid, cleaned, from);
    //     return super._debit(from, amountLD, minAmountLD, dstEid);
    // }

    // Storage gap for future upgrades
    uint256[50] private __gap;

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        require(!paused(), "KRWC: token transfer while paused");
        super._update(from, to, value);
    }
}
