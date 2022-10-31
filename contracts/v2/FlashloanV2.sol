//SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./aave/FlashLoanReceiverBaseV2.sol";
import "../../interfaces/v2/ILendingPoolAddressesProviderV2.sol";
import "../../interfaces/v2/ILendingPoolV2.sol";
import "../../interfaces/IUniswapV2Router02.sol";
import "../../interfaces/WethInterface.sol";

contract FlashloanV2 is FlashLoanReceiverBaseV2, Withdrawable {

    struct Router {
        IUniswapV2Router02 UniRouter;
        IUniswapV2Router02 SushiRouter;
    }

    Router public myRouter;

    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    constructor(address _addressProvider, address _Urouter, address _Srouter) FlashLoanReceiverBaseV2(_addressProvider) public {
        myRouter.UniRouter = IUniswapV2Router02(_Urouter);
        myRouter.SushiRouter = IUniswapV2Router02(_Srouter);
    }

    /**
     * @dev This function must be called only be the LENDING_POOL and takes care of repaying
     * active debt positions, migrating collateral and incurring new V2 debt token debt.
     *
     * @param assets The array of flash loaned assets used to repay debts.
     * @param amounts The array of flash loaned asset amounts used to repay debts.
     * @param premiums The array of premiums incurred as additional debts.
     * @param initiator The address that initiated the flash loan, unused.
     * @param params The byte array containing, in this case, the arrays of aTokens and aTokenAmounts.
     */

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {

        // Strategy 
        // Just to perform a non-profit arbitrage 
        // either uisng same DEX [0] or different DEX [1]
        uint amountOutDAI = Swap(assets[0], DAI, amounts[0], 0);

        uint amountOutWBTC = Swap(DAI, assets[0], amountOutDAI, 0);


        for (uint i = 0; i < assets.length; i++) {
            uint amountOwing = amounts[i].add(premiums[i]);
            IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
        }
        
        return true;
    }

    function _flashloan(address[] memory assets, uint256[] memory amounts) internal {
        address receiverAddress = address(this);

        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;

        uint256[] memory modes = new uint256[](assets.length);

        // 0 = no debt (flash), 1 = stable, 2 = variable
        for (uint256 i = 0; i < assets.length; i++) {
            modes[i] = 0;
        }

        LENDING_POOL.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }

    /*
     *  Flash multiple assets 
     */
    function flashloan(address[] memory assets, uint256[] memory amounts) public onlyOwner {
        _flashloan(assets, amounts);
    }

    /*
     *  Flash loan 1000000000000000000 wei (1 ether) worth of `_asset`
     */
    function flashloan(address _asset) public onlyOwner {
        bytes memory data = "";
        uint amount = 1 ether;

        address[] memory assets = new address[](1);
        assets[0] = _asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        _flashloan(assets, amounts);
    }

    // function getWethBal() external view returns (uint) {
    //     return IERC20(WETH).balanceOf(address(this));
    // }

    // r - is used to select dexes from the struct myRouter
    function Swap(address tokenIn, address tokenOut, uint amountIn, uint08 r) public returns (uint) {

        IUniswapV2Router02 router = (r == 0) ? myRouter.UniRouter : myRouter.SushiRouter;
        
        require(IERC20(tokenIn).balanceOf(address(this)) >= amountIn, "Insufficient tokenIn Balance !!!");
        require(IERC20(tokenIn).approve(address(router), amountIn));

        address[] memory path = new address[](3);
        path[0] = tokenIn;
        path[1] = router.WETH();
        path[2] = tokenOut;

        uint[] memory amountOutMin = router.getAmountsOut(amountIn, path);
        router.swapExactTokensForTokens(amountIn, amountOutMin[amountOutMin.length - 1], path, address(this), block.timestamp);

        return amountOutMin[amountOutMin.length -1];
    } 
}
