// SPDX-License-Identifier: MIT

import "@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol";
import "@aave/protocol-v2/contracts/interfaces/IERC20.sol";

contract Escrow {
    address public client;  // Client's address
    address public aaveStablecoinPool;  // Aave Stablecoin Pool's address
    uint256 public payment;  // Payment amount from the client
    uint256 public releaseTime;  // Minimum time before funds are claimable
    
    bool public clientConfirmed;  // Flag indicating if the client has confirmed the claim
    
    event FundsDeposited(address indexed client, uint256 amount);
    event ClaimInitiated(address indexed client, uint256 amount);
    event FundsClaimed(address indexed client, uint256 amount);
    
    constructor(address _aaveStablecoinPool, uint256 _releaseTime) {
        aaveStablecoinPool = _aaveStablecoinPool;
        releaseTime = block.timestamp + _releaseTime;
    }
    
    // Function to deposit funds into the escrow
    function depositFunds() external payable {
        require(msg.value > 0, "Amount must be greater than zero");
        require(client == address(0), "Funds already deposited");
        
        client = msg.sender;
        payment = msg.value;
        
        emit FundsDeposited(client, payment);
    }
    
    // Function to initiate the claim after the minimum time has passed
    function initiateClaim() external {
        require(msg.sender == client, "Only the client can initiate the claim");
        require(block.timestamp >= releaseTime, "Funds are not yet claimable");
        require(!clientConfirmed, "Funds already claimed");
        
        clientConfirmed = true;
        
        emit ClaimInitiated(client, payment);
    }
    
    // Function to claim the funds from the escrow after the claim has been initiated
    function claimFunds() external {
        require(msg.sender == client, "Only the client can claim the funds");
        require(clientConfirmed, "Claim not yet initiated");
        
        IERC20 stablecoin = IERC20(ILendingPoolAddressesProvider(aaveStablecoinPool).getLendingPool().getReserveData(address(this)).underlyingAsset);
        
        require(stablecoin.balanceOf(address(this)) >= payment, "Insufficient funds in the escrow");
        require(stablecoin.transfer(client, payment), "Failed to transfer funds");
        
        emit FundsClaimed(client, payment);
    }
}
