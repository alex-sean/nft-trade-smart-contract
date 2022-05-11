// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IERC20Price {
  /**
   * @dev Return AVAX price in USD
   * @return returns in 18 digits
   */
  function getAVAXPrice() external view returns (uint256);

  /**
   * @dev Calculate token price in USD
   * @param _token ERC20 token address
   * @return return in 18 digits
   */
  function getTokenPrice(
    address _token
  ) external view returns (uint256);
}