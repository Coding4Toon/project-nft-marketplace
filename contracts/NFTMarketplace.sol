// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

//import "hardhat/console.sol";

contract MFTMarketplace is ERC721URIStorage{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    uint256 listingPrice = 0.001 ether;

    address payable owner;

    mapping(uint256 => MarketItem) private idMarketItem;
    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    event idMarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    modifier onlyOwner{
        require(
            msg.sender == owner,
            "Only owner of the marketplace can perform this operation"
        );
        _;
    }

    constructor() ERC721("NFT MARKETPLACE TOON", "NFTOON") {
        owner == payable(msg.sender);
    }

    function updateListingPrice(uint256 _listingPrice) public payable onlyOwner{ 
        listingPrice = _listingPrice;
    }

    function getListingPrice() public view returns (uint256){
        return listingPrice;
    }

// CREATE NFT

/**
 * @dev Allows a user to create a new NFT (Non-Fungible Token).
 * 
 * @param tokenURI - The URI pointing to the NFT's metadata (usually a JSON file).
 * @param price - The price at which the NFT will be listed in the marketplace.
 * 
 * @return uint256 - Returns the ID of the newly created NFT.
 */
function createToken(string memory tokenURI, uint256 price) public payable returns (uint256){

    // Increment the total count of NFTs to generate a unique ID for the new NFT.
    _tokenIds.increment();

    // Fetch the current token ID which will be used as the ID for the new NFT.
    uint256 newTokenId = _tokenIds.current();

    // Mint a new NFT for the caller of this function.
    _mint(msg.sender, newTokenId);

    // Set the provided tokenURI as the metadata URI for the newly minted NFT.
    _setTokenURI(newTokenId, tokenURI);

    // List the new NFT for sale in the marketplace at the given price.
    createMarketItem(newTokenId, price);

    // Return the ID of the newly created NFT.
    return newTokenId;

}

// CREATE ITEM

/**
 * @dev Creates a market item representing an NFT listed for sale.
 * 
 * @param tokenId - The ID of the NFT being listed.
 * @param price - The price at which the NFT is being listed for sale.
 */
function createMarketItem(uint256 tokenId, uint256 price) private {

    // Ensure that the listing price is greater than 0.
    require(price > 0, "Price must be at least 1");

    // Ensure that the caller has sent the exact listing fee to list the NFT for sale.
    require(msg.value == listingPrice, "Price must be equal to listing price");

    // Create a new market item and store it in the 'idMarketItem' mapping.
    // - The NFT's token ID.
    // - The seller's address.
    // - The address of this contract, indicating the contract now has custody of the NFT.
    // - The listing price of the NFT.
    // - A boolean indicating that the NFT has not been sold yet.
    idMarketItem[tokenId] = MarketItem(
        tokenId,
        payable(msg.sender),
        payable(address(this)),
        price,
        false  
    );

    // Transfer custody of the NFT from the seller to this contract. This ensures that the NFT 
    // is held by the contract until it's purchased by a buyer.
    _transfer(msg.sender, address(this), tokenId);

    // Emit an event to notify external watchers (like frontend applications) that a new market 
    // item has been created and an NFT has been listed for sale.
    emit idMarketItemCreated(tokenId, msg.sender, address(this), price, false);
}

// CREATE SALE

/**
 * @dev Allows a user to purchase an NFT that is listed for sale in the market.
 * 
 * @param tokenId - The ID of the NFT being purchased.
 */
function createMarketSale(uint256 tokenId) public payable {

    // Retrieve the listing price of the NFT that's for sale.
    uint256 price = idMarketItem[tokenId].price;

    // Ensure that the buyer has sent the exact amount to purchase the NFT.
    require(msg.value == price, "Please submit the asking price in order to complete the purchase");

    // Transfer ownership of the NFT to the buyer.
    idMarketItem[tokenId].owner = payable(msg.sender);

    // Mark the NFT as sold in the marketplace.
    idMarketItem[tokenId].sold = true;

    // Increment the total count of items sold in the marketplace.
    _itemsSold.increment();

    // Transfer the NFT from the contract's custody to the buyer.
    _transfer(address(this), msg.sender, tokenId);

    // Transfer the listing fee to the contract's owner.
    payable(owner).transfer(listingPrice);

    // Transfer the sale amount to the original seller of the NFT.
    payable(idMarketItem[tokenId].seller).transfer(msg.value);
}

// GET ALL UNSOLD NFT

/**
 * @dev Fetches all NFTs from the marketplace that are currently unsold.
 * 
 * @return MarketItem[] memory - An array of market items representing unsold NFTs.
 */
function fetchMarketItem() public view returns (MarketItem[] memory) {
    
    // Get the total number of NFTs that have been minted/created.
    uint256 itemCount = _tokenIds.current();

    // Calculate the number of unsold NFTs. 
    // This is derived by subtracting the total number of items that have been sold from the total number of minted items.
    uint256 unSoldItemCount = _tokenIds.current() - _itemsSold.current();

    // Initialize a counter to keep track of the current index in the items array 
    // where the next unsold market item should be stored.
    uint256 currentIndex = 0;

    // Create a memory array of MarketItems to store the unsold market items. 
    // Its size is set to the number of unsold items.
    MarketItem[] memory items = new MarketItem[](unSoldItemCount);
    
    // Loop through all NFTs created so far.
    for (uint256 i = 0; i < itemCount; i++){
        
        // If the owner of the NFT (in the market item list) is the address of this contract, 
        // it means the NFT is unsold (since unsold items are held by the contract).
        if (idMarketItem[i+1].owner == address(this)){
            
            // Adjust the loop counter to match the NFT's actual ID since NFT IDs start from 1.
            uint256 currentId = i + 1;

            // Fetch the current unsold market item from storage.
            MarketItem storage currentItem = idMarketItem[currentId];

            // Add the current unsold market item to the resulting items array.
            items[currentIndex] = currentItem;

            // Increment the currentIndex for the next unsold item.
            currentIndex += 1;
        }
    }

    // Return the memory array containing all unsold NFTs.
    return items;
}

// GET USER NFT COLLECTION

/**
 * @dev Fetches all NFTs from the marketplace that are owned by the caller.
 * 
 * @return MarketItem[] memory - An array of market items representing NFTs owned by the caller.
 */
function fetchMyNFT() public view returns (MarketItem[] memory) {
    
    // Get the total number of NFTs that have been minted/created.
    uint256 totalCount = _tokenIds.current();

    // Initialize counters for the number of NFTs owned by the caller and 
    // the current index in the items array where the next owned NFT should be stored.
    uint256 itemCount = 0;
    uint256 currentIndex = 0;

    // First loop through all NFTs to count how many are owned by the caller.
    for(uint256 i = 0; i < totalCount; i++) {
        if (idMarketItem[i+1].owner == msg.sender) {
            itemCount += 1;
        }
    }

    // Create a memory array of MarketItems to store the NFTs owned by the caller. 
    // Its size is set to the number of items owned by the caller.
    MarketItem[] memory items = new MarketItem[](itemCount);

    // Loop again through all NFTs to populate the items array with the NFTs owned by the caller.
    for (uint256 i = 0; i < totalCount; i++) {
        if (idMarketItem[i+1].owner == msg.sender) {
            
            // Adjust the loop counter to match the NFT's actual ID since NFT IDs start from 1.
            uint256 currentId = i + 1;

            // Fetch the current market item from storage.
            MarketItem storage currentItem = idMarketItem[currentId];

            // Add the current market item to the resulting items array.
            items[currentIndex] = currentItem;

            // Increment the currentIndex for the next item.
            currentIndex += 1;
        }
    }

    // Return the memory array containing all NFTs owned by the caller.
    return items;
}


// GET USER ITEM LISTED

/**
 * @dev Fetches all NFTs from the marketplace that are listed by the caller.
 *      This function will help users see which items they've put up for sale.
 * 
 * @return MarketItem[] memory - An array of market items listed by the caller for sale.
 */
function fetchItemsListed() public view returns (MarketItem[] memory) {
    
    // Get the total number of NFTs that have been minted/created.
    uint256 totalCount = _tokenIds.current();

    // Initialize counters for the number of NFTs listed by the caller and 
    // the current index in the items array where the next listed NFT should be stored.
    uint256 itemCount = 0;
    uint256 currentIndex = 0;

    // First loop through all NFTs to count how many are listed by the caller.
    for(uint i = 0; i < totalCount; i++) {
        if(idMarketItem[i+1].seller == msg.sender) {
            itemCount += 1;
        }
    }

    // Create a memory array of MarketItems to store the NFTs listed by the caller. 
    // Its size is set to the number of items listed by the caller.
    MarketItem[] memory items = new MarketItem[](itemCount);

    // Loop again through all NFTs to populate the items array with the NFTs listed by the caller.
    for (uint256 i = 0; i < totalCount; i++) {
        if (idMarketItem[i+1].seller == msg.sender) {
            
            // Adjust the loop counter to match the NFT's actual ID since NFT IDs start from 1.
            uint256 currentId = i + 1;

            // Fetch the current market item from storage.
            MarketItem storage currentItem = idMarketItem[currentId];

            // Add the current market item to the resulting items array.
            items[currentIndex] = currentItem;

            // Increment the currentIndex for the next item.
            currentIndex += 1;
        }
    }

    // Return the memory array containing all NFTs listed by the caller.
    return items;
}

}

