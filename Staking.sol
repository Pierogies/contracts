// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

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

contract PIRGSStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IBEP20;
    using SafeMath for uint256;

    IBEP20 public immutable stakingToken;
    IBEP20 public immutable rewardToken;

    // Staking configurations
    uint256 public constant MAX_TOTAL_REWARDS = 500_000_000_000 * 10 ** 18; // 500 billion cap
    uint256 public constant MAX_STAKE_PER_USER = 1_000_000 * 10 ** 18; // 1 million token max stake
    uint256 public totalRewards;

    // Structure representing a staking option
    struct StakingOption {
        uint256 lockTime;      // Lock duration in seconds
        uint256 rewardRate;    // Annual reward percentage (e.g., 10 = 10%)
        bool isActive;         // Option can be used for staking
    }

    // Structure representing a user's stake
    struct Stake {
        uint256 amount;        // Amount of staked tokens
        uint256 rewardDebt;    // Rewards accrued but not yet claimed
        uint256 lockTime;      // Lock duration for the stake
        uint256 stakeStart;    // Timestamp when the stake started
        uint256 optionIndex;   // Staking option used
    }

    StakingOption[] public stakingOptions;
    mapping(address => Stake[]) public userStakes;
    mapping(address => uint256) public totalUserStaked;

    // Events
    event StakingOptionAdded(uint256 indexed optionIndex, uint256 lockTime, uint256 rewardRate);
    event StakingOptionUpdated(uint256 indexed optionIndex, uint256 lockTime, uint256 rewardRate, bool isActive);
    event Staked(address indexed user, uint256 amount, uint256 optionIndex, uint256 stakeId);
    event Unstaked(address indexed user, uint256 amount, uint256 reward, uint256 stakeId);
    event EmergencyUnstaked(address indexed user, uint256 amount, uint256 stakeId);
    event RewardFunded(uint256 amount, uint256 totalRewards);
    event RewardsClaimed(address indexed user, uint256 reward);

    constructor(IBEP20 _stakingToken, IBEP20 _rewardToken) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;

        // Initial staking options
        stakingOptions.push(StakingOption(30 days, 10, true));    // 1 month - 10% APY
        stakingOptions.push(StakingOption(180 days, 20, true));   // 6 months - 20% APY
        stakingOptions.push(StakingOption(365 days, 30, true));   // 12 months - 30% APY
    }

    function stake(uint256 amount, uint256 optionIndex) external nonReentrant {
        // Validate stake parameters
        require(optionIndex < stakingOptions.length, "Invalid staking option");
        require(amount > 0, "Stake amount must be positive");
        
        StakingOption memory option = stakingOptions[optionIndex];
        require(option.isActive, "Staking option is not active");

        // Check total user stake limit
        uint256 newTotalStake = totalUserStaked[msg.sender].add(amount);
        require(newTotalStake <= MAX_STAKE_PER_USER, "Exceeds max stake limit");

        // Transfer tokens to contract
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Create new stake
        userStakes[msg.sender].push(Stake({
            amount: amount,
            rewardDebt: 0,
            lockTime: option.lockTime,
            stakeStart: block.timestamp,
            optionIndex: optionIndex
        }));

        // Update total user stake
        totalUserStaked[msg.sender] = newTotalStake;

        emit Staked(msg.sender, amount, optionIndex, userStakes[msg.sender].length - 1);
    }

    function unstake(uint256 stakeIndex) external nonReentrant {
        Stake storage userStake = userStakes[msg.sender][stakeIndex];
        
        // Validate unstaking conditions
        require(block.timestamp >= userStake.stakeStart.add(userStake.lockTime), "Stake is locked");
        require(userStake.amount > 0, "No stake to withdraw");

        uint256 stakeAmount = userStake.amount;
        uint256 reward = calculateReward(msg.sender, stakeIndex);

        // Verify reward availability
        require(rewardToken.balanceOf(address(this)) >= reward, "Insufficient rewards");

        // Update state before transfers
        totalUserStaked[msg.sender] = totalUserStaked[msg.sender].sub(stakeAmount);
        
        // Remove stake by replacing with last stake and popping
        userStakes[msg.sender][stakeIndex] = userStakes[msg.sender][userStakes[msg.sender].length - 1];
        userStakes[msg.sender].pop();

        // Transfer stake and reward
        stakingToken.safeTransfer(msg.sender, stakeAmount);
        rewardToken.safeTransfer(msg.sender, reward);

        emit Unstaked(msg.sender, stakeAmount, reward, stakeIndex);
        emit RewardsClaimed(msg.sender, reward);
    }

    function emergencyUnstake(uint256 stakeIndex) external nonReentrant {
        Stake storage userStake = userStakes[msg.sender][stakeIndex];
        
        require(userStake.amount > 0, "No stake to withdraw");

        uint256 stakeAmount = userStake.amount;
        
        // Penalize by removing stake without rewards
        totalUserStaked[msg.sender] = totalUserStaked[msg.sender].sub(stakeAmount);
        
        // Remove stake by replacing with last stake and popping
        userStakes[msg.sender][stakeIndex] = userStakes[msg.sender][userStakes[msg.sender].length - 1];
        userStakes[msg.sender].pop();

        // Transfer only stake amount
        stakingToken.safeTransfer(msg.sender, stakeAmount);

        emit EmergencyUnstaked(msg.sender, stakeAmount, stakeIndex);
    }

    function calculateReward(address user, uint256 stakeIndex) public view returns (uint256) {
        Stake memory userStake = userStakes[user][stakeIndex];
        StakingOption memory option = stakingOptions[userStake.optionIndex];

        uint256 timeElapsed = block.timestamp > userStake.stakeStart.add(userStake.lockTime) 
            ? userStake.lockTime 
            : block.timestamp.sub(userStake.stakeStart);

        uint256 annualReward = userStake.amount.mul(option.rewardRate).div(100);
        uint256 reward = annualReward.mul(timeElapsed).div(365 days);

        return reward;
    }

    // Owner functions for managing the contract
    function addStakingOption(uint256 lockTime, uint256 rewardRate) external onlyOwner {
        require(lockTime > 0, "Invalid lock time");
        require(rewardRate > 0, "Invalid reward rate");

        stakingOptions.push(StakingOption(lockTime, rewardRate, true));
        emit StakingOptionAdded(stakingOptions.length - 1, lockTime, rewardRate);
    }

    function updateStakingOption(uint256 optionIndex, uint256 lockTime, uint256 rewardRate, bool isActive) 
        external 
        onlyOwner 
    {
        require(optionIndex < stakingOptions.length, "Invalid option index");
        require(lockTime > 0, "Invalid lock time");
        require(rewardRate > 0, "Invalid reward rate");

        stakingOptions[optionIndex].lockTime = lockTime;
        stakingOptions[optionIndex].rewardRate = rewardRate;
        stakingOptions[optionIndex].isActive = isActive;

        emit StakingOptionUpdated(optionIndex, lockTime, rewardRate, isActive);
    }

    function fundRewards(uint256 amount) external onlyOwner {
        require(totalRewards.add(amount) <= MAX_TOTAL_REWARDS, "Exceeds maximum reward pool");
        
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        totalRewards = totalRewards.add(amount);

        emit RewardFunded(amount, totalRewards);
    }

    function rescueTokens(IBEP20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to rescue");
        
        // Exclude staking and reward tokens
        if (token == stakingToken || token == rewardToken) {
            uint256 protectedBalance = stakingToken.balanceOf(address(this)).sub(totalUserStaked[msg.sender]);
            balance = balance.sub(protectedBalance);
        }

        token.safeTransfer(owner(), balance);
    }

    // Getter functions
    function getUserStakes(address user) external view returns (Stake[] memory) {
        return userStakes[user];
    }

    function getStakingOptionsCount() external view returns (uint256) {
        return stakingOptions.length;
    }
}
