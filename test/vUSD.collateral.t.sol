// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {vUSD} from "../src/vUSD.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FailingERC20 is ERC20 {
    constructor() ERC20("FailToken", "FAIL") {}

    // Allow minting for tests
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // Override transferFrom to always fail
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        return false; // always fail
    }
}

contract vUSDCollateralTest is Test {
    vUSD public token;
    MockERC20 public dai;

    address owner = address(this); // test contract deploys vUSD
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        token = new vUSD();

        // Deploy mock ERC20 collateral
        dai = new MockERC20("DAI", "DAI");

        // Give alice some DAI
        dai.mint(alice, 1_000_000e18); // 1 million DAI with 18 decimals
    }

    /*//////////////////////////////////////////////////////////////
                          LOCK COLLATERAL
    //////////////////////////////////////////////////////////////*/

    function testLockCollateralSuccess() public {
        // Set up protocol config
        token.setAllowedCollateral(address(dai), true);
        token.setCollateralPrice(address(dai), 1e18); // $1 per token
        token.setCollateralRatio(2e18); // 2:1 ratio

        uint256 depositAmount = 500e18; // 500 DAI

        // Alice approves the vUSD contract
        vm.startPrank(alice);
        dai.approve(address(token), depositAmount);

        // Expect events
        vm.expectEmit(true, true, false, true);
        emit vUSD.CollateralLocked(alice, address(dai), depositAmount);

        uint256 collateralValue = (depositAmount * 1e18) / 1e18;
        uint256 maxMintable = (collateralValue * 1e18) / 2e18;

        vm.expectEmit(true, false, false, true);
        emit vUSD.vUSDMinted(alice, maxMintable);

        // Lock collateral and mint
        token.lockCollateral(address(dai), depositAmount);
        vm.stopPrank();

        // Check balances
        assertEq(token.collateralBalances(alice, address(dai)), depositAmount);
        assertEq(token.debt(alice), maxMintable);
        assertEq(token.balanceOf(alice), maxMintable);

        // Check contract received collateral
        assertEq(dai.balanceOf(address(token)), depositAmount);
    }

    function testLockCollateralFailsForZeroAmount() public {
        token.setAllowedCollateral(address(dai), true);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(vUSD.InvalidAmount.selector, 0));
        token.lockCollateral(address(dai), 0);
        vm.stopPrank();
    }

    function testLockCollateralFailsForUnallowedAsset() public {
        // dai not added to allowed list of assets
        uint256 depositAmount = 100e18;
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(vUSD.CollateralNotAllowed.selector, address(dai)));
        token.lockCollateral(address(dai), depositAmount);
        vm.stopPrank();
    }

    function testLockCollateralTransferFails() public {
        FailingERC20 failToken = new FailingERC20();

        // Set protocol config to allow this asset
        token.setAllowedCollateral(address(failToken), true);
        token.setCollateralPrice(address(failToken), 1e18);
        token.setCollateralRatio(2e18);

        uint256 depositAmount = 100e18;

        vm.startPrank(alice);
        failToken.mint(alice, depositAmount);
        failToken.approve(address(token), depositAmount);

        // Expect TransferFailed custom error
        vm.expectRevert(abi.encodeWithSelector(vUSD.TransferFailed.selector, alice, address(failToken), depositAmount));
        token.lockCollateral(address(failToken), depositAmount);
        vm.stopPrank();
    }
}
