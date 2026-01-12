// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {vUSD} from "../src/vUSD.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

contract DeployVUSD is Script {
    function run() external {
        vm.startBroadcast();

        // 1. Deploy Mock ERC20 tokens
        MockERC20 vETH = new MockERC20("Virtual ETH", "vETH");
        MockERC20 vDOT = new MockERC20("Virtual DOT", "vDOT");

        // 2. Deploy vUSD contract
        vUSD vusd = new vUSD();

        // 3. Configure vUSD
        // Set collateral ratio to 200% (2e18)
        vusd.setCollateralRatio(2e18);

        // Allow vETH and vDOT as collateral
        vusd.setAllowedCollateral(address(vETH), true);
        vusd.setAllowedCollateral(address(vDOT), true);

        // Set prices: vETH = $3000, vDOT = $2
        vusd.setCollateralPrice(address(vETH), 3000e18);
        vusd.setCollateralPrice(address(vDOT), 2e18);

        vm.stopBroadcast();

        // 4. Log all deployed addresses
        console.log("=== Deployment Complete ===");
        console.log("vETH deployed at:", address(vETH));
        console.log("vDOT deployed at:", address(vDOT));
        console.log("vUSD deployed at:", address(vusd));
        console.log("");
        console.log("=== Configuration ===");
        console.log("Collateral Ratio: 200%");
        console.log("vETH Price: $3000");
        console.log("vDOT Price: $2");
    }
}
