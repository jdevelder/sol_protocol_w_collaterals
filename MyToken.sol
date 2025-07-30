// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// erc20 token implementation for the decentralized lending platform
// creates mytoken with user-defined initial supply as required
contract MyToken is ERC20, Ownable {
    
    // constructor creates the token with initial supply and gives it to deployer
    // initialSupply parameter allows user to define the amount as specified
    constructor(uint256 initialSupply) ERC20("MyToken", "MTK") Ownable(msg.sender) {
        // mint the initial supply to contract deployer
        _mint(msg.sender, initialSupply);
    }
    
    // allows owner to create additional tokens if needed
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
    
    // allows owner to destroy tokens from their balance
    function burn(uint256 amount) public onlyOwner {
        _burn(msg.sender, amount);
    }
    
    // returns 18 decimals
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}