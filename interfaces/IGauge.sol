// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGauge {

    function balanceOf(address) external view returns (uint256);
}
