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

    address public constant aaveDataAddress    = 0x7551b5D2763519d4e37e8B81929D336De671d46d; // Polygon
    address public constant aaveDepositAddress = 0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf; // Polygon, as Proxy : ABI for the implementation contract at 0x6a8730f54b8c69ab096c43ff217ca0a350726ac7
    address public constant aaveClaimAddress   = 0x357D51124f59836DeD84c8a1730D72B749d8BC23; // Polygon, as Proxy : ABI for the implementation contract at 0x2c901a65071c077c78209b06ab2b5d8ec285ab84

    address public wantAddress;
    address public vTokenAddress;
    address public debtTokenAddress;
    address public earnedAddress;
    uint16 public referralCode = 0;

    address public uniRouterAddress       = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff; // Polygon
    address public constant wmaticAddress = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // Polygon
    address public constant usdcAddress   = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; // Polygon
    address public constant bbankAddress  = 0xADa17be1b58891d8e1FDA75F73f93152969F6fda; // Rinkeby
    address public constant rewardAddress = 0x917FB15E8aAA12264DCBdC15AFef7cD3cE76BA39; // Polygon, StrategyFish
    address public constant vaultAddress  = 0x4879712c5D1A98C0B88Fb700daFF5c65d12Fd729; // Polygon
    address public constant feeAddress    = 0x1cb757f1eB92F25A917CE9a92ED88c1aC0734334; // Polygon
    
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

    address[] public vTokenArray;
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
        address _vTokenAddress,
        address _debtTokenAddress,
        address _earnedAddress,
        address[] memory _earnedToUsdcPath,
        address[] memory _earnedToBbankPath,
        address[] memory _earnedToWantPath
    ) {
        govAddress = msg.sender;
        vaultChefAddress = _vaultChefAddress;

        wantAddress = _wantAddress;
        vTokenAddress = _vTokenAddress;
        vTokenArray = [vTokenAddress];
        debtTokenAddress = _debtTokenAddress;

        earnedAddress = _earnedAddress;

        earnedToUsdcPath = _earnedToUsdcPath;
        earnedToBbankPath = _earnedToBbankPath;
        earnedToWantPath = _earnedToWantPath;

        transferOwnership(vaultChefAddress);

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

    }

    function wantLockedInHere() public view returns (uint256) {

    }

    function wantLockedTotal() public view returns (uint256) {

    }

    function _resetAllowances() internal {

    }

    function _leverage(uint256 _wantAmt) internal {

    }
}