// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract Tangilend is IERC721Receiver {
    enum Status {
        LISTING,
        LOAN_DEFAULTED,
        LOAN_OFFER,
        REPAIED,
        FORFEITED
    }

    struct Offer {
        uint256 principal;
        uint256 apr;
        uint256 duration;
        ERC20 currency;
    }

    struct Loan {
        address lender;
        address borrower;
        ERC721 collection;
        uint256 tokenID;
        Offer defaultTerm;
        bytes32 acceptedOfferID;
        uint256 endTime;
        Status status;
    }

    mapping(bytes32 => Loan) public loans;
    mapping(bytes32 => mapping(bytes32 => Offer)) public offers;

    event LoanCreated(bytes32 indexed loanID, address indexed borrower);
    event StartedLend(bytes32 indexed loanID, address indexed lender);
    event StartedBorrow(bytes32 indexed loanID, address indexed lender, bytes32 indexed offerID);
    event OfferedTerm(bytes32 indexed loanID, bytes32 indexed offerID, address indexed lender);



    modifier loanExisted (bytes32 id) {
        require(loans[id].borrower != address(0), "This loan doesn't exists");
        _;
    }

    modifier loanIsListing (bytes32 id) {
        require(loans[id].status == Status.LISTING, "This loan is not listing");
        _;
    }

    function createLoan(
        bytes32 loanID,
        address collateralAddress,
        uint256 collateralID,
        uint256 principal,
        uint256 apr,
        uint256 duration,
        address currency
    ) external {
        require(
            ERC721(collateralAddress).ownerOf(collateralID) == msg.sender,
            "You do not own this NFT"
        );
        require(loans[loanID].borrower == address(0), "Loan already exists");

        loans[loanID] = Loan(
            address(0),
            msg.sender,
            ERC721(collateralAddress),
            collateralID,
            Offer( 
                principal, 
                apr, 
                duration, 
                ERC20(currency)
            ),
            bytes32(0),
            0,
            Status.LISTING
        );

        loans[loanID].collection.safeTransferFrom(msg.sender, address(this), collateralID);

        emit LoanCreated(loanID, msg.sender);
    }

    function startLending(bytes32 loanID) external loanExisted(loanID) loanIsListing(loanID) {
        Loan storage loanData = loans[loanID];

        require(
            loanData.defaultTerm.currency.transferFrom(
                msg.sender,
                loanData.borrower,
                loanData.tokenID
            ),
            "Transfer collateral to borrower failed"
        );
        loanData.endTime = block.timestamp + loanData.defaultTerm.duration * (1 days);
        loanData.lender = msg.sender;
        loanData.status = Status.LOAN_DEFAULTED;
        emit StartedLend(loanID, msg.sender);
    }

    function startBorrowing(bytes32 loanID, uint256 offerID) external loanExisted(loanID) loanIsListing(loanID) {
        Loan storage loanData = loans[loanID];
        Offer storage offerData = offers[loanID][bytes32(offerID)];

        require(loanData.borrower == msg.sender, "You are not the borrower");
        require(offerData.principal > 0, "Offer does not exist");

        loanData.endTime = block.timestamp + offerData.duration * (1 days);
        loanData.acceptedOfferID = bytes32(offerID);
        loanData.lender = msg.sender;
        loanData.status = Status.LOAN_OFFER;

        require(
            offerData.currency.transfer(msg.sender, offerData.principal),
            "Transfer principal to borrower failed"
        );

        emit StartedBorrow(loanID, msg.sender, bytes32(offerID));
    }

    function offerLoanTerm(
        bytes32 loanID, 
        bytes32 offerID, 
        uint256 principal, 
        uint256 apr, 
        uint256 duration, 
    address currency) external loanExisted(loanID) loanIsListing(loanID) {
        Loan storage loanData = loans[loanID];

        offers[loanID][offerID] = Offer(principal, apr, duration, ERC20(currency));
        
        require(
            loanData.defaultTerm.currency.transferFrom(
                msg.sender,
                loanData.borrower,
                loanData.tokenID
            ),
            "Transfer collateral to borrower failed"
        );

        emit OfferedTerm(loanID, offerID, msg.sender);
    }

    function repayLoan(bytes32 loanID) external loanExisted(loanID) {
        Loan storage loanData = loans[loanID];
        
        require(loanData.status == Status.LOAN_DEFAULTED || loanData.status == Status.LOAN_OFFER, "This loan does not on loan.");

        if (loanData.status == Status.LOAN_DEFAULTED) {
            require (
                loanData.defaultTerm.currency.transferFrom(msg.sender, loanData.lender, getRepayment(loanID)), 
                "Transfer principal to lender failed"
            );
            loanData.collection.safeTransferFrom(address(this), msg.sender, loanData.tokenID);
        } else {
            require (
                offers[loanID][loanData.acceptedOfferID].currency.transferFrom(msg.sender, loanData.lender, getRepayment(loanID)), 
                "Transfer principal to lender failed"
            );
            loanData.collection.safeTransferFrom(address(this), msg.sender, loanData.tokenID);                 
        }
        loanData.status = Status.REPAIED;
    }
        
        

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {}


    function getRepayment(uint256 loanID) internal returns (uint256) {
        Loan storage loanData = loans[loanID];
        uint256 repayment = 0;
        if (loanData.status == Status.LOAN_DEFAULTED) {
            Offer storage defaultTerm = loanData.defaultTerm;
            repayment = defaultTerm.principal + defaultTerm.principal * defaultTerm.apr / 100 * defaultTerm.duration / 365;
        } else {
            Offer storage acceptedOffer = offers[loanID][loanData.acceptedOfferID];
            repayment = acceptedOffer.principal + acceptedOffer.principal * acceptedOffer.apr / 100 * acceptedOffer.duration / 365;
        }
        return repayment;
    }
}