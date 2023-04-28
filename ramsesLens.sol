// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./interfaces/IPairFactory.sol";
import "./interfaces/IVoter.sol";
import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IMinter.sol";
import "./interfaces/IPair.sol";
import "./interfaces/IFeeDistributor.sol";
import "./interfaces/IGauge.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ramsesLens is Initializable {
    IVoter voter;
    IVotingEscrow ve;
    IMinter minter;

    address public router; // router address

    struct Pool {
        address id;
        string symbol;
        bool stable;
        address token0;
        address token1;
        address gauge;
        address feeDistributor;
        address pairFees;
        uint pairBps;
    }

    struct ProtocolMetadata {
        address veAddress;
        address ramAddress;
        address voterAddress;
        address poolsFactoryAddress;
        address gaugesFactoryAddress;
        address minterAddress;
    }
    
    struct vePosition {
        uint256 tokenId;
        uint256 balanceOf;
        uint256 locked;
    }

    struct tokenRewardData {
        address token;
        uint rewardRate;
    }

    struct gaugeRewardsData {
        address gauge;
        tokenRewardData[] rewardData;
    }

    // user earned per token
    struct userGaugeTokenData {
        address token;
        uint earned;
    }

    struct userGaugeRewardData {
        address gauge;
        uint balance;
        uint derivedBalance;
        userGaugeTokenData[] userRewards;
    }

    // user earned per token for feeDist
    struct userBribeTokenData {
        address token;
        uint earned;
    }

    struct userFeeDistData {
        address feeDistributor;
        userBribeTokenData[] bribeData;
    }
    // the amount of nested structs for bribe lmao
    struct userBribeData {
        uint tokenId;
        userFeeDistData[] feeDistRewards;
    }

    struct userVeData {
        uint tokenId;
        uint lockedAmount;
        uint votingPower;
        uint lockEnd;
    }

    struct userData {
        userGaugeRewardData[] gaugeRewards;
        userBribeData[] bribeRewards;
        userVeData[] veNFTData;
    }

    function initialize(IVoter _voter, address _router) initializer external {
        voter = _voter;
        router = _router;
        ve = IVotingEscrow(voter._ve());
        minter = IMinter(voter.minter());
    }

    /**
    * @notice returns the pool factory address
    */
    function poolFactory() public view returns (address pool) {
        pool = voter.factory();
    }

    /**
    * @notice returns the gauge factory address
    */
    function gaugeFactory() public view returns (address _gaugeFactory) {
        _gaugeFactory = voter.gaugefactory();
    }

    /**
    * @notice returns ram address
    */
    function ramAddress() public view returns (address ram) {
        ram = ve.token();
    }

    /**
    * @notice returns the voter address
    */
    function voterAddress() public view returns (address _voter) {
        _voter = address(voter);
    }

    /**
    * @notice returns rewardsDistributor address
    */
    function rewardsDistributor() public view returns (address _rewardsDistributor) {
        _rewardsDistributor = minter._rewards_distributor();
    }

    /**
    * @notice returns the minter address
    */
    function minterAddress() public view returns (address _minter) {
        _minter = address(minter);
    }

    /**
    * @notice returns Ramses core contract addresses
    */
    function protocolMetadata()
        external
        view
        returns (ProtocolMetadata memory)
    {
        return
            ProtocolMetadata({
                veAddress: voter._ve(),
                voterAddress: voterAddress(),
                ramAddress: ramAddress(),
                poolsFactoryAddress: poolFactory(),
                gaugesFactoryAddress: gaugeFactory(),
                minterAddress: minterAddress()
            });
    }

    /**
    * @notice returns all Ramses pool addresses
    */
    function allPools() public view returns (address[] memory pools) {
        IPairFactory _factory = IPairFactory(poolFactory());
        uint len = _factory.allPairsLength();

        pools = new address[](len);
        for(uint i; i < len; ++i) {
            pools[i] = _factory.allPairs(i);
        }
    }

    /**
    * @notice returns all Ramses pools that have active gauges
    */
    function allActivePools() public view returns (address[] memory pools) {
        uint len = voter.length();
        pools = new address[](len);

        for(uint i; i < len; ++i) {
            pools[i] = voter.pools(i);
        }
    }

    /**
    * @notice returns the gauge address for a pool
    * @param pool pool address to check
    */
    function gaugeForPool(address pool) public view returns (address gauge) {
        gauge = voter.gauges(pool);
    }

    /**
    * @notice returns the feeDistributor address for a pool
    * @param pool pool address to check
    */
    function feeDistributorForPool(address pool) public view returns (address feeDistributor) {
        address gauge = gaugeForPool(pool);
        feeDistributor = voter.feeDistributers(gauge);
    }

    /**
    * @notice returns current fee rate of a ramses pool
    * @param pool pool address to check
    */
    function pairBips(address pool) public view returns (uint bps) {
        bps = IPairFactory(poolFactory()).pairFee(pool);
    }

    /**
    * @notice returns useful information for a pool
    * @param pool pool address to check
    */
    function poolInfo(address pool) public view returns (Pool memory _poolInfo) {
        IPair pair = IPair(pool);
        _poolInfo.id = pool;
        _poolInfo.symbol = pair.symbol();
        (_poolInfo.token0, _poolInfo.token1) = pair.tokens();
        _poolInfo.gauge = gaugeForPool(pool);
        _poolInfo.feeDistributor = feeDistributorForPool(pool);
        _poolInfo.pairFees = pair.fees();
        _poolInfo.pairBps = pairBips(pool);
    }

    /**
    * @notice returns useful information for all Ramses pools
    */
    function allPoolsInfo() public view returns (Pool[] memory _poolsInfo) {
        address[] memory pools = allPools();
        uint len = pools.length;

        _poolsInfo = new Pool[](len);
        for(uint i; i < len; ++i) {
            _poolsInfo[i] = poolInfo(pools[i]);
        }
    }
    
    /**
    * @notice returns the gauge address for all active pairs
    */
    function allGauges() public view returns (address[] memory gauges) {
        address[] memory pools = allActivePools();
        uint len = pools.length;
        gauges = new address[](len);

        for(uint i; i < len; ++i) {
            gauges[i] = gaugeForPool(pools[i]);
        }
    }

    /**
    * @notice returns the feeDistributor address for all active pairs
    */
    function allFeeDistributors() public view returns (address[] memory feeDistributors) {
        address[] memory pools = allActivePools();
        uint len = pools.length;
        feeDistributors = new address[](len);

        for(uint i; i < len; ++i) {
            feeDistributors[i] = feeDistributorForPool(pools[i]);
        }
    }

    /**
    * @notice returns all reward tokens for the fee distributor of a pool
    * @param pool pool address to check
    */
    function bribeRewardsForPool(address pool) public view returns (address[] memory rewards) {
        IFeeDistributor feeDist = IFeeDistributor(feeDistributorForPool(pool));
        rewards = feeDist.getRewardTokens();
    }

    /**
    * @notice returns all reward tokens for the gauge of a pool
    * @param pool pool address to check
    */
    function gaugeRewardsForPool(address pool) public view returns (address[] memory rewards) {
        IGauge gauge = IGauge(gaugeForPool(pool));
        if (address(gauge) == address(0)) return rewards;

        uint len = gauge.rewardsListLength();
        rewards = new address[](len);
        for(uint i; i < len; ++i) {
            rewards[i] = gauge.rewards(i);
        }
    }

    /**
     * @notice returns gauge staking data of a user
     * @dev derivedBalance is taken from `derivedBalances` in gauge
     * @param user the account address of the user to check
     * @param pool the pool address
     */
    function stakingPositionOf(
        address user,
        address pool
    ) public view returns (userGaugeRewardData memory rewardsData) {
        IGauge gauge = IGauge(gaugeForPool(pool));
        if (address(gauge) == address(0)) {
            return rewardsData;
        }

        address[] memory rewards = gaugeRewardsForPool(pool);
        uint len = rewards.length;

        rewardsData.gauge = address(gauge);
        rewardsData.balance = gauge.balanceOf(user);
        rewardsData.derivedBalance = gauge.derivedBalances(user);
        userGaugeTokenData[] memory _userRewards = new userGaugeTokenData[](len);
        
        for (uint i; i < len; ++i) {
            _userRewards[i].token = rewards[i];
            _userRewards[i].earned = gauge.earned(rewards[i], user);
        }
        rewardsData.userRewards = _userRewards;
    }

    /**
     * @notice returns staking data of a user for multiple pools
     * @param user the account address of the user to check
     * @param pools array of pool addresses
     */
    function stakingPositionsOf(
        address user,
        address[] memory pools
    ) public view returns (userGaugeRewardData[] memory rewardsData) {
        uint len = pools.length;
        rewardsData = new userGaugeRewardData[](len);

        for (uint i; i < len; ++i) {
            rewardsData[i] = stakingPositionOf(user, pools[i]);
        }
    }

    /**
     * @notice returns staking data of all a users positions
     * @dev this is a brute force method, it iterates all pools and checks if balance or rewards > 0. It can run out of gas
     * @dev it is recommended to use `stakingPositionsOf()` if pools positions are already known
     * @param user the account address of the user to check
     */
    function allStakingPositionsOf(
        address user
    ) public view returns (userGaugeRewardData[] memory rewardsData) {
        address[] memory pools = allActivePools();
        uint len = pools.length;
        userGaugeRewardData[] memory _rewardsData = stakingPositionsOf(
            user,
            pools
        );

        uint x;
        for (uint i; i < len; ++i) {
            if (_rewardsData[i].userRewards.length > 0) {
                if (
                    _rewardsData[i].balance > 0 ||
                    _rewardsData[i].userRewards[0].earned > 0
                ) {
                    // only checks ram
                    ++x;
                }
            }
        }
        rewardsData = new userGaugeRewardData[](x);
        uint j;
        for (uint i; i < len; ++i) {
            if (_rewardsData[i].userRewards.length > 0) {
                if (
                    _rewardsData[i].balance > 0 ||
                    _rewardsData[i].userRewards[0].earned > 0
                ) {
                    // only checks ram
                    rewardsData[j] = _rewardsData[i];
                    ++j;
                }
            }
        }
    }

    /**
    * @notice returns all token id's of a user
    * @param user account address to check
    */
    function veNFTsOf(address user) public view returns (uint[] memory NFTs) {
        uint len = ve.balanceOf(user);
        NFTs = new uint[](len);

        for(uint i; i < len; ++i) {
            NFTs[i] = ve.tokenOfOwnerByIndex(user, i);
        }
    }

    /**
     * @notice returns bribes data of a token id per pool
     * @param tokenId the veNFT token id to check
     * @param pool the pool address
     */
    function bribesPositionOf(
        uint tokenId,
        address pool
    ) public view returns (userFeeDistData memory rewardsData) {
        IFeeDistributor feeDist = IFeeDistributor(feeDistributorForPool(pool));
        if (address(feeDist) == address(0)) {
            return rewardsData;
        }

        address[] memory rewards = bribeRewardsForPool(pool);
        uint len = rewards.length;

        rewardsData.feeDistributor = address(feeDist);
        userBribeTokenData[] memory _userRewards = new userBribeTokenData[](len);
        
        for (uint i; i < len; ++i) {
            _userRewards[i].token = rewards[i];
            _userRewards[i].earned = feeDist.earned(rewards[i], tokenId);
        }
        rewardsData.bribeData = _userRewards;
    }

    /**
    * @notice returns bribes data of a token id for multiple pools
    * @param tokenId the veNFT token id to check
    * @param pools pools addresses
    */
    function bribesPositionsOf(uint tokenId, address[] memory pools) public view returns (userFeeDistData[] memory rewardsData) {
        uint len = pools.length;
        rewardsData = new userFeeDistData[](len);

        for(uint i; i < len; ++i) {
            rewardsData[i] = bribesPositionOf(tokenId, pools[i]);
        }
    }

    /**
    * @notice returns bribes data of a user for multiple pools
    * @notice not removing 0 values here
    * @param user account address of the user
    * @param pools pools addresses
    */
    function bribesPositionsOf(address user, address[] memory pools) public view returns (userBribeData[] memory rewardsData) {
        uint[] memory ids = veNFTsOf(user);
        rewardsData = new userBribeData[](ids.length);

        for(uint i; i < ids.length; ++i) {
            rewardsData[i].tokenId = ids[i];
            rewardsData[i].feeDistRewards = bribesPositionsOf(ids[i], pools);
        }
    }

    /**
    * @notice returns all bribes positions of a user
    * @notice not removing 0 values here, costs too much gas (many nodes limit gas for read functions)
    * @param user account address of the user
    */
    function allBribesPositions(address user) public view returns (userBribeData[] memory rewardsData) {
        address[] memory pools = allActivePools();
        uint[] memory ids = veNFTsOf(user);
        rewardsData = new userBribeData[](ids.length);
        
        for(uint i; i < ids.length; ++i) {
            rewardsData[i].tokenId = ids[i];
            rewardsData[i].feeDistRewards = bribesPositionsOf(ids[i], pools);
        }
    }

    /**
     * @notice returns gauge reward data for a Ramses pool
     * @param pool Ramses pool address
     */
    function poolRewardsData(
        address pool
    ) public view returns (gaugeRewardsData memory rewardData) {
        address gauge = gaugeForPool(pool);
        if (gauge == address(0)) {
            return rewardData;
        }

        address[] memory rewards = gaugeRewardsForPool(pool);
        uint len = rewards.length;
        tokenRewardData[] memory _rewardData = new tokenRewardData[](len);

        for (uint i; i < len; ++i) {
            _rewardData[i].token = rewards[i];
            _rewardData[i].rewardRate = IGauge(gauge).rewardRate(rewards[i]);
        }
        rewardData.gauge = gauge;
        rewardData.rewardData = _rewardData;
    }

    /**
     * @notice returns gauge reward data for multiple ramses pools
     * @param pools Ramses pools addresses
     */
    function poolsRewardsData(
        address[] memory pools
    ) public view returns (gaugeRewardsData[] memory rewardsData) {
        uint len = pools.length;
        rewardsData = new gaugeRewardsData[](len);

        for (uint i; i < len; ++i) {
            rewardsData[i] = poolRewardsData(pools[i]);
        }
    }

    /**
     * @notice returns gauge reward data for all ramses pools
     */
    function allPoolsRewardData()
        public
        view
        returns (gaugeRewardsData[] memory rewardsData)
    {
        address[] memory pools =  allActivePools();
        rewardsData = poolsRewardsData(pools);
    }

    /**
    * @notice returns veNFT lock data for a token id
    * @param user account address of the user
    */
    function vePositionsOf(address user) public view returns (userVeData[] memory veData) {
        uint[] memory ids = veNFTsOf(user);
        uint len = ids.length;
        veData = new userVeData[](len);

        for(uint i; i < len; ++i) {
            veData[i].tokenId = ids[i];
            IVotingEscrow.LockedBalance memory _locked = ve.locked(ids[i]);
            veData[i].lockedAmount = uint(int(_locked.amount));
            veData[i].lockEnd = _locked.end;
            veData[i].votingPower = ve.balanceOfNFT(ids[i]);
        }
    }

    /**
    * @notice returns all reward info for a user
    * @notice this is a very gas heavy function and may not be as efficient or quick to call
    * @notice very likely to get an evm timeout with this function
    * @param user the account address of the user
    */
    function userInfo(address user) public view returns (userData memory _userInfo) {
        _userInfo.gaugeRewards = allStakingPositionsOf(user);
        _userInfo.bribeRewards = allBribesPositions(user);
        _userInfo.veNFTData = vePositionsOf(user);
    }
    
}
