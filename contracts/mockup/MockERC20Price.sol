// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interface/IERC20Price.sol";

contract MockERC20Price is Ownable, IERC20Price {
    using SafeMath for uint256;

    uint256 private _avaxPrice = 30 * 10 ** 18;

    function _getAVAXPrice() internal view returns (uint256) {
        return _avaxPrice;
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
     * @return uint256 returns Arcade token price in USD
     */
    function getTokenPrice(
        address _token
    ) external override view returns (uint256) {
        uint256 avaxPrice = _getAVAXPrice();
        return avaxPrice.mul(5);
    }
}