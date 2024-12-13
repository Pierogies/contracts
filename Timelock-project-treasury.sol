// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IBEP20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MultiStageTimelock {
    IBEP20 public immutable token; // Token to be locked
    address public immutable beneficiary; // Address that will receive the tokens
    uint256 public immutable firstReleaseTime; // Timestamp for the first release (50%)
    uint256 public immutable secondReleaseTime; // Timestamp for the second release (50%)
    uint256 public totalLocked; // Total amount of tokens locked
    bool public firstReleaseClaimed; // Whether the first release has been claimed
    bool public secondReleaseClaimed; // Whether the second release has been claimed

    // Events for improved transparency
    event TokensFunded(uint256 amount, address funder);
    event TokensReleased(uint256 amount, uint256 releaseStage);
    event EmergencyWithdrawal(address recipient, uint256 amount);

    constructor(
        IBEP20 _token,
        address _beneficiary,
        uint256 _firstReleaseTime,
        uint256 _secondReleaseTime
    ) {
        require(_firstReleaseTime > block.timestamp, "First release time must be in the future");
        require(_secondReleaseTime > _firstReleaseTime, "Second release time must be after the first release time");
        
        token = _token;
        beneficiary = _beneficiary;
        firstReleaseTime = _firstReleaseTime;
        secondReleaseTime = _secondReleaseTime;
    }

    // Fund the timelock contract with the locked amount
    function fund(uint256 amount) external {
        require(totalLocked == 0, "Already funded");
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Funding failed"
        );
        totalLocked = amount;
        
        emit TokensFunded(amount, msg.sender);
    }

    // Release tokens in two stages
    function release() external {
        require(msg.sender == beneficiary, "Only beneficiary can release tokens");
        
        uint256 releaseAmount = 0;
        
        if (block.timestamp >= firstReleaseTime && !firstReleaseClaimed) {
            releaseAmount = totalLocked / 2; // 50% of the locked tokens
            firstReleaseClaimed = true;
            require(token.transfer(beneficiary, releaseAmount), "First release failed");
            
            emit TokensReleased(releaseAmount, 1);
        }
        
        if (block.timestamp >= secondReleaseTime && !secondReleaseClaimed) {
            releaseAmount = totalLocked / 2; // Remaining 50%
            secondReleaseClaimed = true;
            require(token.transfer(beneficiary, releaseAmount), "Second release failed");
            
            emit TokensReleased(releaseAmount, 2);
        }
        
        require(releaseAmount > 0, "No tokens available for release");
    }

    // Emergency withdrawal function for contract owner (optional)
    function emergencyWithdraw() external {
        require(
            block.timestamp > secondReleaseTime && 
            (!firstReleaseClaimed || !secondReleaseClaimed), 
            "Cannot withdraw before release times or after full release"
        );
        
        uint256 remainingBalance = token.balanceOf(address(this));
        require(remainingBalance > 0, "No tokens to withdraw");
        
        require(token.transfer(beneficiary, remainingBalance), "Withdrawal failed");
        
        emit EmergencyWithdrawal(beneficiary, remainingBalance);
    }

    // View function to check remaining locked tokens
    function getRemainingLockedTokens() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
