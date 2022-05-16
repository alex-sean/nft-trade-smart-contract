//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

enum OrderStatus {
    NONE,
    LISTING,
    PENDING,
    COMPLETED,
    CANCELLED
}