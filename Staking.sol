// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Staking is ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    IERC20 public token;
    uint256 public constant MAX_TOTAL_REWARDS = 250_000_000_000 * 10**18;
    uint256 public totalRewardsPaid;

    enum StakeDuration {
        OneMonth,
        SixMonths,
        TwelveMonths
    }

    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 apy;
        StakeDuration duration;
    }

    mapping(address => Stake[]) public stakes;

    constructor(address _tokenAddress) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Invalid token address");
        token = IERC20(_tokenAddress);
    }

    function stake(uint256 amount, StakeDuration duration) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        
        require(
            token.allowance(msg.sender, address(this)) >= amount, 
            "Insufficient token allowance"
        );

        require(
            token.transferFrom(msg.sender, address(this), amount), 
            "Token transfer failed"
        );

        uint256 apy;
        if (duration == StakeDuration.OneMonth) {
            apy = 10; // 10% APY
        } else if (duration == StakeDuration.SixMonths) {
            apy = 20; // 20% APY
        } else if (duration == StakeDuration.TwelveMonths) {
            apy = 30; // 30% APY
        }

        stakes[msg.sender].push(Stake({
            amount: amount,
            timestamp: block.timestamp,
            apy: apy,
            duration: duration
        }));
    }

    function calculateRewards(Stake memory _stake) internal view returns (uint256) {
        uint256 stakingPeriod = block.timestamp.sub(_stake.timestamp) / 30 days;
        uint256 rewards = _stake.amount.mul(_stake.apy).mul(stakingPeriod).div(100);
        return rewards;
    }

    function unstake(uint256 _stakeIndex) external nonReentrant {
        require(_stakeIndex < stakes[msg.sender].length, "Invalid stake index");
        
        Stake storage userStake = stakes[msg.sender][_stakeIndex];
        uint256 rewards = calculateRewards(userStake);
        
        require(
            totalRewardsPaid.add(rewards) <= MAX_TOTAL_REWARDS, 
            "Rewards exceed maximum allocation"
        );

        uint256 totalAmount = userStake.amount.add(rewards);
        totalRewardsPaid = totalRewardsPaid.add(rewards);

        // Replace the unstaked stake with the last one and pop the array
        stakes[msg.sender][_stakeIndex] = stakes[msg.sender][stakes[msg.sender].length - 1];
        stakes[msg.sender].pop();

        require(
            token.transfer(msg.sender, totalAmount), 
            "Token transfer failed"
        );
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }

    function migrateStakes(address[] calldata users, Stake[] calldata userStakes) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            stakes[users[i]].push(userStakes[i]);
        }
    }
}
