// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

contract ProcurementContract{

    // Deployer adddress is assigned buyer role
    address buyer;
    constructor() {
        buyer = msg.sender;
    }

    // Number of suppliers in final auction
    uint constant total_winning_qualification_suppliers = 2;

    // Addresses of supplier stakeholders for procurement process    
    address [] suppliers;
    address [] accepted_suppliers;
    //address [] leading_qualification_suppliers;
    address [] winning_qualification_suppliers;
    address [] winning_suppliers;
    address payable public winning_supplier;
   
    // Role restrictions for procurement process
    modifier onlyBuyer(){
        require (msg.sender == buyer, "Only buyer can call this function");
        _;
    }
   
    modifier onlySuppliers(){
        require (msg.sender != buyer, "Only supplier can call this function");
        _;
    }

    // Different state variables for procurement process
    bool buyer_specification_state = false;

    struct supplier_quotation_state{
        bool supplier_participate;
    }
    mapping (address => supplier_quotation_state) supplier_quotation_State;

    struct supplier_acceptance_state{
        bool supplier_accepted;
    }
    mapping (address => supplier_acceptance_state) supplier_acceptance_State;

    struct supplier_qualification_state{
        bool supplier_qualified;
    }
    mapping (address => supplier_qualification_state) supplier_qualification_State;

    // Different events for procurement process
    event supplier_Participation_Open(string);
    event Evaluation_Ended(string, address[], uint[], address[]);
    event Qualification_Ended(string, address[], uint[]);
    event Auction_Open(string);
    event Auction_Ended(string, address, uint);
    event Alert(string);
    event Alarm(string);
    event Attention(string);

    // Variables for RFQ Stage
    bytes32 public procurement_specification;
    uint public reserve_price;
    uint public bid_decrement;
    uint qualification_duration;
    uint auction_duration;
    uint public qualification_deadline;
    uint public auction_deadline;

    // Variables for Quotation Stage
    uint total_suppliers =0;

    struct supplier_evaluation{
        bytes32 RFQ_form;
    }
    mapping (address => supplier_evaluation) supplier_details;
 
    // Variables for Quotation Evaluation Stage
    uint total_accepted_suppliers =0;

    struct supplier_bonus{
        uint bonus;
    }
    mapping (address => supplier_bonus) supplier_Bonus;

    struct supplier_malus{
        uint malus;
    }
    mapping (address => supplier_malus) supplier_Malus;

    // Variables for Evaluation Announcement
    bool qualification_start = false;

    // Variables for Qualification Auction Stage
    bool supplier_qualification_bids = false;
    bool qualifying_bids = false;
    uint [] winning_qualification_bids;

    struct supplier_qualification_bid{
        uint qualification_bid;
    }
    mapping (address => supplier_qualification_bid) supplier_qualification_Bid;

    // Variables for Qualification Announcement
    bool auction_start = false;

    // Variables for Final Auction Stage
    bool supplier_bids = false;
    uint leading_bid;

    struct supplier_bid{
        uint bid;
    }
    mapping (address => supplier_bid) supplier_Bid;
   
    /////////////////////////////////
    // 1. RFQ Stage (buyer)
    /////////////////////////////////
    function requst_for_quotation (bytes32 _procurement_specification, uint _reserve_price, uint _bid_decrement,uint _qualification_duration_minutes, uint _auction_duration_minutes) public onlyBuyer{
        buyer_specification_state = true;
        require (qualification_start==false, "The quotation evaluation has already been announced.");

        procurement_specification = _procurement_specification;
        reserve_price = _reserve_price;
        bid_decrement = _bid_decrement;
       
        qualification_duration = _qualification_duration_minutes;
        qualification_deadline = block.timestamp + (qualification_duration*1 minutes);
       
        auction_duration = _auction_duration_minutes;
        auction_deadline = block.timestamp + (auction_duration*1 minutes);

        emit supplier_Participation_Open("suppliers may participate for the procurement process by providing their details");
    }
   
    /////////////////////////////////
    // 2. Quotation Stage (suppliers)
    /////////////////////////////////
    function quotation (bytes32 _RFQ_form) public onlySuppliers{
        require (buyer_specification_state, "There is no RFQ yet.");
        require (qualification_start==false, "The quotation evaluation has already been announced.");
       
        supplier_details[msg.sender].RFQ_form = _RFQ_form;
        suppliers.push(msg.sender);
       
        total_suppliers++;
        supplier_quotation_State[msg.sender].supplier_participate = true;
    }
   
    // get current suppliers
    /////////////////////////////////
    function current_suppliers () public view returns (uint , address[] memory){
        return (total_suppliers, suppliers);
    }

    // get details from all suppliers that participated in quotation stage: RFQ forms
    /////////////////////////////////
    function current_supplier_details (address _supplier) public view onlyBuyer returns (bytes32){
        return (supplier_details[_supplier].RFQ_form);
    }
   
    /////////////////////////////////
    // 3. Quotation Evaluation Stage (buyer)
    /////////////////////////////////
    function quotation_evaluation (address _supplier, uint _bonus, uint _malus) public onlyBuyer{
        require (supplier_quotation_State[_supplier].supplier_participate, "Supplier has not delivered quotation.");
        require (qualification_start==false, "The quotation evaluation has already been announced.");
   
        // accept supplier from all suppliers that participated in quotation stage
        for (uint i=0; i<suppliers.length; i++){
            if (_supplier == suppliers[i]) {
                accepted_suppliers.push(suppliers[i]);
                total_accepted_suppliers++;
                supplier_Bonus[_supplier].bonus = _bonus;
                supplier_Malus[_supplier].malus = _malus;
                break;
            }
            else emit Alert ("Supplier needs to have delivered quotation.");
        }

        // define acceptance state that allows suppliers to participate in qualification auction
        supplier_acceptance_State[_supplier].supplier_accepted = true;
        emit Auction_Open("Accepted suppliers may start their bidding");
    }
   
    // get current accepted suppliers
    /////////////////////////////////
    function current_accepted_suppliers () public view returns (uint, address[] memory){
        return (total_accepted_suppliers, accepted_suppliers);
    }

    /////////////////////////////////
    // 4. Evaluation Announcement (buyer)
    /////////////////////////////////
    function announce_accepted_suppliers () public onlyBuyer returns(bool){
        require(reserve_price>0, "Prior stages not finished.");
        require (qualification_start==false, "The quotation evaluation has already been announced.");
        qualification_start = true;

        // pre-define winning_qualification_bids to be of reserve price
        for (uint j=0; j<total_winning_qualification_suppliers; j++){
            winning_qualification_bids.push(reserve_price);
            winning_qualification_suppliers.push(address(0));
        }

        emit Evaluation_Ended("The evaluation stage has ended and Thank you for participating. The qualification stage starts now. The accepted suppliers are", accepted_suppliers, winning_qualification_bids, winning_qualification_suppliers);      
        return true;
    }

    /////////////////////////////////
    // 5. Qualification Auction Stage (accepted suppliers)
    /////////////////////////////////            
    function qualification_auction (uint _qualification_bid) public onlySuppliers returns(bool) {
        require (qualification_start, "The quotations have not yet been evaluated.");
        require (supplier_acceptance_State[msg.sender].supplier_accepted, "You have not been accepted to the qualification auction.");
        require (block.timestamp < qualification_deadline, "Qualification period has ended.");
       
        // define current submited netto supplier_qualification_Bid (including bonus and malus) for accepted suppliers
        for (uint i=0; i<accepted_suppliers.length; i++){
            if (msg.sender == accepted_suppliers [i]){
                supplier_qualification_Bid[msg.sender].qualification_bid = _qualification_bid - supplier_Bonus[msg.sender].bonus + supplier_Malus[msg.sender].malus;

                // sort all currnet winning_qualification_bids in increasing order
                for (uint l=0; l<winning_qualification_bids.length-1; l++){
                    for (uint j=0; j<winning_qualification_bids.length-1; j++){
                        if(winning_qualification_bids[j] > winning_qualification_bids[j+1]){
                            uint current_value = winning_qualification_bids[j];
                            winning_qualification_bids[j] = winning_qualification_bids[j+1];
                            winning_qualification_bids[j+1] = current_value;

                            address current_address = winning_qualification_suppliers[j];
                            winning_qualification_suppliers[j] = winning_qualification_suppliers[j+1];
                            winning_qualification_suppliers[j+1] = current_address;
                        }
                    }
                }

                // compare current submited netto supplier_qualification_Bid with highest winning_qualification_bid and replace if lower (then sorted above ...)
                if(supplier_qualification_Bid[msg.sender].qualification_bid <= winning_qualification_bids[winning_qualification_bids.length-1] - bid_decrement){
    uint[] memory newQualBids = new uint[](winning_qualification_bids.length);
    address[] memory newSuppliers = new address[](winning_qualification_suppliers.length);

    for (uint j=0; j<newQualBids.length-1; i++){
        newQualBids[i] = winning_qualification_bids[i];
        if(i < newSuppliers.length) {
            newSuppliers[i] = winning_qualification_suppliers[i];
        }
    }

    // replace last element with current submited netto supplier_qualification_Bid
    newQualBids[newQualBids.length-1] = supplier_qualification_Bid[msg.sender].qualification_bid;
   
    if(msg.sender != address(0)) {
      newSuppliers[newSuppliers.length - 1] = msg.sender; // correct?
    }

    winning_qualification_bids = newQualBids;
    winning_qualification_suppliers = newSuppliers;

}
            }
            else emit Alert("Only accepted suppliers are allowed to bid");
        }
        return (true);
    }
 
    // get all currently qualified suppliers
    /////////////////////////////////
    function current_qualified_suppliers () public view returns (uint[] memory, address[] memory){
        return (winning_qualification_bids, winning_qualification_suppliers);  
    }

    /////////////////////////////////
    // 6. Qualification Announcement (buyer)
    /////////////////////////////////
    function announce_qualification_bids () public onlyBuyer returns(bool){
        require (block.timestamp > qualification_deadline, "Qualification period has not yet ended.");
        require(reserve_price>0, "Prior stages not finished.");
        require (auction_start==false, "The auction qualification has already been announced.");

        auction_start = true;

        // pre-define leading bid as lowest of the submitted qualification bids
        leading_bid = winning_qualification_bids[0];

        // define qualification state that allows suppliers to participate in final auction
        for (uint i=0; i<winning_qualification_suppliers.length; i++){
            supplier_qualification_State[winning_qualification_suppliers[i]].supplier_qualified = true;
        }
        emit Qualification_Ended("The qualification stage has ended and Thank you for participating. The auction stage starts now. The qualified suppliers and bids are", winning_qualification_suppliers, winning_qualification_bids);      
        return true;
    }

    /////////////////////////////////
    // 7. Final Auction Stage (qualified suppliers)
    /////////////////////////////////
    function final_auction (uint _bid) public onlySuppliers returns(bool) {
        require (auction_start, "Qualified suppliers not determined.");
        require (block.timestamp > qualification_deadline, "Qualification has not yet ended");
        require (supplier_qualification_State[msg.sender].supplier_qualified, "You have not qualified to the final auction.");
        require (block.timestamp < auction_deadline, "Auction period has ended.");

        // compare current submited netto supplier_Bid with highest leading_bid and replace if lower
        for (uint i=0; i<winning_qualification_suppliers.length; i++){
            if (msg.sender == winning_qualification_suppliers [i]){
                supplier_Bid[msg.sender].bid = _bid - supplier_Bonus[msg.sender].bonus + supplier_Malus[msg.sender].malus;
                if (supplier_Bid[msg.sender].bid <= leading_bid - bid_decrement){
                    leading_bid = supplier_Bid[msg.sender].bid;
                    winning_supplier = payable(msg.sender);
                }
                break;
            }
            else emit Attention("Only qualified suppliers are allowed to bid");
        }
        return (true);
    }

    // get currently winning supplier
    /////////////////////////////////
    function current_winning_supplier () public view returns (uint, address){
        return (leading_bid, winning_supplier);  
    }

    /////////////////////////////////
    // 8. Winner Announcement and Awarding (buyer)
    /////////////////////////////////
    function confirm_winning_bid () public payable onlyBuyer returns(bool){
        require (block.timestamp > auction_deadline, "Auction period has not yet ended.");
       
        emit Auction_Ended("The auction has ended and Thank you for participating. The winning supplier and bid is", winning_supplier, leading_bid);
        require(msg.value == leading_bid,"The amount does not equal the awarding bid price");
        (bool sent, ) = winning_supplier.call{value: leading_bid}("");
        require(sent, "Transfer to winning supplier failed.");

        return true;
    }

}
