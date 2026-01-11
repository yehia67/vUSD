// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {vUSD} from "../src/vUSD.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FailingERC20 is ERC20 {
    constructor() ERC20("FailToken", "FAIL") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // Override transferFrom to always fail
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert("TRANSFER_FAILED");
    }
}

contract vUSDCollateralTest is Test {
    vUSD public token;

    MockERC20 public vETH;
    MockERC20 public vDOT;

    address alice = address(0xA11CE);

    function setUp() public {
        token = new vUSD();

        vETH = new MockERC20("vETH", "vETH");
        vDOT = new MockERC20("vDOT", "vDOT");

        vETH.mint(alice, 1_000_000e18);
        vDOT.mint(alice, 1_000_000e18);
    }

    /*//////////////////////////////////////////////////////////////
                        TEST HELPERS
    //////////////////////////////////////////////////////////////*/

    function _setupCollateral(address asset, uint256 price) internal {
        token.setAllowedCollateral(asset, true);
        token.setCollateralPrice(asset, price);
        token.setCollateralRatio(2e18); // 2:1
    }

    function _testLockCollateralSuccess(MockERC20 collateral, uint256 price) internal {
        _setupCollateral(address(collateral), price);

        uint256 depositAmount = 10e18;

        vm.startPrank(alice);
        collateral.approve(address(token), depositAmount);

        vm.expectEmit(true, true, false, true);
        emit vUSD.CollateralLocked(alice, address(collateral), depositAmount);

        uint256 collateralValueUsd = Math.mulDiv(depositAmount, price, 1e18);
        uint256 expectedMint = Math.mulDiv(collateralValueUsd, 1e18, 2e18);

        vm.expectEmit(true, false, false, true);
        emit vUSD.vUSDMinted(alice, address(collateral), depositAmount, collateralValueUsd, expectedMint);

        token.lockCollateral(address(collateral), depositAmount);
        vm.stopPrank();

        assertEq(token.debtBalances(alice, address(collateral)), expectedMint);
        assertEq(token.balanceOf(alice), expectedMint);
    }

    function _testUnlockCollateralFull(MockERC20 collateral, uint256 price) internal {
        _setupCollateral(address(collateral), price);
        uint256 depositAmount = 1e18;

        vm.startPrank(address(alice));
        collateral.approve(address(token), depositAmount);
        token.lockCollateral(address(collateral), depositAmount);

        uint256 finalCollateralBalance = collateral.balanceOf(address(alice)) + depositAmount;

        // Calculate collateral value and expected burn
        uint256 collateralValueUsd = Math.mulDiv(depositAmount, price, 1e18);
        uint256 expectedBurn = Math.mulDiv(collateralValueUsd, 1e18, 2e18);

        // Expect events
        vm.expectEmit(true, true, true, true);
        emit vUSD.vUSDBurned(address(alice), address(collateral), depositAmount, collateralValueUsd, expectedBurn);

        vm.expectEmit(true, true, true, true);
        emit vUSD.CollateralUnlocked(address(alice), address(collateral), depositAmount);

        token.unlockCollateral(address(collateral), depositAmount);
        vm.stopPrank();

        // Check final state
        assertEq(token.collateralBalances(address(alice), address(collateral)), 0);
        assertEq(token.debtBalances(address(alice), address(collateral)), 0);
        assertEq(token.balanceOf(address(alice)), 0);
        assertEq(collateral.balanceOf(address(alice)), finalCollateralBalance);
    }

    function _testUnlockCollateralPartial(MockERC20 collateral, uint256 price) internal {
        _setupCollateral(address(collateral), price);

        uint256 depositAmount = 10e18;

        vm.startPrank(address(alice));
        collateral.approve(address(token), depositAmount);
        token.lockCollateral(address(collateral), depositAmount);
        uint256 initialDebt = token.balanceOf(address(alice));

        uint256 unlockAmount = 4e18;

        uint256 collateralValueUsd = Math.mulDiv(unlockAmount, price, 1e18);
        uint256 expectedBurn = Math.mulDiv(collateralValueUsd, 1e18, 2e18);
        expectedBurn = Math.min(expectedBurn, initialDebt);

        // Expect events
        vm.expectEmit(true, false, false, true);
        emit vUSD.vUSDBurned(address(alice), address(collateral), unlockAmount, collateralValueUsd, expectedBurn);

        vm.expectEmit(true, true, false, true);
        emit vUSD.CollateralUnlocked(address(alice), address(collateral), unlockAmount);

        token.unlockCollateral(address(collateral), unlockAmount);
        vm.stopPrank();

        // Check final state
        assertEq(token.debtBalances(address(alice), address(collateral)), initialDebt - expectedBurn);
        assertEq(token.balanceOf(address(alice)), initialDebt - expectedBurn);
        assertEq(token.collateralBalances(address(alice), address(collateral)), depositAmount - unlockAmount);
        assertEq(collateral.balanceOf(address(token)), depositAmount - unlockAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        vETH TESTS
    //////////////////////////////////////////////////////////////*/

    function testLockCollateralWithvETH() public {
        uint256 ethPrice = 2_000e18; // $2000
        _testLockCollateralSuccess(vETH, ethPrice);
    }

    function testUnlockFullCollateralWithvETH() public {
        _testUnlockCollateralFull(vETH, 2_000e18);
    }

    function testUnlockPartialCollateralWithvETH() public {
        _testUnlockCollateralPartial(vETH, 2_000e18);
    }

    /*//////////////////////////////////////////////////////////////
                        vDOT TESTS
    //////////////////////////////////////////////////////////////*/

    function testLockCollateralWithvDOT() public {
        uint256 dotPrice = 5e17; // $0.5
        _testLockCollateralSuccess(vDOT, dotPrice);
    }

    function testUnlockFullCollateralWithvDOT() public {
        _testUnlockCollateralFull(vDOT, 5e17);
    }

    function testUnlockPartialCollateralWithvDOT() public {
        _testUnlockCollateralPartial(vDOT, 5e17);
    }

    /*//////////////////////////////////////////////////////////////
                    FAILURE / Additional Tests
    //////////////////////////////////////////////////////////////*/

    function testLockCollateralFailsForZeroAmount() public {
        _setupCollateral(address(vETH), 2_000e18);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(vUSD.InvalidAmount.selector, 0));
        token.lockCollateral(address(vETH), 0);
        vm.stopPrank();
    }

    function testLockCollateralFailsForUnallowedAsset() public {
        uint256 depositAmount = 100e18;

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(vUSD.CollateralNotAllowed.selector, address(vETH)));
        token.lockCollateral(address(vETH), depositAmount);
        vm.stopPrank();
    }

    function testLockCollateralTransferFails() public {
        FailingERC20 failToken = new FailingERC20();

        _setupCollateral(address(failToken), 1e18);

        uint256 depositAmount = 100e18;

        vm.startPrank(alice);
        failToken.mint(alice, depositAmount);
        failToken.approve(address(token), depositAmount);

        vm.expectRevert();
        token.lockCollateral(address(failToken), depositAmount);
        vm.stopPrank();
    }

    function testDifferentPricesProduceDifferentDebt() public {
        _setupCollateral(address(vETH), 2_000e18);
        _setupCollateral(address(vDOT), 5e17); // $0.5

        uint256 amount = 1e18;

        vm.startPrank(alice);

        vETH.approve(address(token), amount);
        token.lockCollateral(address(vETH), amount);
        uint256 ethDebt = token.debtBalances(alice, address(vETH));

        vDOT.approve(address(token), amount);
        token.lockCollateral(address(vDOT), amount);
        uint256 dotDebt = token.debtBalances(alice, address(vDOT));

        vm.stopPrank();

        assertGt(ethDebt, dotDebt);
    }

    function testUnlockCollateralFailsForZeroAmount() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(vUSD.InvalidAmount.selector, 0));
        token.unlockCollateral(address(vETH), 0);
        vm.stopPrank();
    }

    function testUnlockCollateralFailsForTooMuch() public {
        token.setAllowedCollateral(address(vETH), true);
        token.setCollateralPrice(address(vETH), 1e18);
        token.setCollateralRatio(2e18);

        uint256 depositAmount = 500e18;

        vm.startPrank(alice);
        vETH.approve(address(token), depositAmount);
        token.lockCollateral(address(vETH), depositAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                vUSD.InsufficientCollateral.selector, address(vETH), depositAmount, depositAmount + 1
            )
        );
        token.unlockCollateral(address(vETH), depositAmount + 1);
        vm.stopPrank();
    }

    function testUnlockCollateralFailsIfInsufficientVUSDBalance() public {
        _setupCollateral(address(vETH), 2_000e18);

        uint256 depositAmount = 10e18;

        vm.startPrank(alice);
        vETH.approve(address(token), depositAmount);
        token.lockCollateral(address(vETH), depositAmount);

        uint256 minted = token.balanceOf(alice);

        // Transfer all vUSD away so burn fails
        require(token.transfer(address(0xB0B), minted), "Transfer failed");

        uint256 unlockAmount = 5e18;
        uint256 expectedBurn =
            Math.mulDiv(Math.mulDiv(unlockAmount, token.collateralPrice(address(vETH)), 1e18), 1e18, 2e18);

        vm.expectRevert(abi.encodeWithSelector(vUSD.InsufficientVUSDBalance.selector, expectedBurn, 0));
        token.unlockCollateral(address(vETH), unlockAmount);
        vm.stopPrank();

        // Ensure state unchanged
        assertEq(token.collateralBalances(alice, address(vETH)), depositAmount);
        assertEq(vETH.balanceOf(address(token)), depositAmount);
        assertEq(token.debtBalances(alice, address(vETH)), minted);
        assertEq(token.balanceOf(alice), 0);
    }
}
