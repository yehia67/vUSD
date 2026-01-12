// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IvUSD.sol";

contract vUSD is ERC20, Ownable, ReentrancyGuard, IvUSD {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

  // Protocol config
    uint256 public constant MIN_COLLATERAL_RATIO = 1e18;
    uint256 public collateralRatio = 1e18;
    mapping(address => bool) public isAllowedCollateral;
    mapping(address => uint256) public collateralPrice;

    // User balances
    mapping(address => mapping(address => uint256)) public collateralBalances; // user -> asset -> amount
    mapping(address => mapping(address => uint256)) public debtBalances; // user -> asset -> vUSD minted

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() ERC20("vUSD Stablecoin", "vUSD") Ownable(msg.sender) {}

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
        if (newRatio < MIN_COLLATERAL_RATIO) {
            revert InvalidCollateralRatio(newRatio);
        }
    }

    function _validateCollateralPrice(uint256 price) internal pure {
        if (price == 0) revert InvalidCollateralPrice(price);
    }

    function _validateCollateral(address asset, uint256 amount) internal view {
        if (amount == 0) revert InvalidAmount(amount);
        if (!isAllowedCollateral[asset]) revert CollateralNotAllowed(asset);
    }

    function _validateCollateralUnlock(address asset, uint256 userCollateral, uint256 collateralAmount) internal pure {
        if (userCollateral < collateralAmount) {
            revert InsufficientCollateral(asset, userCollateral, collateralAmount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                       COLLATERAL & MINTING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Locks collateral and mints vUSD against it
     * @dev Transfers collateral from user to contract and mints maximum possible vUSD
     * @param asset The address of the collateral asset to lock
     * @param amount The amount of collateral to lock
     */
    function lockCollateral(address asset, uint256 amount) external {
        _validateCollateral(asset, amount);

        // Transfer the collateral from user to contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Track user collateral
        collateralBalances[msg.sender][asset] += amount;
        emit CollateralLocked(msg.sender, asset, amount);

        // Calculate max mintable vUSD
        uint256 price = collateralPrice[asset]; // 1e18

        uint256 collateralValueUsd = Math.mulDiv(amount, price, 1e18);
        uint256 maxMintable = Math.mulDiv(collateralValueUsd, 1e18, collateralRatio);

        // Mint vUSD to user
        _mint(msg.sender, maxMintable);
        debtBalances[msg.sender][asset] += maxMintable;

        emit vUSDMinted(msg.sender, asset, amount, collateralValueUsd, maxMintable);
    }

    /**
     * @notice Repays vUSD and unlocks collateral
     * @dev Burns vUSD and returns equivalent collateral to user
     * @param asset The address of the collateral asset to unlock
     * @param collateralAmount The amount of collateral to unlock
     */
    function unlockCollateral(address asset, uint256 collateralAmount) external nonReentrant {
        _validateCollateral(asset, collateralAmount);

        uint256 userCollateral = collateralBalances[msg.sender][asset];
        uint256 userDebt = debtBalances[msg.sender][asset];

        _validateCollateralUnlock(asset, userCollateral, collateralAmount);

        // Calculate how much vUSD needs to be burned to safely unlock given collateral
        uint256 price = collateralPrice[asset];
        uint256 ratio = collateralRatio;
        uint256 collateralValueUsd = Math.mulDiv(collateralAmount, price, 1e18);

        // Calculate how much vUSD needs to stay backed by remaining collateral
        uint256 remainingCollateral = userCollateral - collateralAmount;
        uint256 remainingCollateralValueUsd = Math.mulDiv(remainingCollateral, price, 1e18);
        uint256 vUSDToKeep = Math.mulDiv(remainingCollateralValueUsd, 1e18, ratio);

        vUSDToKeep = Math.min(vUSDToKeep, userDebt); // capped by remaining debt
        uint256 vUSDToBurn = userDebt - vUSDToKeep;

        // If no vUSD needs to be burned, return collateral and return.
        if (vUSDToBurn == 0) {
            collateralBalances[msg.sender][asset] -= collateralAmount;

            IERC20(asset).safeTransfer(msg.sender, collateralAmount);
            emit CollateralUnlocked(msg.sender, asset, collateralAmount);
            return;
        }

        // Check Available vUSD to burn
        uint256 userBalance = balanceOf(msg.sender);
        if (userBalance < vUSDToBurn) {
            revert InsufficientVUSDBalance(vUSDToBurn, balanceOf(msg.sender));
        }

        // Burn vUSD from user
        _burn(msg.sender, vUSDToBurn);
        debtBalances[msg.sender][asset] -= vUSDToBurn;
        emit vUSDBurned(msg.sender, asset, collateralAmount, collateralValueUsd, vUSDToBurn);

        // Update collateral balance
        collateralBalances[msg.sender][asset] -= collateralAmount;

        // Transfer collateral back to user
        IERC20(asset).safeTransfer(msg.sender, collateralAmount);
        emit CollateralUnlocked(msg.sender, asset, collateralAmount);
    }
}
