pragma solidity ^0.4.25;

contract ProcurementContract{

    // deployer adddress is assigned buyer role
    address buyer;
    constructor() public {
        buyer = msg.sender;
    }

    // addresses of stakeholders involved in the procurement process    
    address [] suppliers;
    address [] accepted_suppliers;
    address [] leading_qualification_suppliers;
    address [] winning_qualification_suppliers;
    address [] winning_suppliers;
    uint [] leading_qualification_bids;
    uint [] winning_qualification_bids;
    uint [] winning_bids;
    address winning_supplier;
    
    // attributes needed @ pre-auction stage
    bytes32 product_description;
    uint leading_qualification_bid;
    uint public bid_decrement;
    uint qualification_duration;
    uint auction_duration;

    // different states duirng the procurement process
    bool buyer_specification = false; 
    bool supplier_participate = false;
    bool supplier_accepted = false;
    bool supplier_qualification_bids = false;
    bool supplier_bids = false;
    bool qualifying_bids = false;
    bool auction_start = false;

    // restriction during auction
    modifier onlyBuyer(){
        require (msg.sender == buyer, "Only buyer can call this function");
        _;
    }
    
    modifier onlysupplier(){
        require (msg.sender != buyer, "Only supplier can call this function");
        _;
    }
    
    // attributes needed during supplier evaluation stage
    struct supplier_evaluation{
    // bytes32 RFI_form; //Request for Information (RFI) hash file
    // bytes32 RFP_form; //Request for Proposal (RFP) hash file
    bytes32 RFQ_form; //Request for Quotation (RFQ) hash file
    }
    mapping (address => supplier_evaluation) supplier_details;
    
    uint total_suppliers =0;
    uint total_accepted_suppliers =0;
    uint total_winning_qualification_suppliers =2;
    
    // variables needed during the live qualification process
    struct supplier_qualification_bid{
        uint qualification_bid;
    }
    mapping (address => supplier_qualification_bid) supplier_qualification_Bid;
    
    uint public qualification_deadline;

    struct supplier_bonus{
        uint bonus;
    }
    mapping (address => supplier_bonus) supplier_Bonus;

    // variables needed during the live action process
    struct supplier_bid{
        uint bid;
    }
    mapping (address => supplier_bid) supplier_Bid;
    
    uint public auction_deadline;
    
    uint leading_bid;
    event supplier_Participation_Open(string);
    event Auction_Open(string);
    event Auction_Ended(string, uint);
    event Qualification_Ended(string, uint[]);
    event Alert(string);
    event Alarm(string);
    event Attention(string);

    // 1. buyer specification stage
    function requst_for_quotation (bytes32 _product_description, // bytes32 _technical_specification,
                                 uint _pre_auction_price, uint _bid_decrement,uint _qualification_duration_minutes, uint _auction_duration_minutes) public onlyBuyer{
     
        buyer_specification = true;

        product_description = _product_description;
        // technical_specification = _technical_specification;
        leading_qualification_bid = _pre_auction_price;
        bid_decrement = _bid_decrement;
       
        qualification_duration = _qualification_duration_minutes; //the qualification duration in minutes
        qualification_deadline = now + (qualification_duration*1 minutes);
       
        auction_duration = _auction_duration_minutes; //the auction duration in minutes
        auction_deadline = now + (auction_duration*1 minutes);

        emit supplier_Participation_Open("suppliers may participate for the procurement process by providing their details");
    }
   
    // 2. supplier participation stage: suppliers participate in the evaluation stage
    function quotation (bytes32 _RFQ_form) public onlysupplier{
     
        require (buyer_specification);
        
        // supplier_details[msg.sender].RFI_form = _RFI_form;
        // supplier_details[msg.sender].RFP_form = _RFP_form;
        supplier_details[msg.sender].RFQ_form = _RFQ_form;
        suppliers.push(msg.sender) -1;
        
        total_suppliers++;
        supplier_participate = true;
     
    }
    
    // 3. supplier evaluation stage
    function quotation_evaluation (address _supplier, uint _bonus) public onlyBuyer{
    
        require (supplier_participate);
    
        // select suppliers only from the ones who participated suppliers 
        for (uint i=0; i<suppliers.length; i++){
            if (_supplier == suppliers[i]) {
                accepted_suppliers.push(suppliers[i]) -1;
                total_accepted_suppliers++;
                supplier_Bonus[_supplier].bonus = _bonus;
                break;
            }
            else emit Alert ("Accepted suppliers are selected from the ones who participated in previous stage only");
        }
        supplier_accepted = true;
        emit Auction_Open("Accepted suppliers may start their bidding");
    }
    
    function qualifying_quotations () public view returns (uint, address[]){
        return (total_accepted_suppliers, accepted_suppliers);
    }

    // 4. Live qualification stage: (only accepted suppliers can bid)
    // PROBLEM: non-accepted suppliers can execute this function, although it does not change the winning bid ... 
    function qualification (uint _qualification_bid) public onlysupplier returns(bool) {
                                 // bid
        require (supplier_accepted);
        require (now < qualification_deadline, "Qualification period has ended.");
        
        for (uint i=0; i<accepted_suppliers.length; i++){
            if (msg.sender == accepted_suppliers [i]){
                supplier_qualification_Bid[msg.sender].qualification_bid = _qualification_bid;
                if (supplier_qualification_Bid[msg.sender].qualification_bid + supplier_Bonus[msg.sender].bonus <= (leading_qualification_bid - bid_decrement)){
                    
                    leading_qualification_bids.push(supplier_qualification_Bid[msg.sender].qualification_bid);
                    leading_qualification_suppliers.push(msg.sender);

                    if (leading_qualification_bids.length <= total_winning_qualification_suppliers) {
                       
                            winning_qualification_bids.push(supplier_qualification_Bid[msg.sender].qualification_bid);
                            winning_qualification_suppliers.push(msg.sender);
                        
                    }
                    else{
                        for (uint j=leading_qualification_bids.length; j>leading_qualification_bids.length-total_winning_qualification_suppliers; j--){
                            winning_qualification_bids.length--;
                            winning_qualification_suppliers.length--;
                        }
                        for (uint w=leading_qualification_bids.length; w>leading_qualification_bids.length-total_winning_qualification_suppliers; w--){
                            winning_qualification_bids.push(leading_qualification_bids[w-1]);
                            winning_qualification_suppliers.push(leading_qualification_suppliers[w-1]);
                        }
                    }
                }
                break;
            }
            else emit Alert("Only accepted suppliers are allowed to bid");
        }
        supplier_qualification_bids = true;
        return (true);
    }
 
    function current_qualifying_suppliers () public view returns (uint[], address[]){
        return (winning_qualification_bids, winning_qualification_suppliers);   
        // leading_qualification_bids, leading_qualification_suppliers
    }

    // 5. Announcing the qualification bids
    function announce_qualification_bids () public onlyBuyer returns(bool){
        require (supplier_qualification_bids, "Qualification period has not yet ended.");
        require (now > qualification_deadline, "Qualification period has not yet ended.");
        require (!auction_start, "Qualification bids already announced.");

        auction_start = true;

        emit Qualification_Ended("The qualification stage has ended and Thank you for participating. The auction stage starts now. The qualifying bids are", winning_qualification_bids);       
        return true;
    }

    // 6. Live final auction stage: (only qualified suppliers can bid)
    function final_auction (uint _bid) public onlysupplier returns(bool) {
                                 // bid
        require (supplier_qualification_bids);
        require (now > qualification_deadline, "Qualification has not yet ended");
        require (now < auction_deadline, "Auction period has ended.");

        leading_bid = winning_qualification_bids[0];

        for (uint i=0; i<winning_qualification_suppliers.length; i++){
            if (msg.sender == winning_qualification_suppliers [i]){
                supplier_Bid[msg.sender].bid = _bid;
                if (supplier_Bid[msg.sender].bid + supplier_Bonus[msg.sender].bonus <= (leading_bid - bid_decrement)){
                    leading_bid = supplier_Bid[msg.sender].bid;
                    winning_supplier = msg.sender;
                }
                break;
            }
            else emit Attention("Only qualified suppliers are allowed to bid");
        }
        supplier_bids = true;
        return (true);
    }

    function current_winning_suppliers () public view returns (uint[], address[]){
        return (winning_bids, winning_suppliers);   
        // leading_qualification_bids, leading_qualification_suppliers
    }

    //7. Announcing the winnind bid and Awarding the respective supplier (after the qualification_deadline)
    function confirm_winning_bid () public payable onlyBuyer returns(bool){
        
        require (supplier_bids);
        require (now > auction_deadline, "Auction period has not yet ended.");
        
        emit Auction_Ended("The auction has ended and Thank you for participating. The winning bid equals", leading_bid);
        require(msg.value == leading_bid,"The amount does not equal the awarding bid price");
        winning_supplier.transfer(leading_bid);
        
        return true;
    }

}