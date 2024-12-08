// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Minimal interface for BEP-20 (compatible with ERC-20)
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

// BEP-20 token implementation
contract BEP20Token is IBEP20 {
    // Token details
    string public name = "Pierogies";      // Name of the token
    string public symbol = "PIRGS";      // Symbol of the token
    uint8 public decimals = 18;           // Decimal places (18 is standard for most tokens)
    uint256 public totalSupply;           // Total token supply

    // Mappings for balances and allowances
    mapping(address => uint256) public _balances;
    mapping(address => mapping(address => uint256)) public _allowances;

    // Owner of the contract
    address public owner;

    // Constructor to initialize the token supply and assign it to the owner
    constructor() {
        owner = msg.sender; // Set the contract deployer as the owner
        totalSupply = 1_000_000_000_000 * 10 ** decimals; // Initial supply: 1 trillion tokens
        _balances[owner] = totalSupply; // Assign all tokens to the owner's balance
        emit Transfer(address(0), owner, totalSupply); // Emit a transfer event from the zero address (minting)
    }

    // Return the balance of a specific account
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    // Transfer tokens from the sender to a recipient
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    // Return the allowance for a spender on behalf of an owner
    function allowance(address _owner, address spender) external view override returns (uint256) {
        return _allowances[_owner][spender];
    }

    // Approve a spender to spend a specific amount on behalf of the sender
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    // Transfer tokens on behalf of a sender, using the allowance mechanism
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "Transfer amount exceeds allowance");
        _approve(sender, msg.sender, currentAllowance - amount);
        _transfer(sender, recipient, amount);
        return true;
    }

    // Internal function to handle transfers
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(_balances[sender] >= amount, "Transfer amount exceeds balance");

        _balances[sender] -= amount; // Deduct from sender's balance
        _balances[recipient] += amount; // Add to recipient's balance
        emit Transfer(sender, recipient, amount); // Emit a transfer event
    }

    // Internal function to set allowances
    function _approve(address _owner, address spender, uint256 amount) internal {
        require(_owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");

        _allowances[_owner][spender] = amount; // Set the allowance
        emit Approval(_owner, spender, amount); // Emit an approval event
    }

    // Function to burn tokens (reduce total supply)
    function burn(uint256 amount) external {
        uint256 burnAmount = amount * 10 ** decimals; // Convert to smallest unit
        require(_balances[msg.sender] >= burnAmount, "Burn amount exceeds balance");
        totalSupply -= burnAmount; // Decrease total supply
        _balances[msg.sender] -= burnAmount; // Deduct from sender's balance
        emit Transfer(msg.sender, address(0), burnAmount); // Emit a transfer event to the zero address
    }
}
