// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Escrow{
    
    enum Status {OPEN, PENDING, CONFIRMED, COMPLETED}
    
    address public buyer;
    address public seller;
    address public arbiter;
    uint256 public immutable arbiter_fee = 1;
    uint256 public balance;
    uint256 public totalItems;

    mapping(uint256 => ItemStruct) private items;
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => uint256) public priceOf;
    
    struct ItemStruct {
        uint256 itemId;
        uint256 price;
        address owner;
        uint256 countItem;
        Status status;
        uint256 deliveryTimestamp;
    }

    //contract deployer is the arbiter
    constructor() {
        arbiter = msg.sender;
        balance = 0;
        totalItems = 0;
    }


    event Action(uint256 itemId, string description, Status status, address indexed function_caller);

    function createNewItem(uint256 _price) payable external{

        require(msg.sender != arbiter, "Arbiter cannot create/sell item");
        require(msg.value >= arbiter_fee, "Arbiter fee not met");
        pay(arbiter, arbiter_fee);

        uint256 _itemId = totalItems + 1;
        totalItems++;
        ItemStruct storage item = items[_itemId];

        item.itemId = _itemId;
        item.price = _price;
        item.owner = msg.sender;
        item.status = Status.OPEN;
        item.countItem = 0;

        ownerOf[_itemId] = msg.sender;
        priceOf[_itemId] = _price;
        seller = msg.sender;

        emit Action (_itemId, "New Item Created", Status.OPEN, msg.sender);

    }

    //step1 : buyer orders item and funds escrow

    function orderItem(uint256 itemId) external payable{
       
        require(msg.sender != ownerOf[itemId], "Owner cannot buy his own item");
        require(msg.sender != arbiter, "Arbiter cannot order the item");
        require(msg.value >= priceOf[itemId], "Pay the correct price of the item");
        require(items[itemId].countItem < 1 , "Only 1 piece");
        items[itemId].countItem++;
        items[itemId].status = Status.PENDING;
        
        buyer = msg.sender;
        
        //money for the item sent to the contract to be held till delivery
        balance += msg.value;

        emit Action (itemId, "Item Ordered", Status.PENDING, msg.sender);
    }
    function getDeliveryTime(uint256 itemId) public view returns(uint256){
        return items[itemId].deliveryTimestamp;
    }

    function getItemStatus(uint256 itemId) public view returns(Status){
        return items[itemId].status;
    }
    //step 2: seller transfers ownership of item 


    function performDelivery(uint256 itemId) external{
        require(msg.sender == seller);
        require(items[itemId].status == Status.PENDING, "Item has not been paid for yet");
        require(balance >= priceOf[itemId], "Item has not been paid for completely");
            // Set the delivery timestamp when delivery is performed
        items[itemId].deliveryTimestamp = block.timestamp;
        //if conditions are met
        items[itemId].owner = buyer;
        ownerOf[itemId] = buyer;
        items[itemId].status = Status.CONFIRMED;

        emit Action(itemId, "CONFIRMED", Status.CONFIRMED, msg.sender);
    }

    //step 3: escrow funds transferred to the seller

    function paySeller(uint256 itemId) external{
        require(msg.sender == arbiter, "Only arbiter can pay the seller");
        require(items[itemId].status == Status.CONFIRMED, "Item has not been delivered yet");
        uint256 amt = items[itemId].price;
        require(balance >= amt, "Funds not available");
        pay(seller, amt);
        balance -= amt;

        items[itemId].status = Status.COMPLETED;

        emit Action(itemId, "COMPLETED", Status.COMPLETED, msg.sender);
        totalItems--;

    }
    
    function pay(address payee, uint256 amount) internal {
        (bool callSuccess, ) = payable(payee).call{value: amount}("");
        require(callSuccess, "Call Failed");
    }

function refundIfNotClaimed(uint256 itemId) external {
    require(msg.sender == arbiter, "Only arbiter can initiate refund");
    require(items[itemId].status == Status.CONFIRMED, "Item has not been confirmed yet");
    require(block.timestamp > items[itemId].deliveryTimestamp + 1 minutes, "1 minutes not elapsed yet");

    // Return funds to the buyer
    pay(buyer, balance);
    balance = balance - items[itemId].price;

    // Return item to the seller
    items[itemId].owner = seller;
    ownerOf[itemId] = seller;
    items[itemId].status = Status.OPEN;

    emit Action(itemId, "Refund initiated", Status.OPEN, msg.sender);
    }
    
}
