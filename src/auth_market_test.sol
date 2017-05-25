pragma solidity ^0.4.8;

import "ds-test/test.sol";
import "ds-token/base.sol";
import "ds-roles/roles.sol";

import "./auth_market.sol";
import "./simple_market_test.sol";

contract AuthMarketTester {
    TestableAuthMarket market;
    function AuthMarketTester(TestableAuthMarket market_) {
        market = market_;
    }
    function doApprove(address spender, uint value, ERC20 token) {
        token.approve(spender, value);
    }
    function doBuy(uint id, uint buy_how_much) returns (bool _success) {
        return market.buy(id, buy_how_much);
    }
    function doOffer( uint sell_how_much, ERC20 sell_which_token
                  , uint buy_how_much,  ERC20 buy_which_token ) returns (uint _id) {
        return market.offer(sell_how_much, sell_which_token, buy_how_much, buy_which_token);
    }
    function doCancel(uint id) returns (bool _success) {
        return market.cancel(id);
    }
}

contract TestableAuthMarket is AuthMarket(1 weeks) {
    uint public time;
    function getTime() constant returns (uint) {
        return time;
    }
    function addTime(uint extra) {
        time += extra;
    }
}

// Test expiring market retains behaviour of simple market
contract AuthSimpleMarketTest is SimpleMarketTest {
    AuthMarketTester user2;
    function setUp() {
        otc = new TestableAuthMarket();
        user2 = new AuthMarketTester(TestableAuthMarket(otc));

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);

        dai.transfer(user2, 100);
        user2.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);
    }
}

// Expiry specific tests
contract AuthMarketTest is DSTest {
    AuthMarketTester user2;
    ERC20 dai;
    ERC20 mkr;
    TestableAuthMarket otc;
    DSRoles mom;

    function setUp() {
        otc = new TestableAuthMarket();
        user2 = new AuthMarketTester(otc);

        mom = new DSRoles();
        otc.setAuthority(mom);
        mom.setRootUser(this, true);
        mom.setRoleCapability(1, otc, bytes4(sha3("buy(uint256,uint256)")), true);
        mom.setRoleCapability(1, otc, bytes4(sha3("offer(uint256,address,uint256,address)")), true);
        mom.setUserRole(user2, 1, true);

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);

        dai.transfer(user2, 100);
        mkr.transfer(user2, 100);
        user2.doApprove(otc, 100, dai);
        user2.doApprove(otc, 100, mkr);
        mkr.approve(otc, 30);
    }
    function testIsClosedBeforeExpiry() {
        assert(!otc.isClosed());
    }
    function testIsClosedAfterExpiry() {
        otc.addTime(AuthMarket(otc).lifetime() + 1 seconds);
        assert(otc.isClosed());
    }
    function testOfferBeforeExpiry() {
        otc.offer( 30, mkr, 100, dai );
    }
    function testFailOfferAfterExpiry() {
        otc.addTime(AuthMarket(otc).lifetime() + 1 seconds);
        otc.offer( 30, mkr, 100, dai );
    }
    function testCancelBeforeExpiry() {
        var id = otc.offer( 30, mkr, 100, dai );
        otc.cancel(id);
    }
    function testFailCancelNonOwnerBeforeExpiry() {
        var id = otc.offer( 30, mkr, 100, dai );
        user2.doCancel(id);
    }
    function testCancelNonOwnerAfterExpiry() {
        var id = otc.offer( 30, mkr, 100, dai );
        otc.addTime(otc.lifetime() + 1 seconds);

        assert(otc.isActive(id));
        assert(user2.doCancel(id));
        assert(!otc.isActive(id));
    }
    function testBuyBeforeExpiry() {
        var id = user2.doOffer( 30, mkr, 100, dai );
        assert(user2.doBuy(id, 30));
    }
    function testFailBuyAfterExpiry() {
        var id = otc.offer( 30, mkr, 100, dai );
        otc.addTime(otc.lifetime() + 1 seconds);
        user2.doBuy(id, 30);
    }
}

contract ExpiringTransferTest is TransferTest {
    AuthMarketTester user2;
    function setUp() {
        otc = new TestableAuthMarket();
        user2 = new AuthMarketTester(TestableAuthMarket(otc));

        dai = new DSTokenBase(10 ** 9);
        mkr = new DSTokenBase(10 ** 6);

        dai.transfer(user2, 100);
        user2.doApprove(otc, 100, dai);
        mkr.approve(otc, 30);
    }
}

contract ExpiringOfferTransferTest is OfferTransferTest, ExpiringTransferTest {}
contract ExpiringBuyTransferTest is BuyTransferTest, ExpiringTransferTest {}
contract ExpiringPartialBuyTransferTest is PartialBuyTransferTest, ExpiringTransferTest {}

contract ExpiringCancelTransferTest is CancelTransferTest
                                     , ExpiringTransferTest
{
    function testCancelAfterExpiryTransfersFromMarket() {
        var id = otc.offer( 30, mkr, 100, dai );
        TestableAuthMarket(otc).addTime(
            AuthMarket(otc).lifetime() + 1 seconds
        );

        var balance_before = mkr.balanceOf(otc);
        otc.cancel(id);
        var balance_after = mkr.balanceOf(otc);

        assertEq(balance_before - balance_after, 30);
    }
    function testCancelAfterExpiryTransfersToSeller() {
        var id = otc.offer( 30, mkr, 100, dai );
        TestableAuthMarket(otc).addTime(
            AuthMarket(otc).lifetime() + 1 seconds
        );

        var balance_before = mkr.balanceOf(this);
        user2.doCancel(id);
        var balance_after = mkr.balanceOf(this);

        assertEq(balance_after - balance_before, 30);
    }
}
