// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IFeeDistributor {
    function earned(address, uint256) external view returns (uint256);
    function getRewardTokens() external view returns (address[] memory);
    function rewards(uint256) external view returns (address);
}
