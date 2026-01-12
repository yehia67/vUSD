// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {vUSD} from "../src/vUSD.sol";
import {IvUSD} from "../src/interfaces/IvUSD.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract VUSDMultiCollateralBehaviorTest is Test {
    vUSD internal token;
    MockERC20 internal vETH;
    MockERC20 internal vDOT;

    address internal alice = address(0xA11CE);

    function setUp() public {
        token = new vUSD();

        vETH = new MockERC20("vETH", "vETH");
        vDOT = new MockERC20("vDOT", "vDOT");

        // Protocol config
        token.setCollateralRatio(2e18);

        token.setAllowedCollateral(address(vETH), true);
        token.setAllowedCollateral(address(vDOT), true);

        token.setCollateralPrice(address(vETH), 2_000e18); // $2000
        token.setCollateralPrice(address(vDOT), 2e18); // $2

        // Fund Alice
        vETH.mint(alice, 1e18);
        vDOT.mint(alice, 1e18);
    }

    function testUnlockOneAssetDoesNotAffectOtherCollateral() public {
        vm.startPrank(alice);

        // Approvals
        vETH.approve(address(token), 1e18);
        vDOT.approve(address(token), 1e18);

        // Lock both assets
        token.lockCollateral(address(vETH), 1e18);
        token.lockCollateral(address(vDOT), 1e18);

        vm.stopPrank();

        /*
            Initial state:
            - vETH collateral = 1
            - vDOT collateral = 1
            - vETH debt = 1000
            - vDOT debt = 1
            - total vUSD balance = 1001
        */

        assertEq(token.collateralBalances(alice, address(vETH)), 1e18);
        assertEq(token.collateralBalances(alice, address(vDOT)), 1e18);

        uint256 vETHDebtBefore = token.debtBalances(alice, address(vETH));
        uint256 vDOTDebtBefore = token.debtBalances(alice, address(vDOT));
        uint256 vUSDBalanceBefore = token.balanceOf(alice);

        assertEq(vETHDebtBefore, 1_000e18);
        assertEq(vDOTDebtBefore, 1e18);
        assertEq(vUSDBalanceBefore, 1_001e18);

        // === Unlock 100% of vETH ===
        vm.startPrank(alice);
        token.unlockCollateral(address(vETH), 1e18);
        vm.stopPrank();

        // vETH collateral fully unlocked
        assertEq(token.collateralBalances(alice, address(vETH)), 0);

        // vDOT collateral MUST remain untouched
        assertEq(token.collateralBalances(alice, address(vDOT)), 1e18);

        // vETH debt must be fully burned
        assertEq(token.debtBalances(alice, address(vETH)), 0);

        // vDOT debt must remain unchanged
        assertEq(token.debtBalances(alice, address(vDOT)), vDOTDebtBefore);

        // vUSD balance decreased only by vETH-backed debt
        assertEq(token.balanceOf(alice), vUSDBalanceBefore - vETHDebtBefore);

        // Alice receives her vETH back
        assertEq(vETH.balanceOf(alice), 1e18);
    }

    function testPriceDropBeforeFullUnlock() public {
        uint256 lowPrice = 1_000e18; // $1000
        uint256 deposit = 1e18; // 1 vETH

        // Lock collateral at high price
        vm.startPrank(alice);
        vETH.approve(address(token), deposit);
        token.lockCollateral(address(vETH), deposit);
        vm.stopPrank();

        uint256 debtAfterMint = token.debtBalances(alice, address(vETH));
        uint256 vUSDBalance = token.balanceOf(alice);

        // Manipulate price downward
        token.setCollateralPrice(address(vETH), lowPrice);

        // Unlock everything
        vm.startPrank(alice);
        token.unlockCollateral(address(vETH), deposit);

        // Invariant checks
        assertEq(token.collateralBalances(alice, address(vETH)), 0);
        assertEq(token.debtBalances(alice, address(vETH)), 0);
        assertEq(token.balanceOf(alice), vUSDBalance - debtAfterMint);
    }

    function testPriceIncreaseBeforePartialUnlock() public {
        uint256 highPrice = 4_000e18; // $4000
        uint256 deposit = 1e18; // 1 vETH

        // Lock collateral at low price
        vm.startPrank(alice);
        vETH.approve(address(token), deposit);
        token.lockCollateral(address(vETH), deposit);
        vm.stopPrank();

        uint256 debtAfterMint = token.debtBalances(alice, address(vETH));

        // Manipulate price upward
        token.setCollateralPrice(address(vETH), highPrice);

        // Unlock half the collateral
        vm.startPrank(alice);
        token.unlockCollateral(address(vETH), deposit / 2);
        assertEq(token.collateralBalances(alice, address(vETH)), deposit / 2);

        // And no vUSD burn
        assertEq(token.debtBalances(alice, address(vETH)), debtAfterMint);
        assertEq(token.balanceOf(alice), debtAfterMint);
    }

    function _testUnlockCollateralAfterRatioIncrease() internal {
        // Lock collateral at initial ratio = 2
        uint256 depositAmount = 1e18;
        vm.startPrank(address(alice));
        vETH.approve(address(token), depositAmount);
        token.lockCollateral(address(vETH), depositAmount);
        vm.stopPrank();

        uint256 initialDebt = token.debtBalances(address(alice), address(vETH));
        uint256 initialCollateralBalance = vETH.balanceOf(address(alice));

        // Increase collateral ratio as owner
        token.setCollateralRatio(4e18);

        // Unlock half the collateral, but burn 3/4 of the vUSD as ratio has halved.
        uint256 halfCollateralAmount = depositAmount / 2;
        uint256 price = token.collateralPrice(address(vETH));

        // Calculate expected vUSD burn
        uint256 expectedKeep = initialDebt / 4; // only 1/4 can be kept with new ratio
        uint256 expectedBurn = initialDebt - expectedKeep;

        // Expect events
        vm.expectEmit(true, true, true, true);
        emit IvUSD.vUSDBurned(
            address(alice),
            address(vETH),
            halfCollateralAmount,
            Math.mulDiv(halfCollateralAmount, price, 1e18),
            expectedBurn
        );

        vm.expectEmit(true, true, false, true);
        emit IvUSD.CollateralUnlocked(address(alice), address(vETH), halfCollateralAmount);

        // Unlock collateral
        vm.startPrank(address(alice));
        token.unlockCollateral(address(vETH), halfCollateralAmount);
        vm.stopPrank();

        // Check updated state
        assertEq(token.collateralBalances(address(alice), address(vETH)), halfCollateralAmount);
        assertEq(vETH.balanceOf(address(alice)), initialCollateralBalance + halfCollateralAmount);
        assertEq(token.debtBalances(address(alice), address(vETH)), expectedKeep);
        assertEq(token.balanceOf(address(alice)), expectedKeep);
    }
}
