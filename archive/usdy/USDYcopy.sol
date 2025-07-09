// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "contracts/archive/BlocklistClientUpgradeable.sol";
import "contracts/archive/AllowlistClientUpgradeable.sol";
import "contracts/archive/SanctionsListClientUpgradeable.sol";

contract KRWC is
    Initializable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    BlocklistClientUpgradeable,
    AllowlistClientUpgradeable,
    SanctionsListClientUpgradeable
{
    bytes32 public constant LIST_CONFIGURER_ROLE = keccak256("LIST_CONFIGURER_ROLE");
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

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address blocklist,
        address allowlist,
        address sanctionsList
    ) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        // __ERC165_init();
        __BlocklistClientInitializable_init(blocklist);
        __AllowlistClientInitializable_init(allowlist);
        __SanctionsListClientInitializable_init(sanctionsList);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIST_CONFIGURER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    // function supportsInterface(
    //     bytes4 interfaceId
    // ) public view override(AccessControlUpgradeable, ERC165Upgradeable) returns (bool) {
    //     return super.supportsInterface(interfaceId);
    // }

    function setBlocklist(address blocklist) external override onlyRole(LIST_CONFIGURER_ROLE) {
        _setBlocklist(blocklist);
    }

    function setAllowlist(address allowlist) external override onlyRole(LIST_CONFIGURER_ROLE) {
        _setAllowlist(allowlist);
    }

    function setSanctionsList(address sanctionsList) external override onlyRole(LIST_CONFIGURER_ROLE) {
        _setSanctionsList(sanctionsList);
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

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) onlyIfReserveSufficient(amount) {
        uint256 fee = (amount * mintFee) / 10_000;
        if (fee > 0 && feeCollector != address(0)) {
            _mint(feeCollector, fee);
            emit MintFeePaid(msg.sender, fee);
        }
        _mint(to, amount - fee);
    }

    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) onlyIfReserveSufficient(amount) {
        uint256 fee = (amount * burnFee) / 10_000;
        if (fee > 0 && feeCollector != address(0)) {
            _transfer(from, feeCollector, fee);
            emit BurnFeePaid(msg.sender, fee);
        }
        _burn(from, amount - fee);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);

        if (from != msg.sender && to != msg.sender) {
            require(!_isBlocked(msg.sender), "KRWC: 'sender' address blocked");
            require(!_isSanctioned(msg.sender), "KRWC: 'sender' address sanctioned");
            require(_isAllowed(msg.sender), "KRWC: 'sender' address not on allowlist");
        }

        if (from != address(0)) {
            require(!_isBlocked(from), "KRWC: 'from' address blocked");
            require(!_isSanctioned(from), "KRWC: 'from' address sanctioned");
            require(_isAllowed(from), "KRWC: 'from' address not on allowlist");
        }

        if (to != address(0)) {
            require(!_isBlocked(to), "KRWC: 'to' address blocked");
            require(!_isSanctioned(to), "KRWC: 'to' address sanctioned");
            require(_isAllowed(to), "KRWC: 'to' address not on allowlist");
        }
    }

    function burnFrom(address account, uint256 amount) public override onlyRole(BURNER_ROLE) {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function isPaused() external view returns (bool) {
        return paused();
    }

    function isFrozen(address account) external view returns (bool) {
        return _isBlocked(account) || _isSanctioned(account) || !_isAllowed(account);
    }

    function grantRole(bytes32 role, address account) public override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    // function _removeDust(uint256 amount) internal pure override(OFTCore, TransferLimiter) returns (uint256) {
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
}
