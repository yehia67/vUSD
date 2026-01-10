// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract vUSD is ERC20, Ownable {
    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    // Protocol config
    uint256 public collateralRatio; // 1e18 precision
    mapping(address => bool) public isAllowedCollateral;
    mapping(address => uint256) public collateralPrice;

    // User balances
    mapping(address => mapping(address => uint256)) public collateralBalances; // user -> asset -> amount
    mapping(address => uint256) public debt; // user -> vUSD minted

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event CollateralPriceUpdated(address indexed asset, uint256 oldPrice, uint256 newPrice);
    event AllowedCollateralUpdated(address indexed asset, bool oldAllowed, bool newAllowed);
    event CollateralLocked(address indexed user, address indexed asset, uint256 amount);
    event vUSDMinted(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                             CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidCollateralRatio(uint256 attempted);
    error InvalidCollateralPrice(uint256 attempted);
    error CollateralNotAllowed(address asset);
    error InvalidAmount(uint256 attempted);
    error TransferFailed(address from, address asset, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() ERC20("vUSD Stablecoin", "vUSD") Ownable(msg.sender) {}

    /// @notice Override decimals to 6 (USDC-style)
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /*//////////////////////////////////////////////////////////////
                            MINT / BURN
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint vUSD (only callable by owner / protocol)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Burn vUSD (only callable by owner / protocol)
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          PROTOCOL CONFIG
    //////////////////////////////////////////////////////////////*/

    function setCollateralRatio(uint256 newRatio) external onlyOwner {
        _validateCollateralRatio(newRatio);

        uint256 oldRatio = collateralRatio;
        collateralRatio = newRatio;
        emit CollateralRatioUpdated(oldRatio, newRatio);
    }

    function setCollateralPrice(address asset, uint256 price) external onlyOwner {
        _validateCollateralPrice(price);

        uint256 oldPrice = collateralPrice[asset];
        collateralPrice[asset] = price;
        emit CollateralPriceUpdated(asset, oldPrice, price);
    }

    function setAllowedCollateral(address asset, bool allowed) external onlyOwner {
        bool oldAllowed = isAllowedCollateral[asset];
        isAllowedCollateral[asset] = allowed;
        emit AllowedCollateralUpdated(asset, oldAllowed, allowed);
    }

    /*//////////////////////////////////////////////////////////////
                     INPUT VALIDATION (INTERNAL)
    //////////////////////////////////////////////////////////////*/

    function _validateCollateralRatio(uint256 newRatio) internal pure {
        if (newRatio == 0) revert InvalidCollateralRatio(newRatio);
    }

    function _validateCollateralPrice(uint256 price) internal pure {
        if (price == 0) revert InvalidCollateralPrice(price);
    }

    /*//////////////////////////////////////////////////////////////
                       COLLATERAL & MINTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Lock collateral and mint vUSD
    function lockCollateral(address asset, uint256 amount) external {
        if (amount == 0) revert InvalidAmount(amount);
        if (!isAllowedCollateral[asset]) revert CollateralNotAllowed(asset);

        // Transfer the collateral from user to contract
        bool success = ERC20(asset).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed(msg.sender, asset, amount);

        // Track user collateral
        collateralBalances[msg.sender][asset] += amount;
        emit CollateralLocked(msg.sender, asset, amount);

        // Calculate max mintable vUSD
        uint256 price = collateralPrice[asset]; // 1e18
        uint256 ratio = collateralRatio; // 1e18

        uint256 collateralValue = (amount * price) / 1e18;
        uint256 maxMintable = (collateralValue * 1e18) / ratio;

        // Mint vUSD to user
        _mint(msg.sender, maxMintable);
        debt[msg.sender] += maxMintable;

        emit vUSDMinted(msg.sender, maxMintable);
    }
}
