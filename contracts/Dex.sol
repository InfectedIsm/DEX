//SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.15;
//Below solidity pragma statement (needed because we return an array of struct in function):
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';


contract Dex {
    
    address public admin; //admin address with privilege access to certain functions (shouldn't it be private?)

    //token related variables/events
    struct Token {
        bytes32 ticker;
        address tokenAddress;
    }
    
    mapping(bytes32 => Token) public tokens; //mapping linking tokens' names to their info (ticker and address)    
    bytes32[] public tokenList; //list of all existing tokens 
    mapping(address => mapping(bytes32 => uint)) public traderBalances; //trader (address) balance (uint) of each tokens (bytes32)
    bytes32 constant DAI = bytes32('DAI'); //better readability in the code + gas efficient as we cast the value only once

    //order related variables/events
    enum Side {
        BUY,
        SELL
    }

    struct Order {
        uint id;
        address trader;
        Side side;
        bytes32 ticker;
        uint amount;
        uint filled;
        uint price;
        uint date;
    }

    event NewTrade(
        uint tradeId,
        uint orderId,
        bytes32 indexed ticker,
        address indexed trader1,
        address indexed trader2,
        uint amount,
        uint price,
        uint date
    );

    mapping(bytes32 => mapping(uint => Order[])) public orderBook; //uint here is the Side, as enum can be casted to uint
    uint public nextOrderId;
    uint public nextTradeId;


    //FUNCTIONS //

    constructor() {
        admin = msg.sender;
    }

    function addToken(
        bytes32 ticker, 
        address tokenAddress) 
        onlyAdmin 
        external 
    {
        tokens[ticker] = Token(ticker, tokenAddress);
        tokenList.push(ticker);
    }

    //pragma experimental ABIEncoderV2 used above because we return an array of struct;
    function getOrders(
        bytes32 ticker,
        Side side) 
        external
        view
        returns(Order[] memory)
    {
        return orderBook[ticker][uint(side)];
    }


    //make an article on how to export a mapping to a front-end
    function getTokens() 
      external 
      view 
      returns(Token[] memory) {
      Token[] memory _tokens = new Token[](tokenList.length);
      for (uint i = 0; i < tokenList.length; i++) {
        _tokens[i] = Token(
          tokens[tokenList[i]].ticker,
          tokens[tokenList[i]].tokenAddress
        );
      }
      return _tokens;
    }

    // user balance interaction functions //

    function deposit(
        uint amount, 
        bytes32 ticker)
        tokenExist(ticker) 
        external 
    {
        IERC20(tokens[ticker].tokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        traderBalances[msg.sender][ticker] += amount;
    }

    function withdraw(
        uint amount,
        bytes32 ticker)
        tokenExist(ticker)
        external
    {
        require(traderBalances[msg.sender][ticker] >= amount, "unsuficient balance");
        traderBalances[msg.sender][ticker] -= amount;
        IERC20(tokens[ticker].tokenAddress).transfer(msg.sender, amount);
    }

    // orders functions //

    function createLimitOrder(
        bytes32 ticker,
        uint amount,
        uint price,
        Side side
        )
        tokenExist(ticker)
        tokenIsNotDai(ticker)
        external
    {
        if (side == Side.SELL) {
            require(traderBalances[msg.sender][ticker] >= amount, "token balance too low");
        } else {
            require(traderBalances[msg.sender][DAI] >= amount*price, "DAI balance too low");
        }
        //pointer to orderBook[ticker][side] /!\ and not a new storage as we could think
        Order [] storage orders = orderBook[ticker][uint(side)];
        orders.push(Order(nextOrderId, msg.sender, side,ticker,amount,0,price,block.timestamp));
        
        uint i = orders.length -1;
        while (i>0){
            if(side == Side.BUY && orders[i-1].price > orders[i].price){
                break;
            }
            if(side == Side.SELL && orders[i-1].price < orders[i].price){
                break;
            }
            Order memory order = orders[i -1];
            orders[i-1] = orders [i];
            orders [i] = order;
            i--;
        }
        nextOrderId ++;
    }

    function createMarketOrder(
        bytes32 ticker,
        uint amount,
        Side side
        )
        tokenExist(ticker)
        tokenIsNotDai(ticker)
        external
    {
        if (side == Side.SELL) {
            require(traderBalances[msg.sender][ticker] >= amount, "token balance too low");
        }
        //if we buy, we want to check seller order book, if we sell, the opposite
        Order[] storage orders = orderBook[ticker]
        [uint(side == Side.BUY ? Side.SELL : Side.BUY)];
        uint i;
        uint remaining = amount;

        while(i < orders.length && remaining > 0) {
            //here we don't search for the better price, we fill orders from older to newer
            uint available = orders[i].amount - orders[i].filled;
            uint matched = (remaining > available) ? available : remaining;
            remaining -= matched;
            orders[i].filled += matched;
            emit NewTrade(
                nextTradeId,
                orders[i].id, 
                ticker, 
                orders[i].trader, 
                msg.sender,
                matched,
                orders[i].price,
                block.timestamp);

            if(side == Side.SELL) {
                traderBalances[msg.sender][ticker] -= matched;
                traderBalances[msg.sender][DAI] += matched*orders[i].price;
                traderBalances[orders[i].trader][ticker] += matched;
                traderBalances[orders[i].trader][DAI] -= matched*orders[i].price;                
            }

            if(side == Side.BUY) {
                require(traderBalances[msg.sender][DAI] >=matched*orders[i].price, "DAI balance too low");
                traderBalances[msg.sender][ticker] += matched;
                traderBalances[msg.sender][DAI] -= matched*orders[i].price;
                traderBalances[orders[i].trader][ticker] -= matched;
                traderBalances[orders[i].trader][DAI] += matched*orders[i].price;                
            }
            nextTradeId++;
            i++;
        }
        i = 0;
        //we start from the begining of orderbook, each time an order is filled
        //we shift the whole array left, and pop the last element as it is a duplicate of last one
        while (i <orders.length && orders[i].filled == orders[i].amount) {
            for(uint j = i; j < orders.length - 1; j++){
                orders[j] = orders[j+1];
            }
            orders.pop();
            i++;
        }
    }
    
    // modifiers //

    modifier tokenExist(bytes32 ticker) {
        require(tokens[ticker].tokenAddress != address(0), "this token does not exist");
        _;
    }

    modifier tokenIsNotDai(bytes32 ticker) {
        require( ticker != DAI, 'cannot trade DAI');
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }
}
