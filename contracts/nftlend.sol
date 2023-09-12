// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract Tangilend is IERC721Receiver,Ownable {
    using SafeERC20 for IERC20;
    IERC20 private token;

    struct ListDeposit {
        
        address  lender;
        uint256 loanId;
        uint256 loanduration ; 
        uint256 LoanStartTime ;
        uint256 LoanEndtime;
        address payableCurrency;
        uint256 principal ; 
        /// @dev Max is 10,000%, fits in 160 bits
        uint160 interestRate;
        
        
    }
     // Structure to hold Loan information
    struct Loan {
        address lender ;
        address borrower;
        uint256 loanduration ; 
        uint256 LoanStartTime ;
        uint256 LoanEndtime;
        uint256 collateralId ;
        address payableCurrency;
        uint256 principal ; 
        /// @dev Max is 10,000%, fits in 160 bits
        uint160 interestRate;
        
    }
    mapping(uint256 => mapping (uint256 => ListDeposit)) public listDeposits ;
    
    mapping(uint256 => Loan) public Loans;
    
                        
    event LoanStart(uint256 indexed tokenId, address indexed borrower, uint256 LoanEndTime);
    event LoanEnd(uint256 indexed tokenId, address indexed borrower);
       // Function to start renting the NFT

    
    constructor() {
    
        // token = _token;
    }
    using Counters for Counters.Counter; 
    Counters.Counter private depositCounter;
    Counters.Counter private loanCounter;

    function listLoan(IERC721Enumerable nft ,uint256 loanId, uint256 LoanDuration, uint256 collateralId ,address payableCurrency,uint256 principal ,uint160 interestRate  ) external {
        
        require(nft.ownerOf(collateralId) == msg.sender, "NFTRentingContract: Only NFT owner can list loan");
        

        // Transfer the NFT to the contract
        nft.safeTransferFrom(msg.sender, address(this), collateralId);

        // Calculate the Loan end time
        uint256 LoanEndTime = block.timestamp +LoanDuration*(1 hours);
         // Store the Loan information
        Loans[loanId] = Loan(
             address(0),
             msg.sender ,
            LoanDuration,
            0,
            LoanEndTime ,
            collateralId ,
            payableCurrency , 
             principal , 
            interestRate
        );

    }

    function DepositOffer(uint256 loanId,
        uint256 loanduration ,
        address payableCurrency,
        uint256 principal ,   
        uint160 interestRate)  public  returns (uint)  {
        IERC20(Loans[loanId].payableCurrency).safeTransferFrom(msg.sender,address(this), principal) ;
        uint256 depositId = depositCounter.current();
        uint256 LoanEndTime = block.timestamp +loanduration*(1 hours);
        listDeposits[loanId][depositId] = ListDeposit( msg.sender,loanId, loanduration, 0, LoanEndTime ,payableCurrency, principal, interestRate) ;
        depositCounter.increment();
        return depositId;

    }
    function withdraw( uint256 loanId, uint256 depositId) external{
        require(listDeposits[loanId][depositId].lender == msg.sender, "Not allowed");
        IERC20(Loans[loanId].payableCurrency).safeTransferFrom(address(this),msg.sender, Loans[loanId].principal) ;
        delete listDeposits[loanId][depositId];
    }
    function acceptTerm(  uint256 loanId) external {
        Loan storage loan = Loans[loanId];
        address lender = msg.sender ;
        require(loan.lender == address(0), "Already in loan ");
        require(loan.LoanEndtime > 0, "NFTRentingContract: NFT is not available for rent");
        require(loan.LoanEndtime > block.timestamp, "NFTRentingContract: Loan period expired");
        require(IERC20(Loans[loanId].payableCurrency).balanceOf(msg.sender)  >= loan.principal  , "NFTRentingContract: Insufficient deposit");

        // Transfer money to borrower
        IERC20(Loans[loanId].payableCurrency).transferFrom(msg.sender, loan.borrower, loan.principal );
        // Update Loan information
        loan.lender = lender;
        loan.LoanStartTime = block.timestamp;

        emit LoanStart(loanId, msg.sender, loan.LoanEndtime);
        
    }
     function startLoan(  uint256 loanId, uint256 depositId)  public {
       
        Loan storage loan = Loans[loanId];
        ListDeposit storage depositoffer = listDeposits[loanId][depositId] ;
        address lender = listDeposits[loanId][depositId].lender ;
        require(loan.lender == address(0), "Already in loan ");
        require(loan.LoanEndtime > 0, "NFTRentingContract: NFT is not available for rent");
        require(loan.LoanEndtime > block.timestamp, "NFTRentingContract: Loan period expired");
        require(IERC20(Loans[loanId].payableCurrency).balanceOf(msg.sender)  >= loan.principal  , "NFTRentingContract: Insufficient deposit");

        // Transfer deposit from  contract to lender
        IERC20(Loans[loanId].payableCurrency).transferFrom( address(this),msg.sender, loan.principal );

        
        // Update Loan information
        loan.lender = lender;
        loan.LoanStartTime = block.timestamp;
        loan.LoanEndtime = depositoffer.LoanEndtime ;
        loan.loanduration = depositoffer.loanduration;
        loan.principal = depositoffer.principal ;
        loan.interestRate = depositoffer.interestRate;


        emit LoanStart(loanId, msg.sender, loan.LoanEndtime);
    }
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external override pure returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

   
    function getCurrentTimestamp() public view returns (uint256) {
        return block.timestamp;
    }
     
    function x() view public  returns (uint) {
        return msg.sender.balance;
    }
    // function time(uint256 loanId) view public returns(uint){
    //     Loan storage loan = Loans[loanId];
    //     return loan.LoanEndtime;

    // }
    /// @dev The units of precision equal to the minimum interest of 1 basis point.
    uint256 public constant INTEREST_RATE_DENOMINATOR = 1e18;
    /// @dev The denominator to express the final interest in terms of basis ponits.
    uint256 public constant BASIS_POINTS_DENOMINATOR = 10_000;
    // Interest rate parameter
    uint256 public constant INSTALLMENT_PERIOD_MULTIPLIER = 1_000_000;
    // 50 / BASIS_POINTS_DENOMINATOR = 0.5%
    function getFullInterestAmount(uint256 principal, uint256 interestRate) public pure virtual returns (uint256) {
        // Interest rate to be greater than or equal to 0.01%
        // if (interestRate / INTEREST_RATE_DENOMINATOR < 1) revert FIAC_InterestRate(interestRate);

        return principal + principal * interestRate / INTEREST_RATE_DENOMINATOR / BASIS_POINTS_DENOMINATOR;
    }
    function payback(IERC721Enumerable nft, uint256 loanId) external {
        Loan storage loan = Loans[loanId];
        
          // Check if the Loan period has ended
        if (block.timestamp < loan.LoanEndtime) {

            IERC20(Loans[loanId].payableCurrency).transfer(loan.lender, loan.principal + loan.principal * loan.LoanEndtime* 365 days * loan.interestRate );
            // Transfer the asset back to the borrower\
            nft.safeTransferFrom( address(this),msg.sender, loan.collateralId);
            
            
        }
        else{
            
        
            nft.safeTransferFrom( address(this),loan.lender, loan.collateralId);
        }
        
        delete Loans[loanId];

        emit LoanEnd(loanId, msg.sender);


    }

    // Function to end the loan and claim money include interest
    function claimAsset(IERC721Enumerable nft, uint256 loanId) external {
       
        Loan storage loan = Loans[loanId];
        require(loan.lender == msg.sender, "not allowed");
        require(loan.LoanStartTime > 0, "NFTRentingContract: Loan not started yet");

        // Check if the Loan period has ended
        nft.safeTransferFrom( address(this),msg.sender, loan.collateralId);
        
        delete Loans[loanId];

        emit LoanEnd(loanId, msg.sender);
    }


    
    
}