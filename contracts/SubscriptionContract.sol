//SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract SubscriptionContract is Ownable {
  uint public nextPlanId;
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
  mapping(address => mapping(uint => Subscription)) public subscriptions;
  mapping(address => Subscription) public subscribers;

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

  function createPlan( string memory _name, uint amount) external onlyOwner{
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

    subscriptions[msg.sender][planId] = Subscription(
      msg.sender, 
      block.timestamp, 
      block.timestamp + plan.frequency,
      true
    );

    subscribers[msg.sender] = Subscription(
      msg.sender, 
      block.timestamp, 
      block.timestamp + plan.frequency,
      true
    );
    emit SubscriptionCreated(msg.sender, planId, block.timestamp, true);
  }

  function cancel(uint planId) external {
    Subscription storage subscriptionplan = subscriptions[msg.sender][planId];
    require(
      subscriptionplan.subscriber != address(0), 
      "subscriptionplan does not exist"
    );
    delete subscriptions[msg.sender][planId]; 
    emit SubscriptionCancelled(msg.sender, planId, block.timestamp, false);
  }

  function pay(address subscriber, uint planId) external payable {
    Subscription storage subscriptionplan = subscriptions[subscriber][planId];
    Plan storage plan = plans[planId];
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

  function isSubscriber(address _address) public view returns(bool){
      require(subscribers[_address].subscriber != address(0), "You need to subscribe first");
      require(
        block.timestamp < subscribers[_address].nextPayment,
        "You need to renew your subscription to continue"
      );
      console.log("envy",subscribers[_address].isSubscribed);
      console.log("bramy",subscribers[_address].subscriber);
      return subscribers[_address].isSubscribed;
  }
}