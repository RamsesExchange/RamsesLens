// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IFeeDistributor {
    function getRewardTokens() external view returns (address[] memory);
    function earned(address token, uint tokenId) external view returns (uint reward);
}
