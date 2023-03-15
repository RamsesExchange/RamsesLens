// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "./interfaces/IRamsesLens.sol";
import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IFeeDistributor.sol";
import "./interfaces/IVoter.sol";
import "./interfaces/IPair.sol";
import "./interfaces/IRam.sol";
import "./ProxyImplementation.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/*
@title RamsesLens
@author 0xDAO-fi, Ramses Exchange
@notice Fork of SolidlyLens optimized for Ramses Exchange
*/


/**************************************************
 *                   Interfaces
 **************************************************/

interface IMinter {
    function _ve_dist() external view returns (address);
}

/**************************************************
 *                 Core contract
 **************************************************/
contract RamsesLens is ProxyImplementation {
    address public veAddress;
    address public ownerAddress;

    // Internal interfaces
    IVoter internal voter;
    IMinter internal minter;
    IVotingEscrow internal ve;
    IRam internal ram;

    /**************************************************
     *                   Structs
     **************************************************/
    struct Pool {
        address id;
        string symbol;
        bool stable;
        address token0Address;
        address token1Address;
        address gaugeAddress;
        address bribeAddress;
        address[] bribeTokensAddresses;
        address fees;
    }

    struct ProtocolMetadata {
        address veAddress;
        address ramAddress;
        address voterAddress;
        address poolsFactoryAddress;
        address gaugesFactoryAddress;
        address minterAddress;
    }

    /**************************************************
     *                   Configuration
     **************************************************/

    /**
     * @notice Initialize proxy storage
     */
    function initializeProxyStorage(address _veAddress)
        public
        checkProxyInitialized
    {
        veAddress = _veAddress;
        ownerAddress = msg.sender;
        ve = IVotingEscrow(veAddress);
        ram = IRam(ve.token());
        voter = IVoter(ve.voter());
        minter = IMinter(ram.minter());
    }

    function setVeAddress(address _veAddress) external {
        require(msg.sender == ownerAddress, "Only owner");
        veAddress = _veAddress;
    }

    function setOwnerAddress(address _ownerAddress) external {
        require(msg.sender == ownerAddress, "Only owner");
        ownerAddress = _ownerAddress;
    }

    /**************************************************
     *                 Protocol addresses
     **************************************************/
    function voterAddress() public view returns (address) {
        return ve.voter();
    }

    function poolsFactoryAddress() public view returns (address) {
        return voter.factory();
    }

    function gaugesFactoryAddress() public view returns (address) {
        return voter.gaugefactory();
    }

    function ramAddress() public view returns (address) {
        return ve.token();
    }

    function routerAddress() public view returns (address) {
        return ram.router();
    }

    function veDistAddress() public view returns (address) {
        return minter._ve_dist();
    }

    function minterAddress() public view returns (address) {
        return ram.minter();
    }

    /**************************************************
     *                  Protocol data
     **************************************************/
    function protocolMetadata()
        external
        view
        returns (ProtocolMetadata memory)
    {
        return
            ProtocolMetadata({
                veAddress: veAddress,
                voterAddress: voterAddress(),
                ramAddress: ramAddress(),
                poolsFactoryAddress: poolsFactoryAddress(),
                gaugesFactoryAddress: gaugesFactoryAddress(),
                minterAddress: minterAddress()
            });
    }

    function poolsLength() public view returns (uint256) {
        return voter.length();
    }

    function poolsAddresses() public view returns (address[] memory) {
        uint256 _poolsLength = poolsLength();
        address[] memory _poolsAddresses = new address[](_poolsLength);
        for (uint256 poolIndex; poolIndex < _poolsLength; poolIndex++) {
            address poolAddress = voter.pools(poolIndex);
            _poolsAddresses[poolIndex] = poolAddress;
        }
        return _poolsAddresses;
    }

    function poolInfo(address poolAddress)
        public
        view
        returns (IRamsesLens.Pool memory)
    {
        IPair pool = IPair(poolAddress);
        address token0Address = pool.token0();
        address token1Address = pool.token1();
        address gaugeAddress = voter.gauges(poolAddress);
        address bribeAddress = voter.bribes(gaugeAddress);
        address[]
            memory _bribeTokensAddresses = bribeTokensAddressesByBribeAddress(
                bribeAddress
            );
        if (_bribeTokensAddresses.length < 2) {
            _bribeTokensAddresses = new address[](2);
            _bribeTokensAddresses[0] = token0Address;
            _bribeTokensAddresses[1] = token1Address;
        }
        return
            IRamsesLens.Pool({
                id: poolAddress,
                symbol: pool.symbol(),
                stable: pool.stable(),
                token0Address: token0Address,
                token1Address: token1Address,
                gaugeAddress: gaugeAddress,
                bribeAddress: bribeAddress,
                bribeTokensAddresses: _bribeTokensAddresses,
                fees: pool.fees()
            });
    }

    function poolsInfo() external view returns (IRamsesLens.Pool[] memory) {
        address[] memory _poolsAddresses = poolsAddresses();
        IRamsesLens.Pool[] memory pools = new IRamsesLens.Pool[](
            _poolsAddresses.length
        );
        for (
            uint256 poolIndex;
            poolIndex < _poolsAddresses.length;
            poolIndex++
        ) {
            address poolAddress = _poolsAddresses[poolIndex];
            IRamsesLens.Pool memory _poolInfo = poolInfo(poolAddress);
            pools[poolIndex] = _poolInfo;
        }
        return pools;
    }

    function gaugesAddresses() public view returns (address[] memory) {
        address[] memory _poolsAddresses = poolsAddresses();
        address[] memory _gaugesAddresses = new address[](
            _poolsAddresses.length
        );
        for (
            uint256 poolIndex;
            poolIndex < _poolsAddresses.length;
            poolIndex++
        ) {
            address poolAddress = _poolsAddresses[poolIndex];
            address gaugeAddress = voter.gauges(poolAddress);
            _gaugesAddresses[poolIndex] = gaugeAddress;
        }
        return _gaugesAddresses;
    }

    function bribesAddresses() public view returns (address[] memory) {
        address[] memory _gaugesAddresses = gaugesAddresses();
        address[] memory _bribesAddresses = new address[](
            _gaugesAddresses.length
        );
        for (uint256 gaugeIdx; gaugeIdx < _gaugesAddresses.length; gaugeIdx++) {
            address gaugeAddress = _gaugesAddresses[gaugeIdx];
            address bribeAddress = voter.bribes(gaugeAddress);
            _bribesAddresses[gaugeIdx] = bribeAddress;
        }
        return _bribesAddresses;
    }

    function bribeTokensAddressesByBribeAddress(address bribeAddress)
        public
        view
        returns (address[] memory)
    {
        uint256 bribeTokensLength = IFeeDistributor(bribeAddress).getRewardTokens().length;
        address[] memory _bribeTokensAddresses = new address[](
            bribeTokensLength
        );
        for (
            uint256 bribeTokenIdx;
            bribeTokenIdx < bribeTokensLength;
            bribeTokenIdx++
        ) {
            address bribeTokenAddress = IFeeDistributor(bribeAddress).rewards(
                bribeTokenIdx
            );
            _bribeTokensAddresses[bribeTokenIdx] = bribeTokenAddress;
        }
        return _bribeTokensAddresses;
    }

    function poolsPositionsOf(
        address accountAddress,
        uint256 startIndex,
        uint256 endIndex
    ) public view returns (IRamsesLens.PositionPool[] memory) {
        uint256 _poolsLength = poolsLength();
        IRamsesLens.PositionPool[]
            memory _poolsPositionsOf = new IRamsesLens.PositionPool[](
                _poolsLength
            );
        uint256 positionsLength;
        endIndex = Math.min(endIndex, _poolsLength);
        for (
            uint256 poolIndex = startIndex;
            poolIndex < endIndex;
            poolIndex++
        ) {
            address poolAddress = voter.pools(poolIndex);
            uint256 balanceOf = IPair(poolAddress).balanceOf(
                accountAddress
            );
            if (balanceOf > 0) {
                _poolsPositionsOf[positionsLength] = IRamsesLens.PositionPool({
                    id: poolAddress,
                    balanceOf: balanceOf
                });
                positionsLength++;
            }
        }

        bytes memory encodedPositions = abi.encode(_poolsPositionsOf);
        assembly {
            mstore(add(encodedPositions, 0x40), positionsLength)
        }
        return abi.decode(encodedPositions, (IRamsesLens.PositionPool[]));
    }

    function poolsPositionsOf(address accountAddress)
        public
        view
        returns (IRamsesLens.PositionPool[] memory)
    {
        uint256 _poolsLength = poolsLength();
        IRamsesLens.PositionPool[]
            memory _poolsPositionsOf = new IRamsesLens.PositionPool[](
                _poolsLength
            );

        uint256 positionsLength;

        for (uint256 poolIndex; poolIndex < _poolsLength; poolIndex++) {
            address poolAddress = voter.pools(poolIndex);
            uint256 balanceOf = IPair(poolAddress).balanceOf(
                accountAddress
            );
            if (balanceOf > 0) {
                _poolsPositionsOf[positionsLength] = IRamsesLens.PositionPool({
                    id: poolAddress,
                    balanceOf: balanceOf
                });
                positionsLength++;
            }
        }

        bytes memory encodedPositions = abi.encode(_poolsPositionsOf);
        assembly {
            mstore(add(encodedPositions, 0x40), positionsLength)
        }
        return abi.decode(encodedPositions, (IRamsesLens.PositionPool[]));
    }

    function veTokensIdsOf(address accountAddress)
        public
        view
        returns (uint256[] memory)
    {
        uint256 veBalanceOf = ve.balanceOf(accountAddress);
        uint256[] memory _veTokensOf = new uint256[](veBalanceOf);

        for (uint256 tokenIdx; tokenIdx < veBalanceOf; tokenIdx++) {
            uint256 tokenId = ve.tokenOfOwnerByIndex(accountAddress, tokenIdx);
            _veTokensOf[tokenIdx] = tokenId;
        }
        return _veTokensOf;
    }

    function gaugeAddressByPoolAddress(address poolAddress)
        external
        view
        returns (address)
    {
        return voter.gauges(poolAddress);
    }

    function bribeAddresByPoolAddress(address poolAddress)
        public
        view
        returns (address)
    {
        address gaugeAddress = voter.gauges(poolAddress);
        address bribeAddress = voter.bribes(gaugeAddress);
        return bribeAddress;
    }

    function bribeTokensAddressesByPoolAddress(address poolAddress)
        public
        view
        returns (address[] memory)
    {
        address bribeAddress = bribeAddresByPoolAddress(poolAddress);
        return bribeTokensAddressesByBribeAddress(bribeAddress);
    }

    function bribesPositionsOf(
        address poolAddress,
        uint256 tokenId
    ) public view returns (IRamsesLens.PositionBribe[] memory) {
        address bribeAddress = bribeAddresByPoolAddress(poolAddress);
        address[]
            memory bribeTokensAddresses = bribeTokensAddressesByBribeAddress(
                bribeAddress
            );
        IRamsesLens.PositionBribe[]
            memory _bribesPositionsOf = new IRamsesLens.PositionBribe[](
                bribeTokensAddresses.length
            );
        uint256 currentIdx;
        for (
            uint256 bribeTokenIdx;
            bribeTokenIdx < bribeTokensAddresses.length;
            bribeTokenIdx++
        ) {
            address bribeTokenAddress = bribeTokensAddresses[bribeTokenIdx];
            uint256 earned = IFeeDistributor(bribeAddress).earned(
                bribeTokenAddress,
                tokenId
            );
            if (earned > 0) {
                _bribesPositionsOf[currentIdx] = IRamsesLens.PositionBribe({
                    bribeTokenAddress: bribeTokenAddress,
                    earned: earned
                });
                currentIdx++;
            }
        }
        bytes memory encodedBribes = abi.encode(_bribesPositionsOf);
        assembly {
            mstore(add(encodedBribes, 0x40), currentIdx)
        }
        IRamsesLens.PositionBribe[] memory filteredBribes = abi.decode(
            encodedBribes,
            (IRamsesLens.PositionBribe[])
        );
        return filteredBribes;
    }

    function bribesPositionsOf(address accountAddress, address poolAddress)
        public
        view
        returns (IRamsesLens.PositionBribesByTokenId[] memory)
    {
     
        uint256[] memory veTokensIds = veTokensIdsOf(accountAddress);
        IRamsesLens.PositionBribesByTokenId[]
            memory _bribePositionsOf = new IRamsesLens.PositionBribesByTokenId[](
                veTokensIds.length
            );

        uint256 currentIdx;
        for (
            uint256 veTokenIdIdx;
            veTokenIdIdx < veTokensIds.length;
            veTokenIdIdx++
        ) {
            uint256 tokenId = veTokensIds[veTokenIdIdx];
            _bribePositionsOf[currentIdx] = IRamsesLens
                .PositionBribesByTokenId({
                    tokenId: tokenId,
                    bribes: bribesPositionsOf(
                        poolAddress,
                        tokenId
                    )
                });
            currentIdx++;
        }
        return _bribePositionsOf;
    }

    function vePositionsOf(address accountAddress)
        public
        view
        returns (IRamsesLens.PositionVe[] memory)
    {
        uint256 veBalanceOf = ve.balanceOf(accountAddress);
        IRamsesLens.PositionVe[]
            memory _vePositionsOf = new IRamsesLens.PositionVe[](veBalanceOf);

        for (uint256 tokenIdx; tokenIdx < veBalanceOf; tokenIdx++) {
            uint256 tokenId = ve.tokenOfOwnerByIndex(accountAddress, tokenIdx);
            uint256 balanceOf = ve.balanceOfNFT(tokenId);
            uint256 locked = ve.locked(tokenId);
            _vePositionsOf[tokenIdx] = IRamsesLens.PositionVe({
                tokenId: tokenId,
                balanceOf: balanceOf,
                locked: locked
            });
        }
        return _vePositionsOf;
    }
}