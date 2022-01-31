// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/ISushiStake.sol";
import "../interfaces/IWETH.sol";

import "./BaseStrategyLP.sol";

contract StrategySushiSwap is BaseStrategyLP {
    using SafeERC20 for IERC20;

    /// @dev Pool id in Sushiswap
    uint256 public pid;
    /// @dev Sushi yield address in Polygon|Rinkeby
    address public constant sushiYieldAddress = 0x0769fd68dFb93167989C6f7254cd0D766Fb2841F;
    /// @dev Wmatic address in Polygon
    // address public constant wmaticAddress = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public constant wmaticAddress = 0xc778417E063141139Fce010982780140Aa0cD5Ab;

    /// @dev [wmatic, bbank] path
    address[] public wmaticToBBankPath;
    /// @dev [wmatic, token0] path
    address[] public wmaticToToken0Path;
    /// @dev [wmatic, token1] path
    address[] public wmaticToToken1Path;
    

    /// @param _vaultChefAddress VaultChef address
    /// @param _pid pool id in Sushiswap
    /// @param _wantAddress Want address
    /// @param _gainedAddress Gained address
    /// @param _gainedToWmaticPath Path for gained and wmatic
    /// @param _gainedToBBankPath Path for gained and bbank
    /// @param _wmaticToBBankPath Path for wmatic and bbank
    /// @param _gainedToToken0Path Path for gained and token0
    /// @param _gainedToToken1Path Path for gained and token1
    /// @param _wmaticToToken0Path Path for wmatic and token0
    /// @param _wmaticToToken1Path Path for wmatic and token1
    /// @dev Constructor function
    constructor(
        address _vaultChefAddress,
        uint256 _pid,
        address _wantAddress,
        address _gainedAddress,
        address[] memory _gainedToWmaticPath,
        address[] memory _gainedToBBankPath,
        address[] memory _wmaticToBBankPath,
        address[] memory _gainedToToken0Path,
        address[] memory _gainedToToken1Path,
        address[] memory _wmaticToToken0Path,
        address[] memory _wmaticToToken1Path
    ) {
        govAddress = msg.sender;
        vaultChefAddress = _vaultChefAddress;

        wantAddress = _wantAddress;
        token0Address = IUniPair(wantAddress).token0();
        token1Address = IUniPair(wantAddress).token1();

        uniRouterAddress = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
        pid = _pid;
        gainedAddress = _gainedAddress;

        gainedToWmaticPath = _gainedToWmaticPath;
        gainedToBBankPath = _gainedToBBankPath;
        wmaticToBBankPath = _wmaticToBBankPath;
        gainedToToken0Path = _gainedToToken0Path;
        gainedToToken1Path = _gainedToToken1Path;
        wmaticToToken0Path = _wmaticToToken0Path;
        wmaticToToken1Path = _wmaticToToken1Path;

        transferOwnership(vaultChefAddress);

        _resetAllowances();
    }
    
    /// @param _amount Deposit amount to the sushi yield
    /// @dev Vault deposit function
    function _vaultDeposit(uint256 _amount) internal override {
        ISushiStake(sushiYieldAddress).deposit(pid, _amount, address(this));
    }

    /// @param _amount Withdraw amount from sushi yield
    /// @dev Vault withdraw function
    function _vaultWithdraw(uint256 _amount) internal override {
        ISushiStake(sushiYieldAddress).withdraw(pid, _amount, address(this));
    }

    /// @dev Earn farm tokens and add liquidity
    function earn() external override nonReentrant whenNotPaused onlyGov {
        // Harvest farm tokens
        ISushiStake(sushiYieldAddress).harvest(pid, address(this));
        
        uint256 gainedAmt = IERC20(gainedAddress).balanceOf(address(this));

        if (gainedAmt > 0) {
            gainedAmt = distributeFees(gainedAmt, gainedAddress);
            gainedAmt = buyBack(gainedAmt, gainedAddress);

            if (gainedAddress != token0Address) {
                _safeSwap(
                    gainedAmt / 2,
                    gainedToToken0Path,
                    address(this)
                );
            }

            if (gainedAddress != token1Address) {
                _safeSwap(
                    gainedAmt / 2,
                    gainedToToken1Path,
                    address(this)
                );
            }
        }
        
        if (gainedAmt > 0) {
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

    /// @param _gainedAmt Gained token amount
    /// @param _gainedAddress Gained token address
    /// @dev Get fee of gained token amount
    function distributeFees(uint256 _gainedAmt, address _gainedAddress) internal returns (uint256) {
        if (controllerFee > 0) {
            uint256 fee = _gainedAmt * controllerFee / feeMax;

            if (_gainedAddress == wmaticAddress) {
                IWETH(wmaticAddress).withdraw(fee);
                safeTransferETH(feeAddress, fee);
            } else {
                _safeSwapWmatic(
                    fee,
                    gainedToWmaticPath,
                    feeAddress
                );
            }

            _gainedAmt = _gainedAmt - fee;
        }

        return _gainedAmt;
    }

    /// @param _gainedAmt Gained token amount
    /// @param _gainedAddress Gained token address
    /// @dev BuyBack gained token
    function buyBack(uint256 _gainedAmt, address _gainedAddress) internal returns (uint256) {
        if (buyBackRate > 0) {
            uint256 buyBackAmt = _gainedAmt * buyBackRate / feeMax;

            _safeSwap(
                buyBackAmt,
                _gainedAddress == wmaticAddress ? wmaticToBBankPath : gainedToBBankPath,
                buyBackAddress
            );

            _gainedAmt = _gainedAmt - buyBackAmt;
        }

        return _gainedAmt;
    }

    /// @dev Shares token total amount of vault
    function vaultSharesTotal() public override view returns (uint256) {
        (uint256 balance,) = ISushiStake(sushiYieldAddress).userInfo(pid, address(this));
        return balance;
    }

    /// @dev Locked want token total amount
    function wantLockedTotal() public override view returns (uint256) {
        (uint256 balance,) = ISushiStake(sushiYieldAddress).userInfo(pid, address(this));
        return IERC20(wantAddress).balanceOf(address(this)) + balance;
    }

    /// @dev Approve and increase allowances for all need tokens
    function _resetAllowances() internal override {
        IERC20(wantAddress).safeApprove(sushiYieldAddress, uint256(0));
        IERC20(wantAddress).safeIncreaseAllowance(
            sushiYieldAddress,
            type(uint256).max
        );

        IERC20(gainedAddress).safeApprove(uniRouterAddress, uint256(0));
        IERC20(gainedAddress).safeIncreaseAllowance(
            uniRouterAddress,
            type(uint256).max
        );

        IERC20(wmaticAddress).safeApprove(uniRouterAddress, uint256(0));
        IERC20(wmaticAddress).safeIncreaseAllowance(
            uniRouterAddress,
            type(uint256).max
        );

        IERC20(token0Address).safeApprove(uniRouterAddress, uint256(0));
        IERC20(token0Address).safeIncreaseAllowance(
            uniRouterAddress,
            type(uint256).max
        );

        IERC20(token1Address).safeApprove(uniRouterAddress, uint256(0));
        IERC20(token1Address).safeIncreaseAllowance(
            uniRouterAddress,
            type(uint256).max
        );
    }

    /// @dev Withdraw the total shares token
    function _emergencyVaultWithdraw() internal override {
        ISushiStake(sushiYieldAddress).withdraw(pid, vaultSharesTotal(), address(this));
    }

    /// @dev Withdraw the total shares token
    function emergencyPanic() external onlyGov {
        _pause();
        ISushiStake(sushiYieldAddress).emergencyWithdraw(pid, address(this));
    }

    /// @param to Address to send token
    /// @param value Amount of token
    /// @dev Transfer the amount of token
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "TransferHelper::safeTransferETH: ETH transfer failed");
    }

    receive() external payable {}
}