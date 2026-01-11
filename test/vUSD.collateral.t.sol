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

        assertEq(token.debt(alice), expectedMint);
        assertEq(token.balanceOf(alice), expectedMint);
    }

    /*//////////////////////////////////////////////////////////////
                        vETH TESTS
    //////////////////////////////////////////////////////////////*/

    function testLockCollateralWithvETH() public {
        uint256 ethPrice = 2_000e18; // $2000
        _testLockCollateralSuccess(vETH, ethPrice);
    }
    /*//////////////////////////////////////////////////////////////
                        vDOT TESTS
    //////////////////////////////////////////////////////////////*/

    function testLockCollateralWithvDOT() public {
        uint256 dotPrice = 5e17; // $0.5
        _testLockCollateralSuccess(vDOT, dotPrice);
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

        uint256 amount = 10e18;

        vm.startPrank(alice);

        vETH.approve(address(token), amount);
        token.lockCollateral(address(vETH), amount);
        uint256 ethDebt = token.debt(alice);

        vDOT.approve(address(token), amount);
        token.lockCollateral(address(vDOT), amount);
        uint256 dotDebt = token.debt(alice) - ethDebt;

        vm.stopPrank();

        assertGt(ethDebt, dotDebt);
    }
}
