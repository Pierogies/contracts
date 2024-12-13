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
    uint256 public firstReleaseClaimed; // Whether the first release has been claimed
    uint256 public secondReleaseClaimed; // Whether the second release has been claimed

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
    }

    // Release tokens in two stages
    function release() external {
        require(msg.sender == beneficiary, "Only beneficiary can release tokens");

        if (block.timestamp >= firstReleaseTime && firstReleaseClaimed == 0) {
            uint256 firstAmount = totalLocked / 2; // 50% of the locked tokens
            firstReleaseClaimed = 1;
            require(token.transfer(beneficiary, firstAmount), "First release failed");
        }

        if (block.timestamp >= secondReleaseTime && secondReleaseClaimed == 0) {
            uint256 secondAmount = totalLocked / 2; // Remaining 50%
            secondReleaseClaimed = 1;
            require(token.transfer(beneficiary, secondAmount), "Second release failed");
        }

        require(
            firstReleaseClaimed == 1 || secondReleaseClaimed == 1,
            "No tokens available for release"
        );
    }
}
