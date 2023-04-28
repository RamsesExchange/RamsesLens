// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVoter {
    function _ve() external view returns (address);
    function factory() external view returns (address);
    function gaugefactory() external view returns (address);
    function gauges(address pool) external view returns (address);
    function feeDistributers(address pool) external view returns (address);
    function length() external view returns (uint256);
    function pools(uint) external view returns (address);
    function minter() external view returns (address);
}
