pragma solidity ^0.4.8;

import "./expiring_market.sol";

// Simple Market with a market lifetime. When the lifetime has elapsed,
// offers can only be cancelled (offer and buy will throw).

contract AuthMarket is ExpiringMarket {
    
    function AuthMarket(uint lifetime_) ExpiringMarket(lifetime_) {
    }

    function offer( uint sell_how_much, ERC20 sell_which_token
                  , uint buy_how_much,  ERC20 buy_which_token )
        auth
        returns (uint id)
    {
        id = super.offer(sell_how_much, sell_which_token, buy_how_much, buy_which_token);
    }

    function buy( uint id, uint quantity )
        auth
        returns ( bool success )
    {
        success = super.buy(id, quantity);
    }
}
