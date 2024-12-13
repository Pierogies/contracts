// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Importujemy ogólny interfejs ERC20 z OpenZeppelin

contract Staking {
    IERC20 public token;
    address public owner;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 apy; // Annual Percentage Yield
    }

    mapping(address => Stake[]) public stakes;

    // Constructor
    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress); // Pobiera token z podanego adresu
        owner = msg.sender; // Set the deployer as the owner
    }

    // Get the owner address
    function getOwner() external view returns (address) {
        return owner;
    }

    // Stake tokens for a specified duration
    function stake(uint256 _amount, uint256 _duration) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(_duration == 1 || _duration == 6 || _duration == 12, "Invalid staking duration");

        // Transfer tokens from user to staking contract
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "Token transfer failed");

        uint256 apy;
        if (_duration == 1) {
            apy = 10; // 10% APY for 1 month
        } else if (_duration == 6) {
            apy = 20; // 20% APY for 6 months
        } else if (_duration == 12) {
            apy = 30; // 30% APY for 1 year
        }

        // Record the stake
        stakes[msg.sender].push(Stake({
            amount: _amount,
            timestamp: block.timestamp,
            apy: apy
        }));
    }

    // Calculate rewards for a given stake
    function calculateRewards(Stake memory _stake) internal view returns (uint256) {
        uint256 stakingPeriod = (block.timestamp - _stake.timestamp) / 30 days; // in months
        uint256 rewards;

        if (_stake.apy > 0) {
            rewards = _stake.amount * _stake.apy * stakingPeriod / 100; // simple interest calculation
        }

        return rewards;
    }

    // Unstake tokens and claim rewards
    function unstake(uint256 _stakeIndex) external {
        require(_stakeIndex < stakes[msg.sender].length, "Invalid stake index");

        Stake storage userStake = stakes[msg.sender][_stakeIndex];
        uint256 rewards = calculateRewards(userStake);
        uint256 totalAmount = userStake.amount + rewards;

        // Remove the stake from the stakes list
        stakes[msg.sender][_stakeIndex] = stakes[msg.sender][stakes[msg.sender].length - 1];
        stakes[msg.sender].pop();

        // Transfer tokens + rewards back to the user
        bool success = token.transfer(msg.sender, totalAmount);
        require(success, "Token transfer failed");
    }
}
