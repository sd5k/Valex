### Shared properties for miners and traders
from enum import Enum
from web3 import Web3, HTTPProvider, TestRPCProvider

class TradingPair(Enum):
    ETH_BTC = 0

class Network(Enum):
    LOCAL = 0
    TESTNET = 1
    MAINNET = 2

# set up, get w3 and exchange
def setUpW3(network):
    if network == Network.LOCAL:
        w3 = Web3(Web3.HTTPProvider("http://127.0.0.1:8545"))
    return w3

def setUpExchange(w3):
    exchangeFile = "./build/contracts/Exchange.json"
    exchangeABI = open(exchangeFile, "r").read()
    Exchange = w3.eth.contract(abi = exchangeABI)
    return Exchange

# exchangeAddress is the address of the exchange
def connectToExchange(Exchange, exchangeAddress):
    # Connects to exchange contract
    exchange = Exchange(address = exchangeAddress)
    return exchange

# trading_pair is the TradingPair to get the order book of
def getOrderBook(exchange, trading_pair):
    # returns a list (ordered by time)
    # of lists of fixed size, with members:
    #    buy_alpha (bool) is true if the order is a buy order (in alpha)
    #    volume (integer) is the volume in alpha (times 10^18)
    #    min_volume (integer) is the minimum volume in alpha (times 10^18)
    #    limit is the limit price for the sale in (alpha / beta times 10^18)
    return exchange.getOrderChapter(trading_pair)
