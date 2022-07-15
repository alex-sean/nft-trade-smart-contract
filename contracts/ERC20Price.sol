// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interface/PancakeSwapInterface.sol";
import "./interface/IERC20Price.sol";

contract BEP20Price is Ownable, IERC20Price {
    using SafeMath for uint256;

    address public factoryAddress;
    address public avaxAddress;
    address public usdtAddress;

    /**
     * @notice Initialize variable members
     * @param _factoryAddress PancakeSwap pool factory address
     * @param _avaxAddress AVAX token address
     * @param _usdtAddress USDT token address
     * @dev Callable by owner
     */
    function initialize(
        address _factoryAddress,
        address _avaxAddress,
        address _usdtAddress
    ) public onlyOwner {
        factoryAddress = _factoryAddress;
        avaxAddress = _avaxAddress;
        usdtAddress = _usdtAddress;
    }

    /**
     * @notice Get liquidity info from pancakeswap
     * Get the balance of `token1` and `token2` from liquidity pool
     * @param token1 1st token address
     * @param token2 2nd token address
     * @return (uint256, uint256) returns balance of token1 and token2 from pool
     */
    function _getLiquidityInfo(
        address token1, 
        address token2
    ) internal view returns (uint256, uint256) {
        address pairAddress = 
            IUniswapV2Factory(factoryAddress)
            .getPair(token1, token2);
        
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        (uint256 res0, uint256 res1,) = pair.getReserves();
        
        address pairToken0 = pair.token0();
        if (pairToken0 == token1) {
            return (res0, res1);
        } else {
            return (res1, res0);
        }
    }

    function _getAVAXPrice() internal view returns (uint256) {
        (uint256 avaxReserve, uint256 usdtReserve) = 
            _getLiquidityInfo(avaxAddress, usdtAddress);

        return 
            usdtReserve.mul(10 ** 18)
            .mul(ERC20(avaxAddress).decimals())
            .div(avaxReserve)
            .div(ERC20(usdtAddress).decimals());
    }

    /**
     * @notice Get AVAX price in USD
     * price = real_price * 10 ** 18
     * @return uint256 returns AVAX price in usd
     */
    function getAVAXPrice() external override view returns (uint256) {
        return _getAVAXPrice();
    }

    /**
     * @notice Get ERC20 token price in USD
     * price = real_price * 10 ** 18
     * @param _token ERC20 token address
     * @return uint256 returns token price in USD
     */
    function getTokenPrice(
        address _token
    ) external override view returns (uint256) {
        (uint256 tokenReserve, uint256 avaxReserve) = 
            _getLiquidityInfo(_token, avaxAddress);
        uint256 avaxPrice = _getAVAXPrice();
        return 
            avaxReserve.mul(avaxPrice)
            .mul(ERC20(_token).decimals())
            .div(tokenReserve)
            .div(ERC20(avaxAddress).decimals());
    }
}