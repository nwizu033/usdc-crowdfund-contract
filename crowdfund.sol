// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.11;

// USDC contract interface
interface USDC {
    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract usdcCrowdfund {
    // instance of the usdc token for the contract
    USDC public usdc;

    // Contract Owner
    address payable public owner;

    // id for campaigns
    uint256 public id;

    // mapping to store listed campaigns
    mapping(uint256 => Campaign) public campaigns;

    // mapping to store amount pledged by an address to a particular campaign
    mapping(uint256 => mapping(address => uint256)) public pledgeAmount;

    // second mapping for iteration purpose (to be able to loop through the campaigns mapping)
    // mapping(uint => bool) public inserted;
    // Campaign[] public keys;

    // How an individual campaign is structured
    struct Campaign {
        address payable Owner;
        string Title;
        string Purpose;
        uint256 Target;
        uint256 StartTime;
        uint256 EndTime;
        uint256 Raised;
        bool Withdrawn;
    }

    constructor(address usdcContractAddress) {
        usdc = USDC(usdcContractAddress);
        owner = payable(msg.sender);
        // USDC contract: 0x07865c6e87b9f70255377e024ace6630c1eaa37f
    }

    // function to list/open a campaign
    function listCampaign(
        string memory _title,
        string memory _purpose,
        uint256 _target,
        uint256 _starttime,
        uint256 _endtime
    ) public {
        uint256 starting = block.timestamp + (_starttime * 1 minutes);
        uint256 ending = starting + (_endtime * 1 minutes);
        uint256 target = _target * (10**6);
        require(msg.sender != address(0), "Not a valid address");
        require(_target > 0, "target must be greater than 0");
        require(ending > starting, "invalid start time");

        // increase the id count
        id += 1;

        // update the campaign at this id with the the campaign structure
        campaigns[id] = Campaign({
            Owner: payable(msg.sender),
            Title: _title,
            Purpose: _purpose,
            Target: target,
            StartTime: starting,
            EndTime: ending,
            Raised: 0,
            Withdrawn: false
        });

        // loop through the map and return an array
        // if(!inserted[id]) {
        //     inserted[id] = true;
        //     keys.push(campaigns[id]);
        // }
    }

    // function to pledge to a prticular campaign.
    function pledge(uint256 _id, uint256 _amount) public payable {
        //  get the instance of the campaign at that particular id
        Campaign storage campaign = campaigns[_id];

        // convert the input amount into usdc decimals
        uint256 amount = _amount * (10**6);

        require(
            block.timestamp > campaign.StartTime,
            "campaign is yet to start"
        );
        require(block.timestamp <= campaign.EndTime, "campaign closed");

        campaign.Raised += amount;
        pledgeAmount[_id][msg.sender] += amount;
        usdc.transferFrom(msg.sender, address(this), amount);
    }

    // function to withdraw amount raised at the end of the campaign
    function withdraw(uint256 _id) public {
        //  get the instance of the campaign at that particular id
        Campaign storage campaign = campaigns[_id];

        // campaign withdrawal amount after 2% tax to the owner of the contract
        uint256 withdrawAmount = (campaign.Raised * 9800) / 10000;

        // owner of contract's share
        uint256 ownerShare = (campaign.Raised * 200) / 10000;

        // ensure the campaign is over & withdrawer is the owner of the campign and it's not already withdrawn
        require(msg.sender == campaign.Owner, "not owner of campaign");
        require(block.timestamp > campaign.EndTime, "campaign still going on");
        require(!campaign.Withdrawn, "already withdrawn");

        // transfer cmapaign owner's share and tax to contract owner
        usdc.transfer(msg.sender, withdrawAmount);
        usdc.transfer(owner, ownerShare);
        campaign.Withdrawn = true;
    }

    // Function to view campaigns (this is not gas efficieent anyways)
    function seeCampaigns() public view returns (Campaign[] memory) {
        Campaign[] memory arr = new Campaign[](id);
        for (uint256 i = 0; i < id; i++) {
            arr[i] = campaigns[i + 1];
        }
        return arr;
    }

    // Time getter function
    function getTime() public view returns (uint256) {
        return (block.timestamp);
    }
}
