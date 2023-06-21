// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol";
import "@aave/protocol-v2/contracts/interfaces/IERC20.sol";
import {Pool} from "@aave/core-v3/contracts/protocol/pool/Pool.sol";



contract Escrow {
    struct Payment {
        uint256 amount;
        address employer;
        address gamer;
        bool isDeposited;
        bool isCompleted;
        bool isRefundable;
        uint256 completionDate;
    }
    
    Payment[] public payments;
    address public trooperAddress;
    
    event PaymentCreated(uint256 paymentId);
    event PaymentCompleted(uint256 paymentId);
    event PaymentClaimed(uint256 paymentId);
    
    constructor(address _stablecoin, address _aaveStablecoinPool) {
        stableCoin = IERC20(_stablecoin);
        aaveStablecoinPool = _aaveStablecoinPool;
    }
    
    modifier onlyEmployer(uint256 paymentId) {
        require(msg.sender == payments[paymentId].employer, "Only the employer can call this function");
        _;
    }

    modifier bothEmployerAndTrooper(uint256 paymentId) {
        require(msg.sender == payments[paymentId].employer, "Only the employer and Trooper can call this function");
        _;
    }
    
    modifier onlyGamer(uint256 paymentId) {
        require(msg.sender == payments[paymentId].gamer, "Only the gamer can call this function");
        _;
    }

    modifier onlyTrooper(uint256 paymentId) {
        require(msg.sender == trooperAddress, "Only Trooper can call this function");
        _;
    }
    
    function createPayment(address _gamer) external payable {
        Payment memory newPayment = Payment({
            amount: msg.value,
            employer: msg.sender,
            gamer: _gamer,
            isDeposited: true,
            isCompleted: false,
            completionDate: 0
        });
        
        payments.push(newPayment);
        Pool.supply(stableCoin, msg.value, _gamer);
        emit PaymentCreated(payments.length - 1);
    }
    
    function confirmCompletion(uint256 paymentId) external bothEmployerAndTrooper(paymentId) {
        require(payments[paymentId].isDeposited, "Payment has not been made");
        require(!payments[paymentId].isCompleted, "Payment has already been completed");
        
        payments[paymentId].isCompleted = true;
        payments[paymentId].completionDate = block.timestamp;
        
        emit PaymentCompleted(paymentId);
    }

    function requestRefund(uint256 paymentId) external onlyEmployer(paymentId) {
        require(payments[paymentId].isDeposited, "Payment has not been made");
        require(!payments[paymentId].isCompleted, "Payment has already been completed");
        
        payments[paymentId].isRefundable = true;
        payments[paymentId].completionDate = block.timestamp;
        
        emit PaymentCompleted(paymentId);
    }
    
    function claimPayment(uint256 paymentId) external onlyGamer(paymentId) {
        require(payments[paymentId].isDeposited, "Payment has not been made");
        require(payments[paymentId].isCompleted, "Payment has not been completed");
        require(block.timestamp >= payments[paymentId].completionDate + 15 days, "Payment cannot be claimed yet");
        
        uint256 amountToClaim = payments[paymentId].amount;
        Pool.withdraw(address(this), amountToClaim);
        
        payable(payments[paymentId].gamer).transfer(amountToClaim);
        
        emit PaymentClaimed(paymentId);
    }

    function approveRefund(uint256 paymentId) external onlyTrooper(paymentId) {
        require(payments[paymentId].isDeposited, "Payment has not been made");
        require(payments[paymentId].isRefundable, "Refund can not be made");
        require(block.timestamp >= payments[paymentId].completionDate + 15 days, "Refund cannot be claimed yet");
        
        uint256 amountToRefund = payments[paymentId].amount;
        Pool.withdraw(payments[paymentId].employer, amountToClaim);
        
        payable(payments[paymentId].employer).transfer(amountToClaim);
        
        emit PaymentClaimed(paymentId);
    }
    
    function getPaymentCount() external view returns (uint256) {
        return payments.length;
    }
    
    function getPayment(uint256 paymentId) external view returns (Payment memory) {
        return payments[paymentId];
    }

    function changeTrooperAddress(address newTrooperAddress) external onlyTrooper(){
        trooperAddress = newTrooperAddress;
    }
}
