// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract PIRGSStaking {
    IBEP20 public stakingToken; // Token used for staking (PIRGS)
    IBEP20 public rewardToken;  // Token used for rewards (same as stakingToken)

    address public owner;
    uint256 public totalRewards = 200_000_000_000 * 10 ** 18; // 200 billion PIRGS allocated for rewards

    // Structure representing a staking option
    struct StakingOption {
        uint256 lockTime; // Lock duration in seconds
        uint256 rewardRate; // Annual reward percentage (e.g., 10 = 10%)
    }

    StakingOption[] public stakingOptions;

    // Structure representing a user's stake
    struct Stake {
        uint256 amount;        // Amount of staked tokens
        uint256 rewardDebt;    // Rewards accrued but not yet claimed
        uint256 lockTime;      // Lock duration for the stake
        uint256 stakeStart;    // Timestamp when the stake started
    }

    mapping(address => Stake[]) public stakes;

    event Staked(address indexed user, uint256 amount, uint256 optionIndex);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor(IBEP20 _stakingToken, IBEP20 _rewardToken) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        owner = msg.sender;

        // Adding staking options (lock time in seconds, APY percentage)
        stakingOptions.push(StakingOption(30 days, 10));  // 1 month - 10% APY
        stakingOptions.push(StakingOption(180 days, 20)); // 6 months - 20% APY
        stakingOptions.push(StakingOption(365 days, 30)); // 12 months - 30% APY
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function stake(uint256 amount, uint256 optionIndex) external {
        require(optionIndex < stakingOptions.length, "Invalid staking option");
        require(amount > 0, "Amount must be greater than 0");

        StakingOption memory option = stakingOptions[optionIndex];
        
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        stakes[msg.sender].push(Stake({
            amount: amount,
            rewardDebt: 0,
            lockTime: option.lockTime,
            stakeStart: block.timestamp
        }));

        emit Staked(msg.sender, amount, optionIndex);
    }

    function withdraw(uint256 stakeIndex) external {
        Stake storage userStake = stakes[msg.sender][stakeIndex];
        require(block.timestamp >= userStake.stakeStart + userStake.lockTime, "Stake is still locked");

        uint256 amount = userStake.amount;
        uint256 reward = calculateReward(msg.sender, stakeIndex);

        userStake.amount = 0;
        userStake.rewardDebt = 0;

        require(stakingToken.transfer(msg.sender, amount), "Token transfer failed");
        require(rewardToken.transfer(msg.sender, reward), "Reward transfer failed");

        emit Withdrawn(msg.sender, amount);
        emit RewardClaimed(msg.sender, reward);
    }

    function calculateReward(address user, uint256 stakeIndex) public view returns (uint256) {
        Stake memory userStake = stakes[user][stakeIndex];
        StakingOption memory option;

        // Matching the staking option based on lock time
        for (uint256 i = 0; i < stakingOptions.length; i++) {
            if (stakingOptions[i].lockTime == userStake.lockTime) {
                option = stakingOptions[i];
                break;
            }
        }

        uint256 timeElapsed = block.timestamp - userStake.stakeStart;
        uint256 annualReward = (userStake.amount * option.rewardRate) / 100;
        uint256 reward = (annualReward * timeElapsed) / 365 days;

        return reward;
    }

    function fundRewards(uint256 amount) external onlyOwner {
        require(rewardToken.transferFrom(msg.sender, address(this), amount), "Funding failed");
        totalRewards += amount;
    }

    function setStakingOption(uint256 lockTime, uint256 rewardRate) external onlyOwner {
        stakingOptions.push(StakingOption(lockTime, rewardRate));
    }

    function getStakes(address user) external view returns (Stake[] memory) {
        return stakes[user];
    }
}
