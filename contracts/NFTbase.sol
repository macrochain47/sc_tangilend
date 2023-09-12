

// SPDX-License-Identifier: MIT


pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";





contract NFTbase is ERC721, ERC721Enumerable, ERC721Burnable, Ownable {
    using Counters for Counters.Counter; 
    using ECDSA for bytes32;
    bool public onSaleOpen = false;
    string private baseURI;
	string private baseExt = ".json";
	address admin;
	
    bool  public burnapprove = false ; 


    string public collectionName;
    // this contract's token symbol
    string public collectionNameSymbol;
    // total number of nft minted
    uint256 public nftCounter;
    address private _signerAddress;
    string private signPrefix = "Signed for NFT Minting:";
    // Event to emit the minter's address during minting
    event NFTMinted(address indexed minter, uint256 tokenId);
    struct NFT{
        address owner ; 
        uint256 principal ;        
    }
    
    mapping(uint256 => NFT) public nfts ; 


    Counters.Counter private _tokenIdCounter;
    
    constructor() ERC721("NFTbase", "NFTB") {
        collectionName = name();
        collectionNameSymbol = symbol();
        admin = msg.sender;		
	}
     function verifyTransaction(
        address sender,
        uint256 amount,
        bytes calldata signature,
        uint256 nonce
    ) private view returns (bool) {
        bytes32 hash = keccak256(
            abi.encodePacked(signPrefix, sender, amount, nonce, address(this))
        );
        address recoveredAddress = ECDSA.recover(hash, signature);
        return _signerAddress == recoveredAddress;
    }

    function isMessageValid(bytes memory _signature)
        public
        view
        returns ( bool)
    {
        bytes32 messagehash = keccak256(
            abi.encodePacked(address(this), msg.sender)
        );
        address signer = messagehash.toEthSignedMessageHash().recover(
            _signature
        );

        if (admin == signer) {
            return ( true);
        } else {
            return (false);
        }
    }
    // Add publicMint and onSaleOpen Variables
    function tokenize(uint256  principal, bytes memory signature )
         public payable {
       
        uint256 tokenId = _tokenIdCounter.current();
       
        
        nfts[tokenId] = NFT(msg.sender, principal );
        internalMint();
        require(
            isMessageValid(signature),
            " Contract Tokenize Not Allowed"
        );
        emit NFTMinted(msg.sender, tokenId);
    }
    // Function to transfer ownership of an NFT
    function transferNFT(uint256 tokenId, address to) external {      

        nfts[tokenId].owner = to;

        emit Transfer(msg.sender, to, tokenId);
    }
    function _baseURI() internal view virtual override returns (string memory) {
		return 'https://ipfs.moralis.io:2053/ipfs/QmcVfVhhPC3m2PxoXbP5FnskWtATzQjgc617cSXF9kT3gD/RWAs';
	}

	
	// Get metadata URI
	function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
		require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token.");

		

		string memory currentBaseURI = _baseURI();
		return
			bytes(currentBaseURI).length > 0
				? string(abi.encodePacked(currentBaseURI, Strings.toString(tokenId), baseExt))
				: "";
	}

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }
    
    function internalMint() internal {
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
    }

    function withdraw(address _addr) external onlyOwner {
        // get the balance of the contract
        uint256 balalnce = address(this).balance;
        payable(_addr).transfer(balalnce);
    }
    function setBurn() public onlyOwner {
		burnapprove = true;
	}
    function burnn(uint256 tokenId) public virtual  {
        require(burnapprove, " cannot burn");
        
        
        _burn(tokenId);
    }
    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }



    using Address for address payable; // ERC-721 token contract address IERC721 private nftContract; // Sale struct to store details of each sale struct Sale { address seller; uint256 tokenId; uint256 price; // The price in native token (with 18 decimals) bool active; } // Mapping from token ID to Sale struct mapping(uint256 => Sale) public tokenIdToSale; // Events event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price); event NFTSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price); // Constructor - Pass the address of the ERC-721 contract when deploying this contract constructor(address _nftContract) { nftContract = IERC721(_nftContract); } // Function to list an NFT for sale function listNFTForSale(uint256 _tokenId, uint256 _priceInWei) external { require(nftContract.ownerOf(_tokenId) == msg.sender, "You don't own this NFT"); require(_priceInWei > 0, "Price must be greater than zero"); tokenIdToSale[_tokenId] = Sale({ seller: msg.sender, tokenId: _tokenId, price: _priceInWei, active: true }); emit NFTListed(_tokenId, msg.sender, _priceInWei); } // Function to buy an NFT function buyNFT(uint256 _tokenId) external payable { Sale storage sale = tokenIdToSale[_tokenId]; require(sale.active, "NFT not available for sale"); require(msg.value >= sale.price, "Insufficient payment"); address seller = sale.seller; uint256 price = sale.price; sale.active = false; delete tokenIdToSale[_tokenId]; // Transfer the NFT to the buyer nftContract.safeTransferFrom(address(this), msg.sender, _tokenId); // Transfer the payment to the seller payable(seller).sendValue(price); emit NFTSold(_tokenId, seller, msg.sender, price); } // Function to cancel an NFT listing (only the seller can call this) function cancelSale(uint256 _tokenId) external { Sale storage sale = tokenIdToSale[_tokenId]; require(sale.active, "NFT not available for sale"); require(sale.seller == msg.sender, "You are not the seller"); sale.active = false; delete tokenIdToSale[_tokenId]; // Transfer the NFT back to the seller nftContract.safeTransferFrom(address(this), msg.sender, _tokenId); emit NFTListed(_tokenId, msg.sender, 0); } // Function to get the details of an active sale function getSale(uint256 _tokenId) external view returns (address seller, uint256 price, bool active) { Sale storage sale = tokenIdToSale[_tokenId]; require(sale.active, "NFT not available for sale"); return (sale.seller, sale.price, sale.active); } } Now, you can list an NFT for sale by specifying the price in Wei (ETH with 18 decimal places). Similarly, when buying an NFT, the buyer needs to send the payment in Wei (ETH with 18 decimal places) to the smart contract. The smart contract will handle the conversion from Wei to Ether for you. Remember that when interacting with the smart contract, users need to be aware of the correct conversion between Ether and Wei. Most wallet interfaces handle this conversion automatically, but it's essential to double-check the amount before confirming transactions to avoid mistakes. User NFT expirationtime in smart contract with rental time , if rental time is up transfer the owner to the origin owner . can you write smart contract for this ChatGPT Sure! Below is a smart contract that implements an NFT rental system with an expiration time. The contract allows users to rent out their NFTs to others for a specified rental duration. If the rental time is up, the NFT ownership reverts back to the original owner. solidity Copy code // SPDX-License-Identifier: MIT pragma solidity ^0.8.0; import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol"; import "@openzeppelin/contracts/utils/Address.sol"; contract NFTRenting { using Address for address payable; // ERC-721 token contract address IERC721 private nftContract; // Rental struct to store details of each rental struct Rental { address owner; // Current owner of the NFT (renter) address originalOwner; // Owner who listed the NFT for rent uint256 tokenId; uint256 rentalPrice; // The price for renting the NFT in native token (with 18 decimals) uint256 rentalDuration; // Duration of the rental in seconds uint256 startTime; // Rental start time (timestamp) bool active; } // Mapping from token ID to Rental struct mapping(uint256 => Rental) public tokenIdToRental; // Events event NFTListedForRent(uint256 indexed tokenId, address indexed owner, uint256 rentalPrice, uint256 rentalDuration); event NFTRented(uint256 indexed tokenId, address indexed renter, uint256 rentalPrice, uint256 rentalDuration, uint256 startTime); event NFTReturned(uint256 indexed tokenId, address indexed originalOwner); // Constructor - Pass the address of the ERC-721 contract when deploying this contract constructor(address _nftContract) { nftContract = IERC721(_nftContract); } // Function to list an NFT for rent function listNFTForRent(uint256 _tokenId, uint256 _rentalPriceInWei, uint256 _rentalDurationInSeconds) external { require(nftContract.ownerOf(_tokenId) == msg.sender, "You don't own this NFT"); require(_rentalPriceInWei > 0, "Rental price must be greater than zero"); require(_rentalDurationInSeconds > 0, "Rental duration must be greater than zero"); tokenIdToRental[_tokenId] = Rental({ owner: msg.sender, originalOwner: msg.sender, tokenId: _tokenId, rentalPrice: _rentalPriceInWei, rentalDuration: _rentalDurationInSeconds, startTime: 0, active: true }); emit NFTListedForRent(_tokenId, msg.sender, _rentalPriceInWei, _rentalDurationInSeconds); } // Function to rent an NFT function rentNFT(uint256 _tokenId) external payable { Rental storage rental = tokenIdToRental[_tokenId]; require(rental.active, "NFT not available for rent"); require(rental.startTime == 0, "NFT is already rented"); require(msg.value >= rental.rentalPrice, "Insufficient payment"); rental.owner = msg.sender; rental.startTime = block.timestamp; emit NFTRented(_tokenId, msg.sender, rental.rentalPrice, rental.rentalDuration, rental.startTime); } // Function to return the NFT after the rental duration is up function returnNFT(uint256 _tokenId) external { Rental storage rental = tokenIdToRental[_tokenId]; require(rental.active, "NFT not available for rent"); require(rental.owner == msg.sender, "You are not the current renter"); require(rental.startTime > 0, "NFT is not currently rented"); require(block.timestamp >= rental.startTime + rental.rentalDuration, "Rental duration is not up yet"); address originalOwner = rental.originalOwner; rental.startTime = 0; // Reset the start time rental.active = false; // Transfer the NFT back to the original owner nftContract.safeTransferFrom(address(this), originalOwner, _tokenId); emit NFTReturned(_tokenId, originalOwner); } // Function to get the details of an active rental function getRental(uint256 _tokenId) external view returns (address owner, uint256 rentalPrice, uint256 rentalDuration, uint256 startTime, bool active) { Rental storage rental = tokenIdToRental[_tokenId]; require(rental.active, "NFT not available for rent"); return (rental.owner, rental.rentalPrice, rental.rentalDuration, rental.startTime, rental.active); }
    
}