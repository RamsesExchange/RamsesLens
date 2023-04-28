// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IPairFactory {
    function allPairsLength() external view returns (uint);
    function allPairs(uint index) external view returns (address);
    function pairFee(address pool) external view returns (uint);
}
