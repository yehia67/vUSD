// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {vUSD} from "../src/vUSD.sol";

contract vUSDTest is Test {
    vUSD public token;

    address owner = address(this); // test contract deploys vUSD
    address alice = address(0xA11CE);

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
}
