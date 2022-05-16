//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../const/OrderType.sol";
import "../const/OrderStatus.sol";
import "./BidOrder.sol";

struct SellOrder {
    address seller;
    address collectionAddress;
    uint256 tokenId;
    uint256 usdtPrice;
    
    bool isStableCoin;  // if sell token in stable coin, set true
    address[] erc20ContractAddresses;

    OrderType orderType;

    BidOrder[] bidOrders;
    uint256 selectedBidIndex;

    OrderStatus status;
    uint256 auctionEndTime;
}