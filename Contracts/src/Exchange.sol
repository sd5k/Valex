pragma solidity ^0.4.17;

import './Swap.sol';
import '../libs/SafeMathLib.sol';

contract Exchange {
  using SafeMathLib for uint;

  // fee parameters and such
  struct Parameters{
    //wei per eth
    uint depositPerUnit;
    uint closureFeePerUnit;
    uint withdrawalFeePerUnit;
    // fixed gas fee (Everything should run in O(1) time)
    // valuated in gas (so remember to multiply by tx.gasprice)
    uint gasFee;
    // Order margin for error (match), expressed as margin[0] units/margin[1] units
    uint[2] margin;
    // Size at which we should clean an order book
    uint cleanSize;
    // Proportion of fees that miners get
    // We round up so that micro-orders don't get backlogged (add 1 on closure)
    uint[2] minerShare;
  }

  // stores active balances
  struct Balances{
    // separate out the open balance (includes deposit, gas fees),
    // which will be distributed between miners, the exchange, and traders,
    // from closed balance, which belongs to the exchange
    uint openBalance;
    uint closedBalance;
  }

  // stores order info (public information)
  struct Order{
    // false for buy ETH, true for sell ETH
    bool buyETH;
    uint volume;
    uint unitLimit;
  }

  // stores address info on people placing orders (private information)
  struct AddressInfo{
    address ethAddress;
    string otherAddress;
  }

  Parameters params;
  Balances private balances;

  // separate chapters for different currency pairs
  // that's why they're 2D
  Order[][] orderbook;
  AddressInfo[][] private addressBook;

  // Checks edge cases for match verification
  function checkMatchEdges(uint chapter, uint index1, uint index2)
    private
    returns(bool passes)
  {
    // valid chapter
    if (chapter >= this.orderBook.length){
      return false;
    }
    // valid indices
    if ((index1 >= this.orderBook[chapter].length) ||
          (index2 >= this.orderBook[chapter].length)){
      return false;
    }
    //One buy order and one sell order
    if (this.orderBook[chapter][index1].buyETH == this.orderBook[chapter][index2].buyETH){
      return false;
    }
    if ((this.orderBook[chapter][index1].volume == 0 ) ||
          (this.orderBook[chapter][index2].volume == 0)){
      return false;
    }
    return true;
  }

  // verifies that match is valid
  function isValidMatch(uint chapter, uint index1, uint index2)
    private
    returns(bool isValid)
  {
    // check edge cases
    if (! checkMatchEdges(chapter, index1, index2)){
      return false;
    }
    // which order is buying and selling ETH?
    uint buyIndex;
    uint sellIndex;
    if (this.orderBook[chapter][index1].buyETH){
      buyIndex = index1;
      sellIndex = index2;
    }
    else{
      buyIndex = index2;
      sellIndex = index1;
    }
    // shorthand for buy and sell orders
    Order buyOrder = this.orderBook[chapter][buyIndex];
    Order sellOrder = this.orderbook[chapter][sellIndex];

    // Non-contradictory limits
    // TODO: DEBUGGING: verify that this is the correct equation
    if (buyOrder.unitLimit *
        sellOrder.unitLimit <= 1){
      return false;
    }
    // Volumes comparable
    if (buyOrder.volume > sellOrder.volume){
      if (buyOrder.volume * margin[0] > sellOrder.volume * margin[1]){
        return false;
      }
    }
    if (sellOrder.volume > buyOrder.volume){
      if (sellOrder.volume * margin[0] > buyOrder.volume * margin[1]){
        return false;
      }
    }
    return true;
  }

  // Clears closed trade, reenters into order book if incomplete
  function clearTrade(uint chapter, uint index1, uint index2)
    private
  {
    if (this.orderBook[chapter][index1].volume < this.orderBook[chapter][index2].volume){
      delete this.orderBook[chapter][index1].volume;
      this.orderBook[chapter][index2].volume = (this.orderBook[chapter][index2].volume -
                                                this.orderBook[chapter][index1].volume)
      delete this.addressBook[chapter][index1].volume;
    }
    else if (this.orderBook[chapter][index1].volume > this.orderBook[chapter][index2].volume){
      delete this.orderBook[chapter][index2].volume;
      this.orderBook[chapter][index1].volume = (this.orderBook[chapter][index1].volume -
                                                this.orderBook[chapter][index2].volume)
      delete this.addressBook[chapter][index2].volume;
    }
    else{
      delete this.orderBook[chapter][index1].volume;
      delete this.orderBook[chapter][index2].volume;
      delete this.addressBook[chapter][index1].volume;
      delete this.addressBook[chapter][index2].volume;
    }
    return;
  }

  // Placeholder: messages traders transaction details
  // Calculates exchange rate for trade using limits (meet in middle)
  function messageTraders(uint chapter, uint index1, uint index2)
    private
  {}

  function makeMatch(uint chapter, uint index1, uint index2)
    public
    returns(bool isValid)
  {
    require(msg.value >= this.params.gasFee * tx.gasprice);
    if (! isValidMatch(chapter, index1, index2)){
      return false;
    }
    uint volCleared;
    if (this.orderBook[chapter][index1].volume < this.orderBook[chapter][index2].volume){
      volCleared = this.orderBook[chapter][index1].volume
    }
    else{
      volCleared = this.orderBook[chapter][index2].volume
    }
    // calculate the miner's payment
    // rounds up, because of the + 1
    uint minerPayment = (((this.params.minerShare[0] * volCleared) / this.params.minerShare[1])
                          + this.params.gasFee * tx.gasprice + 1)
    msg.sender.transfer(minerPayment);
    clearTrade(chapter, index1, index2);
    messageTraders(chapter, index1, index2);
    return true;
  }

  // deploy a new swap contract (not functional)
  function newSwap()
    private
    returns(address newContract)
  {
    Swap s = new Swap();
    return s;
  }
}
