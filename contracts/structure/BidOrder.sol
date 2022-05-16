//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../const/OrderType.sol";

struct BidOrder {
    address buyer;
    address erc20ContractAddress;
    uint256 bidAmount;
}