// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract vUSD is ERC20, Ownable {
    constructor() ERC20("vUSD Stablecoin", "vUSD") Ownable(msg.sender) {}

    /// @notice Override decimals to 6 (USDC-style)
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /*//////////////////////////////////////////////////////////////
                            MINT / BURN
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint vUSD (only callable by owner / protocol)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Burn vUSD (only callable by owner / protocol)
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
