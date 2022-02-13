// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/IAaveStake.sol";
import "../interfaces/IProtocolDataProvider.sol";
import "../interfaces/IUniPair.sol";
import "../interfaces/IUniRouter02.sol";
import "../interfaces/IWETH.sol";

contract StrategyAave is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    address public constant aaveDataAddress    = 0xFA3bD19110d986c5e5E9DD5F69362d05035D045B; // Mumbai testnet // 0x7551b5D2763519d4e37e8B81929D336De671d46d; // Polygon
    address public constant aaveDepositAddress = 0x9198F13B08E299d85E096929fA9781A1E3d5d827; // Mumbai testnet // 0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf; // Polygon
    address public constant aaveClaimAddress   = 0xd41aE58e803Edf4304334acCE4DC4Ec34a63C644; // Mumbai testnet // 0x357D51124f59836DeD84c8a1730D72B749d8BC23; // Polygon

    address public wantAddress;
    address public aTokenAddress;
    address public debtTokenAddress;
    address public earnedAddress;
    uint16 public referralCode = 0;

    address public uniRouterAddress       = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff; // Polygon/Mumbai testnet
    address public constant wmaticAddress = 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889; // Mumbai testnet // 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // Polygon
    address public constant usdcAddress   = 0xe6b8a5CF854791412c1f6EFC7CAf629f5Df1c747; // Mumbai testnet // 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; // Polygon
    address public constant bbankAddress  = 0x63F7B7D85F9B02aD94c93A138a5b7508937b5942; // Mumbai testnet
    address public constant vaultAddress  = 0xD81bdF78b3bC96EE1838fE4ee820145F8101BbE9;
    address public constant feeAddress    = 0x2B8406c07613490cF56b978b8D531fd7EB066582;
    
    address public vaultChefAddress;
    address public govAddress;

    uint256 public lastEarnBlock = block.number;
    uint256 public sharesTotal   = 0;

    address public constant buyBackAddress = 0x000000000000000000000000000000000000dEaD;
    uint256 public controllerFee = 50;
    uint256 public rewardRate = 0;
    uint256 public buyBackRate = 450;
    uint256 public constant feeMaxTotal = 1000;
    uint256 public constant feeMax = 10000; // 100 = 1%

    uint256 public withdrawFeeFactor = 10000; // 0% withdraw fee
    uint256 public constant withdrawFeeFactorMax = 10000;
    uint256 public constant withdrawFeeFactorLL = 9900;

    uint256 public slippageFactor = 950; // 5% default slippage tolerance
    uint256 public constant slippageFactorUL = 995;
    
    /**
     * @dev Variables that can be changed to config profitability and risk:
     * {borrowRate}          - At What % of our collateral do we borrow per leverage level.
     * {borrowDepth}         - How many levels of leverage do we take.
     * {BORROW_RATE_MAX}     - A limit on how much we can push borrow risk.
     * {BORROW_DEPTH_MAX}    - A limit on how many steps we can leverage.
     */
    uint256 public borrowRate;
    uint256 public borrowDepth = 6;
    uint256 public minLeverage;
    uint256 public BORROW_RATE_MAX;
    uint256 public BORROW_RATE_MAX_HARD;
    uint256 public BORROW_DEPTH_MAX = 8;
    uint256 public constant BORROW_RATE_DIVISOR = 10000;

    address[] public aTokenArray;
    address[] public earnedToUsdcPath;
    address[] public earnedToBbankPath;
    address[] public earnedToWantPath;

    event SetSettings(
        uint256 _controllerFee,
        uint256 _rewardRate,
        uint256 _buyBackRate,
        uint256 _withdrawFeeFactor,
        uint256 _slippageFactor,
        address _uniRouterAddress,
        uint16 _referralCode
    );

    modifier onlyGov() {
        require(msg.sender == govAddress, "!gov");
        _;
    }

    constructor(
        address _vaultChefAddress,
        address _wantAddress,
        address _aTokenAddress,
        address _debtTokenAddress,
        address _earnedAddress,
        address[] memory _earnedToUsdcPath,
        address[] memory _earnedToBbankPath,
        address[] memory _earnedToWantPath
    ) {
        govAddress = msg.sender;
        vaultChefAddress = _vaultChefAddress;

        wantAddress = _wantAddress;
        aTokenAddress = _aTokenAddress;
        aTokenArray = [aTokenAddress];
        debtTokenAddress = _debtTokenAddress;

        earnedAddress = _earnedAddress;

        earnedToUsdcPath = _earnedToUsdcPath;
        earnedToBbankPath = _earnedToBbankPath;
        earnedToWantPath = _earnedToWantPath;
        
        (, uint256 ltv, uint256 threshold, , , bool collateral, bool borrow, , , ) = 
            IProtocolDataProvider(aaveDataAddress).getReserveConfigurationData(wantAddress);
        BORROW_RATE_MAX = ltv * 99 / 100; // 1%
        BORROW_RATE_MAX_HARD = ltv * 999 / 1000; // 0.1%
        // At minimum, borrow rate always 10% lower than liquidation threshold
        if (threshold * 9 / 10 > BORROW_RATE_MAX) {
            borrowRate = BORROW_RATE_MAX;
        } else {
            borrowRate = threshold * 9 / 10;
        }
        // Only leverage if you can
        if (!(collateral && borrow)) {
            borrowDepth = 0;
            BORROW_DEPTH_MAX = 0;
        }

        transferOwnership(_vaultChefAddress);

        _resetAllowances();
    }

    function deposit(uint256 _wantAmt) external onlyOwner nonReentrant whenNotPaused returns (uint256) {
        // Call must happen before transfer
        uint256 wantLockedBefore = wantLockedTotal();

        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        // Proper deposit amount for tokens with fees, or vaults with deposit fees
        uint256 sharesAdded = _farm(_wantAmt);
        if (sharesTotal > 0 && wantLockedBefore > 0) {
            sharesAdded = sharesAdded * sharesTotal / wantLockedBefore;
        }
        sharesTotal = sharesTotal + sharesAdded;

        return sharesAdded;
    }

    function _farm(uint256 _wantAmt) internal returns (uint256) {
        uint256 wantAmt = wantLockedInHere();
        if (wantAmt == 0) return 0;

        // Cheat method to check for deposit fees in Aave
        uint256 sharesBefore = wantLockedTotal() - _wantAmt;
        _leverage(wantAmt);

        return wantLockedTotal() - sharesBefore;
    }

    function withdraw(uint256 _wantAmt) external onlyOwner nonReentrant returns (uint256) {
        require(_wantAmt > 0, "_wantAmt is 0");

        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        
        if (_wantAmt > wantAmt) {
            // Fully deleverage
            _deleverage();
            wantAmt = IERC20(wantAddress).balanceOf(address(this));
        }

        if (_wantAmt > wantAmt) {
            _wantAmt = wantAmt;
        }

        if (_wantAmt > wantLockedTotal()) {
            _wantAmt = wantLockedTotal();
        }

        uint256 sharesRemoved = _wantAmt * sharesTotal / wantLockedTotal();

        if (sharesRemoved > sharesTotal) {
            sharesRemoved = sharesTotal;
        }
        sharesTotal = sharesTotal - sharesRemoved;

        // Withdraw fee
        uint256 withdrawFee = _wantAmt * ( withdrawFeeFactorMax - withdrawFeeFactor ) / withdrawFeeFactorMax;
        if (withdrawFee > 0) {
            IERC20(wantAddress).safeTransfer(vaultAddress, withdrawFee);
        }

        _wantAmt = _wantAmt - withdrawFee;

        IERC20(wantAddress).safeTransfer(vaultChefAddress, _wantAmt);

        if (!paused()) {
            // Put it all back in
            _leverage(wantLockedInHere());
        }

        return sharesRemoved;
    }

    function _supply(uint256 _amount) internal {
        IAaveStake(aaveDepositAddress).deposit(wantAddress, _amount, address(this), referralCode);
    }

    function _borrow(uint256 _amount) internal {
        IAaveStake(aaveDepositAddress).borrow(wantAddress, _amount, 2, referralCode, address(this));
    }

    function _repayBorrow(uint256 _amount) internal {
        IAaveStake(aaveDepositAddress).repay(wantAddress, _amount, 2, address(this));
    }

    function _removeSupply(uint256 _amount) internal {
        IAaveStake(aaveDepositAddress).withdraw(wantAddress, _amount, address(this));
    }

    function _leverage(uint256 _amount) internal {
        if (borrowDepth == 0) {
            _supply(_amount);
        } else if (_amount > minLeverage) {
            for (uint256 i = 0; i < borrowDepth; i ++) {
                _supply(_amount);
                _amount = _amount * borrowRate / BORROW_RATE_DIVISOR;
                _borrow(_amount);
            }
        }
    }

    function _deleverage() internal {
        uint256 wantBal = wantLockedInHere();

        if (borrowDepth > 0) {
            while (wantBal < debtTotal()) {
                _repayBorrow(wantBal);
                _removeSupply(aTokenTotal() - supplyBalMin());
                wantBal = wantLockedInHere();
            }
        }
    }

    function deleverageOnce() external onlyGov {
        _deleverageOnce();
    }

    function _deleverageOnce() internal {
        if (aTokenTotal() <= supplyBalTargeted()) {
            _removeSupply(aTokenTotal() - supplyBalMin());
        } else {
            _removeSupply(aTokenTotal() - supplyBalTargeted());
        }

        _repayBorrow(wantLockedInHere());
    }

    function earn() external nonReentrant whenNotPaused onlyGov {
        uint256 preEarn = IERC20(earnedAddress).balanceOf(address(this));

        // Harvest farm tokens
        IAaveStake(aaveClaimAddress).claimRewards(aTokenArray, type(uint256).max, address(this));

        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this)) - preEarn;

        if (earnedAmt > 0) {
            earnedAmt = distributeFees(earnedAmt);
            earnedAmt = buyBack(earnedAmt);

            if (earnedAddress != wantAddress) {
                _safeSwap(
                    earnedAmt,
                    earnedToWantPath,
                    address(this)
                );
            }

            lastEarnBlock = block.number;

            _leverage(wantLockedInHere());
        }
    }

    function distributeFees(uint256 _earnedAmt) internal returns (uint256) {
        if (controllerFee > 0) {
            uint256 fee = _earnedAmt * controllerFee / feeMax;

            IWETH(wmaticAddress).withdraw(fee);
            safeTransferETH(feeAddress, fee);

            _earnedAmt = _earnedAmt - fee;
        }

        return _earnedAmt;
    }

    function buyBack(uint256 _earnedAmt) internal returns (uint256) {
        if (buyBackRate > 0) {
            uint256 buyBackAmt = _earnedAmt * buyBackRate / feeMax;

            _safeSwap(
                buyBackAmt,
                earnedToBbankPath,
                buyBackAddress
            );

            _earnedAmt = _earnedAmt - buyBackAmt;
        }

        return _earnedAmt;
    }

    function pause() external onlyGov {
        _pause();
    }

    function unpause() external onlyGov {
        _unpause();
        _resetAllowances();
    }

    function wantLockedInHere() public view returns (uint256) {
        return IERC20(wantAddress).balanceOf(address(this));
    }

    function wantLockedTotal() public view returns (uint256) {
        return wantLockedInHere() + aTokenTotal() - debtTotal();
    }

    function _resetAllowances() internal {
        IERC20(wantAddress).safeApprove(aaveDepositAddress, type(uint256).max);

        IERC20(earnedAddress).safeApprove(uniRouterAddress, type(uint256).max);
    }

    function resetAllowances() external onlyGov {
        _resetAllowances();
    }

    function debtTotal() public view returns (uint256) {
        return IERC20(debtTokenAddress).balanceOf(address(this));
    }

    function aTokenTotal() public view returns (uint256) {
        return IERC20(aTokenAddress).balanceOf(address(this));
    }

    function supplyBalMin() public view returns (uint256) {
        return debtTotal() * BORROW_RATE_DIVISOR / BORROW_RATE_MAX_HARD;
    }

    function supplyBalTargeted() public view returns (uint256) {
        return debtTotal() * BORROW_RATE_DIVISOR / borrowRate;
    }

    function _safeSwap(
        uint256 _amountIn,
        address[] memory _path,
        address _to
    ) internal {
        uint256[] memory amounts = IUniRouter02(uniRouterAddress).getAmountsOut(_amountIn, _path);
        uint256 amountOut = amounts[amounts.length - 1];

        IUniRouter02(uniRouterAddress).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amountIn, 
            amountOut * slippageFactor, 
            _path, 
            _to, 
            block.timestamp
        );
    }

    function safeTransferETH(address _to, uint256 _value) internal {
        (bool success, ) = _to.call{value: _value}(new bytes(0));
        require(success, "TransferHelper::safeTransferETH: ETH transfer failed");
    }

    function rebalance(uint256 _borrowRate, uint256 _borrowDepth) external onlyGov {
        require(_borrowRate <= BORROW_RATE_MAX, "!rate");
        require(_borrowRate != 0, "borrowRate is used as a divisor");
        require(_borrowDepth <= BORROW_DEPTH_MAX, "!depth");

        _deleverage();
        borrowRate = _borrowRate;
        borrowDepth = _borrowDepth;
        _leverage(wantLockedInHere());
    }

    function setSettings(
        uint256 _controllerFee,
        uint256 _rewardRate,
        uint256 _buyBackRate,
        uint256 _withdrawFeeFactor,
        uint256 _slippageFactor,
        address _uniRouterAddress,
        uint16 _referralCode
    ) external onlyGov {
        require(_controllerFee + _rewardRate + buyBackRate <= feeMaxTotal, "Max fee of 100%");
        require(_withdrawFeeFactor >= withdrawFeeFactorLL, "_withdrawFeeFactor too low");
        require(_withdrawFeeFactor <= withdrawFeeFactorMax, "_withdrawFeeFactor too high");
        require(_slippageFactor <= slippageFactorUL, "_slippageFactor too high");

        controllerFee = _controllerFee;
        rewardRate = _rewardRate;
        buyBackRate = _buyBackRate;
        withdrawFeeFactor = _withdrawFeeFactor;
        slippageFactor = _slippageFactor;
        uniRouterAddress = _uniRouterAddress;
        referralCode = _referralCode;

        emit SetSettings(_controllerFee, _rewardRate, _buyBackRate, _withdrawFeeFactor, _slippageFactor, _uniRouterAddress, _referralCode);
    }

    function setGov(address _govAddress) external onlyGov {
        govAddress = _govAddress;
    }

    receive() external payable {}
}