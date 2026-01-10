// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {vUSD} from "../src/vUSD.sol";

contract DeployVUSD is Script {
    function run() external {
        vm.startBroadcast();
        new vUSD();
        vm.stopBroadcast();
    }
}
