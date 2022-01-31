// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./BaseStrategy.sol";

abstract contract BaseStrategyLP is BaseStrategy {
    using SafeERC20 for IERC20;

    function convertDustToGained() external nonReentrant whenNotPaused {
        // Converts dust tokens into gained tokens, which will be reinvested on the next earn().

        // Converts token0 dust (if any) to gained tokens
        uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));
        if (token0Amt > 0 && token0Address != gainedAddress) {
            // Swap all dust tokens to gained tokens
            _safeSwap(
                token0Amt,
                token0ToGainedPath,
                address(this)
            );
        }

        // Converts token1 dust (if any) to gained tokens
        uint256 token1Amt = IERC20(token1Address).balanceOf(address(this));
        if (token1Amt > 0 && token1Address != gainedAddress) {
            // Swap all dust tokens to gained tokens
            _safeSwap(
                token1Amt,
                token1ToGainedPath,
                address(this)
            );
        }
    }
}