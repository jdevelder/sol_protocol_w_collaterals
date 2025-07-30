// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// enhanced lending platform that requires ether collateral for borrowing
contract LendingPlatformWithCollateral is ReentrancyGuard {
    
    IERC20 public token;
    uint256 public interestRate;
    uint256 public collateralRatio;         
    
    // track user balances using msg.sender
    mapping(address => uint256) public lendingBalances;
    mapping(address => uint256) public borrowingBalances;
    mapping(address => uint256) public borrowStartTime;    
    mapping(address => uint256) public collateralBalances; 
    
    event TokensLent(address indexed lender, uint256 amount);
    event TokensBorrowed(address indexed borrower, uint256 amount, uint256 collateralUsed);
    event TokensRepaid(address indexed borrower, uint256 amount, uint256 interest);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    
    // constructor initializes token, interest rate, and collateral requirements
    constructor(IERC20 _token, uint256 _interestRate, uint256 _collateralRatio) {
        require(address(_token) != address(0), "Token address cannot be zero");
        require(_interestRate > 0 && _interestRate <= 100, "Interest rate must be between 1 and 100");
        require(_collateralRatio >= 100, "Collateral ratio must be at least 100%");
        
        token = _token;
        interestRate = _interestRate;
        collateralRatio = _collateralRatio;
    }
    
    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "Amount must be greater than zero");
        _;
    }
    
    modifier hasBorrowingBalance() {
        require(borrowingBalances[msg.sender] > 0, "No borrowing balance to repay");
        _;
    }
    
    // deposit ether as collateral using msg.value
    function depositCollateral() public payable validAmount(msg.value) {
        collateralBalances[msg.sender] += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }
    
    // withdraw unused collateral with loan protection
    function withdrawCollateral(uint256 _amount) public validAmount(_amount) nonReentrant {
        require(collateralBalances[msg.sender] >= _amount, "Insufficient collateral balance");
        
        if (borrowingBalances[msg.sender] > 0) {
            uint256 remainingCollateral = collateralBalances[msg.sender] - _amount;
            uint256 requiredCollateral = (borrowingBalances[msg.sender] * collateralRatio) / 100;
            require(remainingCollateral >= requiredCollateral, "Cannot withdraw: would leave insufficient collateral for loan");
        }
        
        collateralBalances[msg.sender] -= _amount;
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Ether transfer failed");
        emit CollateralWithdrawn(msg.sender, _amount);
    }
    
    // lend tokens to platform using transferFrom after approval
    function lend(uint256 _amount) public validAmount(_amount) nonReentrant {
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient token balance");
        require(token.allowance(msg.sender, address(this)) >= _amount, "Insufficient allowance");
        
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        lendingBalances[msg.sender] += _amount;
        emit TokensLent(msg.sender, _amount);
    }
    
    // borrow tokens against ether collateral
    function borrow(uint256 _amount) public validAmount(_amount) nonReentrant {
        require(token.balanceOf(address(this)) >= _amount, "Insufficient tokens in platform");
        require(borrowingBalances[msg.sender] == 0, "Outstanding loan must be repaid first");
        
        // check collateral is sufficient for loan amount
        uint256 requiredCollateral = (_amount * collateralRatio) / 100;
        require(collateralBalances[msg.sender] >= requiredCollateral, "Insufficient collateral for loan amount");
        
        borrowingBalances[msg.sender] = _amount;
        borrowStartTime[msg.sender] = block.timestamp;
        
        require(token.transfer(msg.sender, _amount), "Token transfer failed");
        emit TokensBorrowed(msg.sender, _amount, requiredCollateral);
    }
    
    // repay borrowed tokens with calculated interest
    function repay() public hasBorrowingBalance nonReentrant {
        uint256 borrowedAmount = borrowingBalances[msg.sender];
        uint256 borrowDuration = block.timestamp - borrowStartTime[msg.sender];
        
        uint256 interest = calculateInterest(borrowedAmount, borrowDuration);
        uint256 totalRepayment = borrowedAmount + interest;
        
        require(token.balanceOf(msg.sender) >= totalRepayment, "Insufficient balance for repayment");
        require(token.allowance(msg.sender, address(this)) >= totalRepayment, "Insufficient allowance for repayment");
        require(token.transferFrom(msg.sender, address(this), totalRepayment), "Repayment transfer failed");
        
        borrowingBalances[msg.sender] = 0;
        borrowStartTime[msg.sender] = 0;
        emit TokensRepaid(msg.sender, borrowedAmount, interest);
    }
    
    // interest calculation: amount * rate * duration / (365 days * 100)
    function calculateInterest(uint256 _amount, uint256 _duration) internal view returns (uint256) {
        return (_amount * interestRate * _duration) / (365 days * 100);
    }
    
    // get maximum borrowable amount based on collateral
    function getMaxBorrowableAmount(address _user) public view returns (uint256) {
        if (borrowingBalances[_user] > 0) return 0;
        return (collateralBalances[_user] * 100) / collateralRatio;
    }
    
    // get total repayment amount including interest
    function getTotalRepaymentAmount(address _user) public view returns (uint256) {
        if (borrowingBalances[_user] == 0) return 0;
        
        uint256 borrowedAmount = borrowingBalances[_user];
        uint256 borrowDuration = block.timestamp - borrowStartTime[_user];
        uint256 interest = calculateInterest(borrowedAmount, borrowDuration);
        
        return borrowedAmount + interest;
    }
    
    // getter functions for balances
    function getContractBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }
    
    function getUserCollateralBalance(address _user) public view returns (uint256) {
        return collateralBalances[_user];
    }
}
