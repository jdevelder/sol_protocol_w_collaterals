// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// decentralized lending platform that handles lending, borrowing, and repayment
// uses mytoken for all transactions and calculates interest based on loan duration
contract LendingPlatform is ReentrancyGuard {
    
    // main contract variables
    IERC20 public token;
    uint256 public interestRate;
    
    // track user balances and borrow information
    mapping(address => uint256) public lendingBalances;
    mapping(address => uint256) public borrowingBalances;
    mapping(address => uint256) public borrowStartTime;
    
    // events for tracking all major operations
    event TokensLent(address indexed lender, uint256 amount);
    event TokensBorrowed(address indexed borrower, uint256 amount);
    event TokensRepaid(address indexed borrower, uint256 amount, uint256 interest);
    
    // constructor initializes the lending platform with token and interest rate
    constructor(IERC20 _token, uint256 _interestRate) {
        require(address(_token) != address(0), "Token address cannot be zero");
        require(_interestRate > 0 && _interestRate <= 100, "Interest rate must be between 1 and 100");
        
        token = _token;
        interestRate = _interestRate;
    }
    
    // validates that amount is greater than zero
    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "Amount must be greater than zero");
        _;
    }
    
    // checks if user has outstanding borrowed amount to repay
    modifier hasBorrowingBalance() {
        require(borrowingBalances[msg.sender] > 0, "No borrowing balance to repay");
        _;
    }
    
    // allows users to lend tokens to the platform
    // users must approve contract to spend tokens before calling this function
    function lend(uint256 _amount) public validAmount(_amount) nonReentrant {
        // check user has sufficient balance and approved the contract
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient token balance");
        require(token.allowance(msg.sender, address(this)) >= _amount, "Insufficient allowance");
        
        // transfer tokens from user to contract using transferFrom
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        
        // update user's lending balance
        lendingBalances[msg.sender] += _amount;
        
        emit TokensLent(msg.sender, _amount);
    }
    
    // allows users to borrow tokens from the platform
    // this version doesn't require collateral as specified
    function borrow(uint256 _amount) public validAmount(_amount) nonReentrant {
        // check contract has enough tokens to lend
        require(token.balanceOf(address(this)) >= _amount, "Insufficient tokens in platform");
        
        // ensure user doesn't have outstanding loan
        require(borrowingBalances[msg.sender] == 0, "Outstanding loan must be repaid first");
        
        // record borrowing details using msg.sender and block.timestamp
        borrowingBalances[msg.sender] = _amount;
        borrowStartTime[msg.sender] = block.timestamp;
        
        // transfer tokens from contract to user
        require(token.transfer(msg.sender, _amount), "Token transfer failed");
        
        emit TokensBorrowed(msg.sender, _amount);
    }
    
    // allows users to repay borrowed tokens with interest
    // calculates interest based on loan duration
    function repay() public hasBorrowingBalance nonReentrant {
        uint256 borrowedAmount = borrowingBalances[msg.sender];
        uint256 borrowDuration = block.timestamp - borrowStartTime[msg.sender];
        
        // calculate interest using duration and interest rate
        uint256 interest = calculateInterest(borrowedAmount, borrowDuration);
        uint256 totalRepayment = borrowedAmount + interest;
        
        // check user can afford repayment
        require(token.balanceOf(msg.sender) >= totalRepayment, "Insufficient balance for repayment");
        require(token.allowance(msg.sender, address(this)) >= totalRepayment, "Insufficient allowance for repayment");
        
        // transfer repayment from user to contract
        require(token.transferFrom(msg.sender, address(this), totalRepayment), "Repayment transfer failed");
        
        // reset user's borrowing state
        borrowingBalances[msg.sender] = 0;
        borrowStartTime[msg.sender] = 0;
        
        emit TokensRepaid(msg.sender, borrowedAmount, interest);
    }
    
    // calculates interest on borrowed amount based on duration
    // uses formula: amount * interestRate * duration / (365 days * 100)
    function calculateInterest(uint256 _amount, uint256 _duration) internal view returns (uint256) {
        // interest calculation using seconds for precision
        return (_amount * interestRate * _duration) / (365 days * 100);
    }
    
    // preview interest calculation for users
    function previewInterest(uint256 _amount, uint256 _duration) public view returns (uint256) {
        return calculateInterest(_amount, _duration);
    }
    
    // get total repayment amount including interest for current loan
    function getTotalRepaymentAmount(address _user) public view returns (uint256) {
        if (borrowingBalances[_user] == 0) {
            return 0;
        }
        
        uint256 borrowedAmount = borrowingBalances[_user];
        uint256 borrowDuration = block.timestamp - borrowStartTime[_user];
        uint256 interest = calculateInterest(borrowedAmount, borrowDuration);
        
        return borrowedAmount + interest;
    }
    
    // get contract's token balance
    function getContractBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }
    
    // get user's lending balance
    function getUserLendingBalance(address _user) public view returns (uint256) {
        return lendingBalances[_user];
    }
    
    // get user's borrowing balance
    function getUserBorrowingBalance(address _user) public view returns (uint256) {
        return borrowingBalances[_user];
    }
}