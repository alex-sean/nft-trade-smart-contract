//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../const/OrderType.sol";

struct BidOrder {
    uint256 orderId;
    address buyer;
    address erc20ContractAddress;
    uint256 bidAmount;
}