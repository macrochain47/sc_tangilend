// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract OriginationalController is IERC721Receiver,Ownable {
    using SafeERC20 for IERC20;
    IERC20 private token;
    constructor(IERC20 _token) {
           token = _token;
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


    function setTax(uint256 _tax) public onlyOwner {
        tax = _tax;
        emit SetTax(_tax);
    }

    function setToken(IERC20 _token) public onlyOwner {
        token = _token;
        emit SetToken(_token);
    }

    function setNft(IERC721Enumerable _nft) public onlyOwner {
        // nft = _nft;
        emit SetNFT(_nft);
    }

     function getListedNft(IERC721Enumerable nft) view public returns (ListDetail [] memory)  {
        
        uint balance = nft.balanceOf(address(this));
        ListDetail[] memory myNft = new ListDetail[](balance);
       
        for( uint i = 0; i < balance; i++)
        {
            myNft[i] = listDetail[nft.tokenOfOwnerByIndex(address(this), i)];
        }
        return myNft;
    }

    function listNft(IERC721Enumerable nft, uint256 _tokenId, uint256 _price) public {
        Rental storage rental = rentals[_tokenId];
        require(rental.renter == address(0), "NFTRentingContract: NFT already rented cannot ber transfered");
        require(nft.ownerOf(_tokenId) == msg.sender, "You are not the owner of this NFT");
        require(nft.getApproved(_tokenId) == address(this), "Marketplace is not approved to transfer this NFT");

        listDetail[_tokenId] = ListDetail(payable(msg.sender), _price, _tokenId);
        
        nft.safeTransferFrom(msg.sender, address(this), _tokenId);
        emit ListNFT(msg.sender,_tokenId, _price);
    }
    function allow(IERC721Enumerable nft, uint256 _tokenId) public {
        nft.approve(address(this),_tokenId);
    }
    function allowalll(IERC721Enumerable nft) public {
        nft.setApprovalForAll(address(this),true);
    }

    function updateListingNftPrice(IERC721Enumerable nft, uint256 _tokenId, uint256 _price) public {
        require(nft.ownerOf(_tokenId) == address(this), "This NFT doesn't exist on marketplace");
        require(listDetail[_tokenId].author == msg.sender, "Only owner can update price of this NFT");

        listDetail[_tokenId].price = _price;
        emit UpdateListingNFTPrice(_tokenId, _price);
    }

    function unlistNft(IERC721Enumerable nft, uint256 _tokenId) public {
        require(nft.ownerOf(_tokenId) == address(this), "This NFT doesn't exist on marketplace");
        require(listDetail[_tokenId].author == msg.sender, "Only owner can unlist this NFT");

        nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        emit UnlistNFT(msg.sender,_tokenId);
    }
    function showbalance() public view returns(uint) {
        return token.balanceOf(msg.sender) ;
    }

    function buyNft( IERC721Enumerable nft, uint256 _tokenId, uint256 _price) public {
        require(token.balanceOf(msg.sender) >= _price, "Insufficient account balance");
        require(nft.ownerOf(_tokenId) == address(this), "This NFT doesn't exist on marketplace");
        require(listDetail[_tokenId].price <= _price, "Minimum price has not been reached");
           
        SafeERC20.safeTransferFrom(token, msg.sender, address(this), _price);
        token.transfer(listDetail[_tokenId].author, _price * (100 - tax) / 100);
          
        nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        emit BuyNFT(msg.sender,_tokenId, _price);
    }
    //

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
    function withdrawToken(uint256 amount) public onlyOwner {
        require(token.balanceOf(address(this)) >= amount, "Insufficient account balance");
        token.transfer(msg.sender, amount);
    }

    function withdrawErc20() public onlyOwner {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
    function getCurrentTimestamp() public view returns (uint256) {
        return block.timestamp;
    }
     function rentOutNFT(IERC721Enumerable nft ,uint256 _tokenId, uint256 rentalDuration, uint256 collateral , uint256 rentalPayment) external {
        
        require(nft.ownerOf(_tokenId) == msg.sender, "NFTRentingContract: Only NFT owner can rent out");
        require(rentals[_tokenId].renter == address(0), "NFTRentingContract: NFT already rented");
        require(collateral  > 0, "NFTRentingContract: Deposit amount must be greater than 0");

        // Transfer the NFT to the contract
        nft.safeTransferFrom(msg.sender, address(this), _tokenId);

        // Calculate the rental end time
        uint256 rentalEndTime = block.timestamp +rentalDuration*(1 hours);

        // Store the rental information
        rentals[_tokenId] = Rental({
            lender : msg.sender,
            renter: address(0),
            rentalStartTime: 0,
            rentalEndTime: rentalEndTime,
            collateral : collateral ,
            rentalPayment : rentalPayment
        });
    }
    function x() view public  returns (uint) {
        return msg.sender.balance;
    }
    function time(uint256 _tokenId) view public returns(uint){
        Rental storage rental = rentals[_tokenId];
        return rental.rentalEndTime;

    }
    function startRentingNFT( IERC721Enumerable nft, uint256 _tokenId) external {
       
        Rental storage rental = rentals[_tokenId];
        require(rental.renter == address(0), "NFTRentingContract: NFT already rented");
        require(rental.rentalEndTime > 0, "NFTRentingContract: NFT is not available for rent");
        require(rental.rentalEndTime > block.timestamp, "NFTRentingContract: Rental period expired");
        require(token.balanceOf(msg.sender)  >= rental.collateral  , "NFTRentingContract: Insufficient deposit");

        // Transfer deposit from renter to the contract
        token.transferFrom(msg.sender, address(this), rental.collateral + rental.rentalPayment);

        nft.safeTransferFrom(address(this),msg.sender,_tokenId) ;
        // Update rental information
        rental.renter = msg.sender;
        rental.rentalStartTime = block.timestamp;

        emit NFTRentingStarted(_tokenId, msg.sender, rental.rentalEndTime);
    }

    // Function to end the NFT rental and return the deposit
    function endRentingNFT(IERC721Enumerable nft, uint256 _tokenId) external {
        // require(nft.ownerOf(_tokenId) == address(this), "NFTRentingContract: Token ID does not exist");
        Rental storage rental = rentals[_tokenId];
        require(rental.renter == msg.sender, "NFTRentingContract: Only the renter can end the rental");
        require(rental.rentalStartTime > 0, "NFTRentingContract: Rental not started yet");

        // Check if the rental period has ended
        if (block.timestamp < rental.rentalEndTime) {
            // Transfer the deposit back to the renter
            token.transfer(msg.sender, rental.collateral );
            nft.safeTransferFrom( msg.sender,rental.lender, _tokenId);
        }
        else{
            // Transfer NFT back to the NFT owner
            token.transfer(msg.sender, (rental.collateral*85)/100 );
            nft.safeTransferFrom( msg.sender,rental.lender, _tokenId);
        }
        
        delete rentals[_tokenId];

        emit NFTRentingEnded(_tokenId, msg.sender);
    }

    function withdrawnCollateral(uint256 _tokenId) external {
        Rental storage rental = rentals[_tokenId];
        require(rental.lender == msg.sender, "NFTRentingContract: Only the lender can get collateral when expired");
        token.transfer(msg.sender, rental.collateral) ;
    }
    
}