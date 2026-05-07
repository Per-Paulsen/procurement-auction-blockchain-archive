pragma solidity ^0.4.25;

contract testAuctionContractXyz{

// deployer adddress is assigned buyer role
    address buyer;
    constructor() public {
        buyer = msg.sender;
    }

// addresses of stakeholders involved in the reverse_auction    
    //address buyer = 0xC3D3028Ec791Ad71073ceb6F899e391D796C2056;
    address [] sellers;
    address [] qualified_sellers;
    address [] leading_sellers;
    address [] winning_sellers;
    uint [] leading_bids;
    uint [] winning_bids;
    address winning_seller;
    address second_winning_seller;
    
//attributes needed @ pre-auction stage
    bytes32 product_description;
    // bytes32 technical_specification;
    uint leading_bid;
    uint second_leading_bid;
    uint public bid_decrement;
    uint auction_duration;

// different states duirng the auction process
    bool buyer_specification = false; 
    bool seller_participate = false;
    bool seller_qualified = false;
    bool seller_bids = false;
    bool qualifying_bids = false;

// restriction during auction
    modifier onlyBuyer(){
        require (msg.sender == buyer, "Only buyer can call this function");
        _;
    }
    
    modifier onlySeller(){
        require (msg.sender != buyer, "Only seller can call this function");
        _;
    }
    
// attributes needed during seller evaluation stage
    struct seller_evaluation{
    // bytes32 RFI_form; //Request for Information (RFI) hash file
    // bytes32 RFP_form; //Request for Proposal (RFP) hash file
    bytes32 RFQ_form; //Request for Quotation (RFQ) hash file
    }
    mapping (address => seller_evaluation) seller_details;
    
    uint total_sellers =0;
    uint total_qualified_sellers =0;
    uint total_winning_sellers =2;
    
// variables needed during the live action process
    struct seller_bid{
        uint bid;
    }
    mapping (address => seller_bid) seller_Bid;
    
    uint public deadline;
    
    event Seller_Participation_Open(string);
    event Auction_Open(string);
    event Auction_Ended(string, uint);
    event Alert(string);
    event Alarm(string);

// 1. buyer specification stage
    
    function pre_auction_stage (bytes32 _product_description, // bytes32 _technical_specification,
                                 uint _pre_auction_price, uint _bid_decrement,uint _auction_duration_minutes) public onlyBuyer{
     
        buyer_specification = true;

        product_description = _product_description;
        // technical_specification = _technical_specification;
        leading_bid = _pre_auction_price;
        bid_decrement = _bid_decrement;
        auction_duration = _auction_duration_minutes; //the auction duration in minutes
        deadline = now + (auction_duration*1 minutes);
        emit Seller_Participation_Open("Sellers may participate for the auction by providing their details");
    }
   
// 2. seller participation stage: sellers participate in the evaluation stage

    function seller_participation (// bytes32 _RFI_form,bytes32 _RFP_form, 
                                    bytes32 _RFQ_form) public onlySeller{
     
        require (buyer_specification);
        
        // seller_details[msg.sender].RFI_form = _RFI_form;
        // seller_details[msg.sender].RFP_form = _RFP_form;
        seller_details[msg.sender].RFQ_form = _RFQ_form;
        sellers.push(msg.sender) -1;
        
        total_sellers++;
        seller_participate = true;
     
    }
    
    /* 
    function get_seller_details (address _seller) public view returns (bytes32, bytes32, bytes32){
        return (seller_details[_seller].RFI_form, seller_details[_seller].RFP_form, seller_details[_seller].RFQ_form);
    }
    
    function get_sellers_total () public view returns (uint, address[]){
        return (total_sellers, sellers);
    } 
    */
    
// 3. seller qualification stage

    function seller_evaluation_process (address _seller) public onlyBuyer{
    
        require (seller_participate);
    
        // select sellers only from the ones who participated sellers 
        for (uint i=0; i<sellers.length; i++){
            if (_seller == sellers[i]) {
                qualified_sellers.push(sellers[i]) -1;
                total_qualified_sellers++;
                break;
            }
            else emit Alert ("Qualified sellers are selected from the ones who participated in previous stage only");
        }
        seller_qualified = true;
        emit Auction_Open("Qualified sellers may start their bidding");
    }
    
    function get_qualified_sellers_total () public view returns (uint, address[]){
        return (total_qualified_sellers, qualified_sellers);
    }

// 4. Live auction stage: (only qualified sellers can bid)
    
    // PROBLEM: non-qualified sellers can execute this function, although it does not change the winning bid ... 
    function sellers_bidding (uint _bid) public onlySeller returns(bool) {
                                 // bid
        require (seller_qualified);
        require (now < deadline, "Auction period has ended.");
        
        for (uint i=0; i<qualified_sellers.length; i++){
            if (msg.sender == qualified_sellers [i]){
                seller_Bid[msg.sender].bid = _bid;
                if (seller_Bid[msg.sender].bid <= (leading_bid - bid_decrement)){
                    
                    //second_leading_bid = leading_bid;
                    //second_winning_seller = winning_seller;

                    //leading_bid = seller_Bid[msg.sender].bid;
                    //winning_seller = msg.sender;

                    leading_bids.push(seller_Bid[msg.sender].bid);
                    leading_sellers.push(msg.sender);

                    //winning_sellers = [winning_seller, second_winning_seller];
                    //leading_bids = [leading_bid, second_leading_bid];

                    if (leading_bids.length <= total_winning_sellers) {
                       
                            winning_bids.push(seller_Bid[msg.sender].bid);
                            winning_sellers.push(msg.sender);
                        
                    }
                    else{
                        for (uint j=leading_bids.length; j>leading_bids.length-total_winning_sellers; j--){
                            winning_bids.length--;
                            winning_sellers.length--;
                        }
                        for (uint w=leading_bids.length; w>leading_bids.length-total_winning_sellers; w--){
                            winning_bids.push(leading_bids[w-1]);
                            winning_sellers.push(leading_sellers[w-1]);
                        }
                    }
                }
                break;
            }
            else emit Alert("Only qualified sellers are allowed to bid");
        }
        seller_bids = true;
        return (true);
    }
 
    /*function calculate_qualifying_bids () public onlyBuyer {
        require (seller_bids, "Qualifiaction round not finished");
         if(leading_bids.length>=total_winning_sellers){
            for (uint j=leading_bids.length; j>leading_bids.length-total_winning_sellers; j--){
                winning_bids.push(leading_bids[j-1]);
                winning_sellers.push(leading_sellers[j-1]);
            }
        }
        else emit Alarm("Not enough bids!");
        qualifying_bids = true;
    }*/

    function get_qualifying_bids () public view returns (uint[], address[], uint[], address[]){
        require(seller_bids, "Qualification bids not calculated");
        return (leading_bids, leading_sellers, winning_bids, winning_sellers);   
    }
    
//5. Announcing the winnind bid and Awarding the respective seller (after the deadline)
   
    function confirm_winning_bid () public payable onlyBuyer returns(bool){
        
        require (seller_bids);
        require (now > deadline, "Auction period has not yet ended.");
        
        emit Auction_Ended("The auction has ended and Thank you for participating. The winning bid equals", leading_bid);
        require(msg.value == leading_bid,"The amount does not equal the awarding bid price");
        winning_seller.transfer(leading_bid);
        
        return true;
    }
    
    /*
    function getBalance(address desired_address) public view returns(uint balance) {
        return address(desired_address).balance;
    }
    */

}