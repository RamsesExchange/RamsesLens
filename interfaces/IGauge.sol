// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IGauge {
   function rewardsListLength() external view returns (uint);
   function rewards(uint) external view returns (address);
   function balanceOf(address) external view returns (uint);
   function derivedBalances(address) external view returns (uint);
   function earned(address token, address account) external view returns (uint);
   function rewardRate(address token) external view returns (uint);
}
