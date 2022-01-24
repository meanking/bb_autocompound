// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/ISushiStake.sol";
import "../interfaces/IWETH.sol";

import "./BaseStrategyLP.sol";

contract StrategySushiSwap is BaseStrategyLP {
    using SafeERC20 for IERC20;

    uint256 public pid;
    address public constant sushiYieldAddress = 0x0769fd68dFb93167989C6f7254cd0D766Fb2841F;

    address public constant wmaticAddress = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    address[] public wmaticToBBankPath;
    address[] public wmaticToToken0Path;
    address[] public wmaticToToken1Path;

    constructor(
        address _vaultChefAddress,
        uint256 _pid,
        address _wantAddress,
        address _earnedAddress,
        address[] memory _earnedToWmaticPath,
        address[] memory _earnedToBBankPath,
        address[] memory _wmaticToBBankPath,
        address[] memory _earnedToToken0Path,
        address[] memory _earnedToToken1Path,
        address[] memory _wmaticToToken0Path,
        address[] memory _wmaticToToken1Path,
        address[] memory _token0ToEarnedPath,
        address[] memory _token1ToEarnedPath
    ) {
        govAddress = msg.sender;
        vaultChefAddress = _vaultChefAddress;

        wantAddress = _wantAddress;
        token0Address = IUniPair(wantAddress).token0();
        token1Address = IUniPair(wantAddress).token1();

        uniRouterAddress = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
        pid = _pid;
        earnedAddress = _earnedAddress;

        earnedToWmaticPath = _earnedToWmaticPath;
        earnedToBBankPath = _earnedToBBankPath;
        wmaticToBBankPath = _wmaticToBBankPath;
        earnedToToken0Path = _earnedToToken0Path;
        earnedToToken1Path = _earnedToToken1Path;
        wmaticToToken0Path = _wmaticToToken0Path;
        wmaticToToken1Path = _wmaticToToken1Path;
        token0ToEarnedPath = _token0ToEarnedPath;
        token1ToEarnedPath = _token1ToEarnedPath;

        transferOwnership(vaultChefAddress);

        _resetAllowances();
    }
    
    function _vaultDeposit(uint256 _amount) internal override {
        ISushiStake(sushiYieldAddress).deposit(pid, _amount, address(this));
    }

    function _vaultWithdraw(uint256 _amount) internal override {
        ISushiStake(sushiYieldAddress).withdraw(pid, _amount, address(this));
    }

    function earn() external override nonReentrant whenNotPaused onlyGov {
        // Harvest farm tokens
        ISushiStake(sushiYieldAddress).harvest(pid, address(this));
        
        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this));
        uint256 wmaticAmt = IERC20(wmaticAddress).balanceOf(address(this));

        if (earnedAmt > 0) {
            earnedAmt = distributeFees(earnedAmt, earnedAddress);
            earnedAmt = distributeRewards(earnedAmt, earnedAddress);
            earnedAmt = buyBack(earnedAmt, earnedAddress);

            if (earnedAddress != token0Address) {
                _safeSwap(
                    earnedAmt / 2,
                    earnedToToken0Path,
                    address(this)
                );
            }

            if (earnedAddress != token1Address) {
                _safeSwap(
                    earnedAmt / 2,
                    earnedToToken1Path,
                    address(this)
                );
            }
        }

        if (wmaticAmt > 0) {
            wmaticAmt = distributeFees(wmaticAmt, wmaticAddress);
            wmaticAmt = distributeRewards(wmaticAmt, wmaticAddress);
            wmaticAmt = buyBack(wmaticAmt, wmaticAddress);

            if (wmaticAddress != token0Address) {
                _safeSwap(
                    wmaticAmt / 2,
                    wmaticToToken1Path,
                    address(this)
                );
            }

            if (wmaticAddress != token1Address) {
                _safeSwap(
                    wmaticAmt / 2,
                    wmaticToToken1Path,
                    address(this)
                );
            }
        }
        
        if (earnedAmt > 0 || wmaticAmt > 0) {
            uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));
            uint256 token1Amt = IERC20(token1Address).balanceOf(address(this));
            if (token0Amt > 0 && token1Amt > 0) {
                IUniRouter02(uniRouterAddress).addLiquidity(
                    token0Address,
                    token1Address,
                    token0Amt,
                    token1Amt,
                    0,
                    0,
                    address(this),
                    block.timestamp
                );
            }

            lastEarnBlock = block.number;

            _farm();
        }
    }

    function distributeFees(uint256 _earnedAmt, address _earnedAddress) internal returns (uint256) {
        
    }

    function distributeRewards(uint256 _earnedAmt, address _earnedAddress) internal returns (uint256) {
        
    }   

    function buyBack(uint256 _earnedAmt, address _earnedAddress) internal returns (uint256) {

    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "TransferHelper::safeTransferETH: ETH transfer failed");
    }
}