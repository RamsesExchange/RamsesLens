// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IPair {
    function tokens() external view returns (address, address);
    function symbol() external view returns (string memory);
    function fees() external view returns (address);
}
