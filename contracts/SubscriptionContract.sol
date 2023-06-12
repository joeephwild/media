//SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract SubscriptionContract is Ownable {
  uint public nextPlanId = 1;
  struct Plan {
    address artist;
    string name;
    uint amount;
    uint frequency;
  }
  struct Subscription {
    address subscriber;
    uint start;
    uint nextPayment;
    bool isSubscribed;
  }
  mapping(uint => Plan) public plans;
  //mapping(address => mapping(uint => Subscription)) public subscriptions;
  // mapping(address => mapping(address => uint[])) public artistsubscriberplans;
  mapping(address => mapping(address => mapping(uint => Subscription))) public subscriptions;

  event PlanCreated(
    address artist,
    string name,
    uint planId,
    uint date
  );
  event SubscriptionCreated(
    address subscriber,
    uint planId,
    uint date,
    bool isSubscribed
  );
  event SubscriptionCancelled(
    address subscriber,
    uint planId,
    uint date,
    bool isSubscribed
  );
  event PaymentSent(
    address from,
    address to,
    uint amount,
    uint planId,
    uint date
  );

  function createPlan( string memory _name, uint amount) external {
    require(amount > 0, "amount needs to be > 0");
      plans[nextPlanId] = Plan(
      msg.sender, 
      _name,
      amount, 
      30 days
    );
    nextPlanId++;
  }

  function subscribe(uint planId) external payable {
    Plan storage plan = plans[planId];
    require(plan.artist != address(0), "this plan does not exist");
    payable(plan.artist).transfer(plan.amount);
    emit PaymentSent(
      msg.sender, 
      plan.artist, 
      plan.amount, 
      planId, 
      block.timestamp
    );

    // subscriptions[msg.sender][planId] = Subscription(
    //   msg.sender, 
    //   block.timestamp, 
    //   block.timestamp + plan.frequency,
    //   true
    // );

    subscriptions[plan.artist][msg.sender][planId] = Subscription(
      msg.sender, 
      block.timestamp, 
      block.timestamp + plan.frequency,
      true
    );

    emit SubscriptionCreated(msg.sender, planId, block.timestamp, true);
  }

  function cancel(uint planId) external {
    Plan storage plan = plans[planId]; 
    Subscription storage subscriptionplan = subscriptions[plan.artist][msg.sender][planId];
    require(
      subscriptionplan.subscriber != address(0), 
      "subscriptionplan does not exist"
    );
    delete subscriptions[plan.artist][msg.sender][planId]; 
    emit SubscriptionCancelled(msg.sender, planId, block.timestamp, false);
  }

  function pay(address subscriber, uint planId) external payable {
    Plan storage plan = plans[planId];
    Subscription storage subscriptionplan = subscriptions[plan.artist][subscriber][planId];
    
    require(
      subscriptionplan.subscriber != address(0), 
      "subscription plan does not exist or you have not yet subscribed"
    );
    require(
      block.timestamp > subscriptionplan.nextPayment,
      "not due yet"
    );
    payable(plan.artist).transfer(plan.amount);
    emit PaymentSent(
      subscriber,
      plan.artist, 
      plan.amount, 
      planId, 
      block.timestamp
    );
    subscriptionplan.nextPayment = subscriptionplan.nextPayment + plan.frequency;
  }

  function isSubscriber(address artistAddress, address _address, uint planId) public view returns(bool){
      require(subscriptions[artistAddress][_address][planId].subscriber != address(0), "You need to subscribe first");
      require(
        block.timestamp < subscriptions[artistAddress][_address][planId].nextPayment,
        "You need to renew your subscription to continue"
      );
      return subscriptions[artistAddress][_address][planId].isSubscribed;
  }

  function getMyPlans() public view returns (Plan[] memory) {
        uint totalItemCount = nextPlanId;
        uint itemCount = 0;
        uint currentIndex = 0;
        uint currentId;
        //Important to get a count of all the NFTs that belong to the user before we can make an array for them
        for(uint i=0; i < totalItemCount; i++)
        {
            if(plans[i+1].artist == msg.sender){
                itemCount += 1;
            }
        }

        //Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        Plan[] memory items = new Plan[](itemCount);
        for(uint i=0; i < totalItemCount; i++) {
            if(plans[i+1].artist == msg.sender) {
                currentId = i+1;
                Plan storage currentItem = plans[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
  }

}