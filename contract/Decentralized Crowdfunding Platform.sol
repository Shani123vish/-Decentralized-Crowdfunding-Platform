// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        bool goalReached;
    }
    
    struct Contribution {
        address contributor;
        uint256 amount;
        uint256 timestamp;
    }
    
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => Contribution[]) public campaignContributions;
    mapping(uint256 => mapping(address => uint256)) public contributorAmounts;
    
    uint256 public campaignCounter;
    uint256 public platformFeePercentage = 2; // 2% platform fee
    address public platformOwner;
    
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );
    
    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this");
        _;
    }
    
    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }
    
    modifier campaignActive(uint256 _campaignId) {
        require(campaigns[_campaignId].isActive, "Campaign is not active");
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign deadline has passed");
        _;
    }
    
    constructor() {
        platformOwner = msg.sender;
    }
    
    // Core Function 1: Create Campaign
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);
        
        campaigns[campaignCounter] = Campaign({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            isActive: true,
            goalReached: false
        });
        
        emit CampaignCreated(campaignCounter, msg.sender, _title, _goalAmount, deadline);
        
        uint256 currentCampaignId = campaignCounter;
        campaignCounter++;
        
        return currentCampaignId;
    }
    
    // Core Function 2: Contribute to Campaign
    function contributeToCampaign(uint256 _campaignId) 
        external 
        payable 
        campaignExists(_campaignId) 
        campaignActive(_campaignId) 
    {
        require(msg.value > 0, "Contribution must be greater than 0");
        require(msg.sender != campaigns[_campaignId].creator, "Creator cannot contribute to own campaign");
        
        Campaign storage campaign = campaigns[_campaignId];
        
        // Add contribution
        campaign.raisedAmount += msg.value;
        contributorAmounts[_campaignId][msg.sender] += msg.value;
        
        campaignContributions[_campaignId].push(Contribution({
            contributor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));
        
        // Check if goal is reached
        if (campaign.raisedAmount >= campaign.goalAmount && !campaign.goalReached) {
            campaign.goalReached = true;
        }
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }
    
    // Core Function 3: Withdraw/Refund Management
    function withdrawFunds(uint256 _campaignId) 
        external 
        campaignExists(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Only campaign creator can withdraw");
        require(block.timestamp >= campaign.deadline, "Campaign is still active");
        require(campaign.goalReached, "Campaign goal was not reached");
        require(campaign.raisedAmount > 0, "No funds to withdraw");
        
        uint256 totalAmount = campaign.raisedAmount;
        uint256 platformFee = (totalAmount * platformFeePercentage) / 100;
        uint256 creatorAmount = totalAmount - platformFee;
        
        campaign.raisedAmount = 0;
        campaign.isActive = false;
        
        // Transfer funds
        campaign.creator.transfer(creatorAmount);
        payable(platformOwner).transfer(platformFee);
        
        emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount);
    }
    
    function requestRefund(uint256 _campaignId) 
        external 
        campaignExists(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign is still active");
        require(!campaign.goalReached, "Campaign goal was reached, no refunds available");
        require(contributorAmounts[_campaignId][msg.sender] > 0, "No contributions found");
        
        uint256 refundAmount = contributorAmounts[_campaignId][msg.sender];
        contributorAmounts[_campaignId][msg.sender] = 0;
        campaign.raisedAmount -= refundAmount;
        
        payable(msg.sender).transfer(refundAmount);
        
        emit RefundIssued(_campaignId, msg.sender, refundAmount);
    }
    
    // View Functions
    function getCampaignDetails(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isActive,
            bool goalReached
        ) 
    {
        Campaign memory campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive,
            campaign.goalReached
        );
    }
    
    function getContributionCount(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (uint256) 
    {
        return campaignContributions[_campaignId].length;
    }
    
    function getMyContribution(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (uint256) 
    {
        return contributorAmounts[_campaignId][msg.sender];
    }
    
    // Platform Management
    function updatePlatformFee(uint256 _newFeePercentage) 
        external 
        onlyPlatformOwner 
    {
        require(_newFeePercentage <= 5, "Platform fee cannot exceed 5%");
        platformFeePercentage = _newFeePercentage;
    }
}
