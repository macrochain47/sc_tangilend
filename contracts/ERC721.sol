// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract RWACollection is ERC721URIStorage {
    uint256 public amount;
    mapping(address => bool) public isAdmin;
    mapping(uint256 => uint256) public valuation;


    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Only admin can call this function");
        _;
    }

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        isAdmin[msg.sender] = true;
        amount = 0;
    }

    function adminMintAsset(uint256 val, string calldata uri) external  onlyAdmin {
        _mint(msg.sender, amount);
        _setTokenURI(amount, uri);
        valuation[amount] = val;
        amount++;
    }

    function getIDForAsset() external onlyAdmin returns  (uint256)  {
        amount++;
        return amount;
    } 

    function tokenizeAsset(bytes memory signature, uint256 tokenID, uint256 val, string calldata uri) external  {
        require(_exists(tokenID), "Asset is tokenized!");
        bytes32 message = keccak256(abi.encodePacked(address(this), msg.sender, tokenID, val, uri));
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(message);

        require(isAdmin[ECDSA.recover(messageHash, signature)], "Invalid Signature");
        _mint(msg.sender, tokenID);
        _setTokenURI(tokenID, uri);
        valuation[tokenID] = val;
    }
}