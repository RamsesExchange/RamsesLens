// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IMinter {
    function _rewards_distributor() external view returns (address);
}
