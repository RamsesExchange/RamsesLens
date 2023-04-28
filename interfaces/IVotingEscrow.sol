// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVotingEscrow {
    function balanceOf(address) external view returns (uint256);
    function balanceOfNFT(uint256) external view returns (uint256);
    function locked(uint256) external view returns (LockedBalance memory);
    function token() external view returns (address);
    function voter() external view returns (address);
    function tokenOfOwnerByIndex(address, uint256)
        external
        view
        returns (uint256);
    struct LockedBalance {
        int128 amount;
        uint256 end;
    }
}
