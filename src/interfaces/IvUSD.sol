// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title IvUSD
 * @dev Interface for the vUSD stablecoin contract
 * @notice Defines the external functions, events, and errors for the vUSD protocol
 */
interface IvUSD is IERC20 {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when the collateral ratio is updated
     * @param oldRatio The previous collateral ratio
     * @param newRatio The new collateral ratio
     */
    event CollateralRatioUpdated(uint256 oldRatio, uint256 newRatio);

    /**
     * @notice Emitted when the price of a collateral asset is updated
     * @param asset The address of the collateral asset
     * @param oldPrice The previous price
     * @param newPrice The new price
     */
    event CollateralPriceUpdated(address indexed asset, uint256 oldPrice, uint256 newPrice);

    /**
     * @notice Emitted when a collateral asset is allowed or disallowed
     * @param asset The address of the collateral asset
     * @param oldAllowed The previous allowed status
     * @param newAllowed The new allowed status
     */
    event AllowedCollateralUpdated(address indexed asset, bool oldAllowed, bool newAllowed);

    /**
     * @notice Emitted when collateral is locked by a user
     * @param user The address of the user locking collateral
     * @param asset The address of the collateral asset
     * @param amount The amount of collateral locked
     */
    event CollateralLocked(address indexed user, address indexed asset, uint256 amount);

    /**
     * @notice Emitted when vUSD is minted against collateral
     * @param user The address of the user receiving vUSD
     * @param asset The address of the collateral asset
     * @param collateralAmount The amount of collateral used
     * @param collateralUsdValue The USD value of the collateral
     * @param mintAmount The amount of vUSD minted
     */
    event vUSDMinted(
        address indexed user,
        address indexed asset,
        uint256 collateralAmount,
        uint256 collateralUsdValue,
        uint256 mintAmount
    );

    /**
     * @notice Emitted when collateral is unlocked and returned to a user
     * @param user The address of the user unlocking collateral
     * @param asset The address of the collateral asset
     * @param amount The amount of collateral unlocked
     */
    event CollateralUnlocked(address indexed user, address indexed asset, uint256 amount);

    /**
     * @notice Emitted when vUSD is burned and collateral is released
     * @param user The address of the user burning vUSD
     * @param asset The address of the collateral asset
     * @param collateralAmount The amount of collateral released
     * @param collateralUsdValue The USD value of the collateral released
     * @param burnedAmount The amount of vUSD burned
     */
    event vUSDBurned(
        address indexed user,
        address indexed asset,
        uint256 collateralAmount,
        uint256 collateralUsdValue,
        uint256 burnedAmount
    );

    /*//////////////////////////////////////////////////////////////
                             CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when an invalid collateral ratio is provided
     * @param attempted The attempted collateral ratio
     */
    error InvalidCollateralRatio(uint256 attempted);

    /**
     * @notice Thrown when an invalid collateral price is provided
     * @param attempted The attempted collateral price
     */
    error InvalidCollateralPrice(uint256 attempted);

    /**
     * @notice Thrown when a collateral asset is not allowed
     * @param asset The address of the disallowed collateral asset
     */
    error CollateralNotAllowed(address asset);

    /**
     * @notice Thrown when an invalid amount is provided
     * @param attempted The attempted amount
     */
    error InvalidAmount(uint256 attempted);

    /**
     * @notice Thrown when there is insufficient collateral
     * @param asset The address of the collateral asset
     * @param available The available amount
     * @param requested The requested amount
     */
    error InsufficientCollateral(address asset, uint256 available, uint256 requested);

    /**
     * @notice Thrown when there is insufficient vUSD balance
     * @param required The required amount
     * @param available The available amount
     */
    error InsufficientVUSDBalance(uint256 required, uint256 available);

    /*//////////////////////////////////////////////////////////////
                             CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The minimum collateral ratio (1:1, represented as 1e18)
     */
    function MIN_COLLATERAL_RATIO() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The current collateral ratio
     */
    function collateralRatio() external view returns (uint256);

    /**
     * @notice Mapping of allowed collateral assets
     * @param asset The address of the collateral asset
     * @return Whether the asset is allowed as collateral
     */
    function isAllowedCollateral(address asset) external view returns (bool);

    /**
     * @notice Mapping of collateral asset prices
     * @param asset The address of the collateral asset
     * @return The price of the asset (with 18 decimals)
     */
    function collateralPrice(address asset) external view returns (uint256);

    /**
     * @notice Mapping of user collateral balances
     * @param user The address of the user
     * @param asset The address of the collateral asset
     * @return The amount of collateral the user has locked
     */
    function collateralBalances(address user, address asset) external view returns (uint256);

    /**
     * @notice Mapping of user debt balances
     * @param user The address of the user
     * @param asset The address of the collateral asset
     * @return The amount of vUSD minted against the collateral
     */
    function debtBalances(address user, address asset) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                          PROTOCOL CONFIG
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the collateral ratio for the protocol
     * @dev Can only be called by the contract owner
     * @param newRatio The new collateral ratio (with 18 decimals)
     */
    function setCollateralRatio(uint256 newRatio) external;

    /**
     * @notice Sets the price for a collateral asset
     * @dev Can only be called by the contract owner
     * @param asset The address of the collateral asset
     * @param price The price of the asset (with 18 decimals)
     */
    function setCollateralPrice(address asset, uint256 price) external;

    /**
     * @notice Sets whether a collateral asset is allowed
     * @dev Can only be called by the contract owner
     * @param asset The address of the collateral asset
     * @param allowed Whether the asset should be allowed as collateral
     */
    function setAllowedCollateral(address asset, bool allowed) external;

    /*//////////////////////////////////////////////////////////////
                       COLLATERAL & MINTING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Locks collateral and mints vUSD against it
     * @dev Transfers collateral from user to contract and mints maximum possible vUSD
     * @param asset The address of the collateral asset to lock
     * @param amount The amount of collateral to lock
     */
    function lockCollateral(address asset, uint256 amount) external;

    /**
     * @notice Repays vUSD and unlocks collateral
     * @dev Burns vUSD and returns equivalent collateral to user
     * @param asset The address of the collateral asset to unlock
     * @param collateralAmount The amount of collateral to unlock
     */
    function unlockCollateral(address asset, uint256 collateralAmount) external;
}
