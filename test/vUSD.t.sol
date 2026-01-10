// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {vUSD} from "../src/vUSD.sol";

contract vUSDTest is Test {
    vUSD public token;

    address owner = address(this); // test contract deploys vUSD
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        token = new vUSD();
    }

    /*//////////////////////////////////////////////////////////////
                              MINT
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanMint() public {
        token.mint(alice, 1_000_000); // 1 vUSD (6 decimals)

        assertEq(token.balanceOf(alice), 1_000_000);
        assertEq(token.totalSupply(), 1_000_000);
    }

    function testNonOwnerCannotMint() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 1_000_000);
    }

    /*//////////////////////////////////////////////////////////////
                              BURN
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanBurn() public {
        token.mint(alice, 1_000_000);

        token.burn(alice, 400_000);

        assertEq(token.balanceOf(alice), 600_000);
        assertEq(token.totalSupply(), 600_000);
    }

    function testNonOwnerCannotBurn() public {
        token.mint(alice, 1_000_000);

        vm.prank(alice);
        vm.expectRevert();
        token.burn(alice, 100_000);
    }

    /*//////////////////////////////////////////////////////////////
                         COLLATERAL RATIO
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanSetCollateralRatio() public {
        uint256 newRatio = 1.5e18;

        vm.expectEmit(true, false, false, true);
        emit vUSD.CollateralRatioUpdated(0, newRatio); // old = 0 for first set

        token.setCollateralRatio(newRatio);

        assertEq(token.collateralRatio(), newRatio);
    }

    function testNonOwnerCannotSetCollateralRatio() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setCollateralRatio(1.2e18);
    }

    function testCollateralRatioCannotBeZero() public {
        vm.expectRevert(abi.encodeWithSelector(vUSD.InvalidCollateralRatio.selector, 0));
        token.setCollateralRatio(0);
    }

    /*//////////////////////////////////////////////////////////////
                         COLLATERAL PRICE
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanSetCollateralPrice() public {
        uint256 price = 2e18;

        vm.expectEmit(true, false, false, true);
        emit vUSD.CollateralPriceUpdated(address(bob), 0, price); // old = 0 for first set

        token.setCollateralPrice(address(bob), price);

        assertEq(token.collateralPrice(address(bob)), price);
    }

    function testNonOwnerCannotSetCollateralPrice() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setCollateralPrice(address(bob), 3e18);
    }

    function testCollateralPriceCannotBeZero() public {
        vm.expectRevert(abi.encodeWithSelector(vUSD.InvalidCollateralPrice.selector, 0));
        token.setCollateralPrice(address(bob), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        ALLOWED COLLATERAL
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanSetAllowedCollateral() public {
        vm.expectEmit(true, false, false, true);
        emit vUSD.AllowedCollateralUpdated(address(bob), false, true); // old = false

        token.setAllowedCollateral(address(bob), true);

        assertTrue(token.isAllowedCollateral(address(bob)));
    }

    function testNonOwnerCannotSetAllowedCollateral() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setAllowedCollateral(address(bob), true);
    }
}
