// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Edenhall} from "../src/Edenhall.sol";
import {BlackJack} from "../src/Blackjack.sol";
import {Test, console2, console} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {info} from "src/library/info.sol";
import {BlackjackUtils} from "src/BlackjackUtils.sol";

contract BlackJackTest is Test {
    struct PlayerStates {
        bool playerBust;
        uint8 playerCards;
        bool playerStand;
        bool playerHit;
        bool playerJoined;
    }

    Edenhall public EH;
    VRFCoordinatorV2_5Mock public vrf;
    BlackjackUtils public BJU;

    address alice = makeAddr("user");
    address bob = makeAddr("bob");
    address cas = makeAddr("cas");
    address mei = makeAddr("mei");
    address son = makeAddr("son");
    address kim = makeAddr("kim");
    address job = makeAddr("job");

    // Errors
    error GameHasAlreadyStarted();
    error CardsAmountIs21OrAbove();
    error NotAPlayer();
    error PlayerHasAlreadyBusted();

    // Player Events
    event PlayerDrawn(address player, uint8 card, uint8 suit);
    event PlayerBust(address player, uint8 card);
    event PlayerWon(address player, uint8 card);
    event PlayerKicked(address player);
    event PlayerLeft(address player);
    event PlayerJoined(address player);
    event BlackjackPlayer(address winner, uint8 card); // fix this.

    // Dealer Events
    event BlackjackHouse(uint256 amount);
    event DealerBusted(uint8 value);
    event CardDrawnDealer(uint8 value, uint8 suit);
    event DelaerWon(uint8 card);

    uint256 subID;
    address table;

    function setUp() external {
        // Launch Edenhall contract.

        BJU = new BlackjackUtils();

        EH = new Edenhall(address(BJU));

        // setup chainlink
        vrf = new VRFCoordinatorV2_5Mock(1 ether, 0.1 ether, 0.047 ether);

        EH.setVRF(address(vrf));
        uint256 subId = vrf.createSubscription();

        vrf.fundSubscription(subId, 10000000000 ether);

        EH.setSubbie(subId);

        subID = subId;
    }

    modifier createdTable() {
        vm.startPrank(alice);

        Edenhall.GameInfo memory Params =
            Edenhall.GameInfo({private_game: false, max_players: 3, invite_code: 0, table_owner: alice});
        address[] memory invitedPlayers = new address[](1);
        invitedPlayers[0] = alice;

        address Table = EH.play(Params, invitedPlayers);
        vm.stopPrank();
        vrf.addConsumer(subID, Table);
        table = Table;
        _;
    }

    modifier privateTable() {
        vm.startPrank(alice);

        Edenhall.GameInfo memory Params =
            Edenhall.GameInfo({private_game: true, max_players: 3, invite_code: 0, table_owner: alice});
        address[] memory invitedPlayers = new address[](2);
        invitedPlayers[0] = address(alice);
        invitedPlayers[1] = address(bob);

        address Table = EH.play(Params, invitedPlayers);
        vm.stopPrank();
        vrf.addConsumer(subID, Table);
        table = Table;
        _;
    }

    modifier multiplePlayerTable() {
        vm.startPrank(alice);
        Edenhall.GameInfo memory Params =
            Edenhall.GameInfo({private_game: false, max_players: 3, invite_code: 0, table_owner: alice});
        address[] memory invitedPlayers = new address[](1);
        invitedPlayers[0] = alice;

        address Table = EH.play(Params, invitedPlayers);

        table = Table;

        vm.stopPrank();
        vrf.addConsumer(subID, Table);

        // playerTwo Bob
        vm.startPrank(bob);
        BlackJack(table).joinTable(address(bob));

        // playerThree Cas
        vm.startPrank(cas);
        BlackJack(table).joinTable(address(cas));

        // playerFour mei
        vm.startPrank(mei);
        BlackJack(table).joinTable(address(mei));

        // playerFive Son
        vm.startPrank(son);
        BlackJack(table).joinTable(address(son));

        // playerSix kim
        vm.startPrank(kim);
        BlackJack(table).joinTable(address(kim));

        // playerSeven Job
        vm.startPrank(job);
        BlackJack(table).joinTable(address(job));

        _;
    }

    modifier multiplePlayerPrivateTable() {
        vm.startPrank(alice);
        Edenhall.GameInfo memory Params =
            Edenhall.GameInfo({private_game: true, max_players: 7, invite_code: 0, table_owner: alice});
        address[] memory invitedPlayers = new address[](7);
        invitedPlayers[0] = alice;
        invitedPlayers[1] = bob;
        invitedPlayers[2] = cas;
        invitedPlayers[3] = mei;
        invitedPlayers[4] = son;
        invitedPlayers[5] = kim;
        invitedPlayers[6] = job;

        address Table = EH.play(Params, invitedPlayers);

        table = Table;
        vm.stopPrank();
        vrf.addConsumer(subID, Table);

        // playerTwo Bob
        vm.startPrank(bob);
        BlackJack(table).joinPrivateTable(address(bob));

        // playerThree Cas
        vm.startPrank(cas);
        BlackJack(table).joinPrivateTable(address(cas));

        // playerFour mei
        vm.startPrank(mei);
        BlackJack(table).joinPrivateTable(address(mei));

        // playerFive Son
        vm.startPrank(son);
        BlackJack(table).joinPrivateTable(address(son));

        // playerSix kim
        vm.startPrank(kim);
        BlackJack(table).joinPrivateTable(address(kim));

        // playerSeven Job
        vm.startPrank(job);
        BlackJack(table).joinPrivateTable(address(job));

        _;
    }

    function test_playWorks_Correctly() public createdTable {
        vm.startPrank(alice);
        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        vm.stopPrank();

        assert(BlackJack(table).getCards(alice) > 0);
        assert(info.getHouseCards(address(table)) > 0);
    }

    function test_PlayerCanLeaveTable() public createdTable {
        assert(BlackJack(table).getPlayer(0) != address(0));

        vm.startPrank(alice);

        assertEq(BlackJack(table).getPlayer(0), address(alice));

        vm.startPrank(bob);

        assertEq(BlackJack(table).getPlayers(), 1);

        BlackJack(table).joinTable(address(bob));
        assertEq(BlackJack(table).getPlayers(), 2);

        BlackJack(table).leaveTable(address(bob));

        assertEq(BlackJack(table).getPlayers(), 1);
    }

    function test_CardsShouldBeShuffledDuringPlay() public createdTable {
        vm.startPrank(alice);

        BlackJack(table).StartGame();
        vm.stopPrank();
        assertEq(info.getCardsRemaining(table), 52);
    }

    function test_StandWorksForOnlyPlayersAndCannotHit() public createdTable {
        vm.startPrank(alice);

        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        vm.startPrank(alice);
        BlackJack(table).stand();
        vm.expectRevert();
        BlackJack(table).drawCard();
    }

    function test_playerCannotJoinTableAfterGameHasStarted() public createdTable {
        vm.startPrank(alice);

        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        vm.startPrank(bob);
        vm.expectRevert();

        BlackJack(table).joinTable(address(bob));
    }

    function test_IfPlayerNotInGameItWillRevert() public createdTable {
        vm.startPrank(alice);

        BlackJack(table).StartGame();

        vm.stopPrank();

        vm.prank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        vm.startPrank(bob);
        vm.expectRevert();
        BlackJack(table).drawCard();

        vm.expectRevert();
        BlackJack(table).stand();
    }

    function test_kickPlayerShouldKickPlayer() public privateTable {
        uint256 playersBefore = BlackJack(table).getPlayers();
        vm.startPrank(bob);
        vm.expectEmit();
        emit PlayerJoined(bob);
        BlackJack(table).joinPrivateTable(address(bob));

        vm.startPrank(alice);

        BlackJack(table).kickPlayer(bob);
        uint256 playersAfter = BlackJack(table).getPlayers();

        assertLt(playersAfter, playersBefore);
    }

    function test_nonInvitedPlayerCannotJoin() public privateTable {
        vm.startPrank(kim);
        vm.expectRevert();
        BlackJack(table).joinPrivateTable(address(kim));

        vm.stopPrank();
        assertEq(BlackJack(table).getPlayers(), 2);
    }

    function test_NoOneCanKickPlayerInPublicGame() public createdTable {
        vm.startPrank(bob);
        vm.expectEmit();
        emit PlayerJoined(address(bob));
        BlackJack(table).joinTable(address(bob));
        vm.startPrank(alice);
        assertEq(BlackJack(table).getPlayers(), 2);

        vm.expectRevert();
        BlackJack(table).kickPlayer(bob);

        assertEq(BlackJack(table).getPlayers(), 2);
    }

    function test_playerBustsAbove21() public createdTable {
        vm.startPrank(alice);

        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        vm.startPrank(alice);
        BlackJack(table).drawCard();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(2, address(table));

        vm.startPrank(alice);

        BlackJack(table).drawCard();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(3, address(table));

        console.log(BlackJack(table).getCards(alice));

        vm.startPrank(alice);

        vm.expectRevert();

        BlackJack(table).drawCard();

        assertGt(BlackJack(table).getCards(alice), 21);
    }

    function test_bustedPlayerCannotStand() public createdTable {
        vm.startPrank(alice);

        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        vm.startPrank(alice);

        BlackJack(table).drawCard();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(2, address(table));

        vm.startPrank(alice);

        BlackJack(table).drawCard();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(3, address(table));

        vm.startPrank(alice);
        vm.expectRevert();

        BlackJack(table).drawCard();

        vm.expectRevert();
        BlackJack(table).stand();
    }

    function test_playerCanStandAndFinishGame() public createdTable {
        vm.startPrank(alice);
        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        vm.startPrank(alice);

        vm.warp(2 minutes);
        BlackJack(table).stand();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(2, address(table));

        assertEq(info.getHouseCards(table), 0);
    }

    function test_GameWontFinishIfNotOneMinuteHasPassed() public createdTable {
        vm.startPrank(alice);

        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        assertEq(info.getTableOwner(table), address(0x0));

        vm.startPrank(alice);
        // Game has to pass 1 minute so we will warp 2 minute.

        vm.warp(30 seconds);
        BlackJack(table).stand();

        vm.startPrank(address(vrf));
        vm.expectRevert();

        vrf.fulfillRandomWords(2, address(table));

        assertGt(BlackJack(table).getCards(alice), 0);
        assertGt(info.getHouseCards(table), 0);
    }

    function test_PlayerCantHitAfterCallingStand() public createdTable {
        vm.startPrank(alice);
        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        vm.startPrank(alice);
        BlackJack(table).stand();
        vm.expectRevert();
        BlackJack(table).drawCard();
    }

    // multiple Players testing.

    function test_multiplePlayersWorkInTableandCanJoin() public createdTable {
        // playerOne alice
        assertEq(BlackJack(table).getPlayer(0), address(alice));
        assertEq(BlackJack(table).getPlayers(), 1);

        // playerTwo Bob
        vm.startPrank(bob);
        BlackJack(table).joinTable(address(bob));
        assertEq(BlackJack(table).getPlayer(1), address(bob));
        assertEq(BlackJack(table).getPlayers(), 2);

        // playerThree Cas
        vm.startPrank(cas);
        BlackJack(table).joinTable(address(cas));
        assertEq(BlackJack(table).getPlayer(2), address(cas));
        assertEq(BlackJack(table).getPlayers(), 3);

        // playerFour mei
        vm.startPrank(mei);
        BlackJack(table).joinTable(address(mei));
        assertEq(BlackJack(table).getPlayer(3), address(mei));
        assertEq(BlackJack(table).getPlayers(), 4);

        // playerFive Son
        vm.startPrank(son);
        BlackJack(table).joinTable(address(son));
        assertEq(BlackJack(table).getPlayer(4), address(son));
        assertEq(BlackJack(table).getPlayers(), 5);

        // playerSix kim
        vm.startPrank(kim);
        BlackJack(table).joinTable(address(kim));
        assertEq(BlackJack(table).getPlayer(5), address(kim));
        assertEq(BlackJack(table).getPlayers(), 6);

        // playerSeven Job
        vm.startPrank(job);
        BlackJack(table).joinTable(address(job));
        assertEq(BlackJack(table).getPlayer(6), address(job));
        assertEq(BlackJack(table).getPlayers(), 7);

        // See if the players will get right Cards.

        BlackJack(table).StartGame();

        // also fullfil first.
        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(1, address(table));

        // All players should have cards now.

        assertGt(BlackJack(table).getCards(alice), 0);
        assertGt(BlackJack(table).getCards(bob), 0);
        assertGt(BlackJack(table).getCards(cas), 0);
        assertGt(BlackJack(table).getCards(mei), 0);
        assertGt(BlackJack(table).getCards(son), 0);
        assertGt(BlackJack(table).getCards(kim), 0);
        assertGt(BlackJack(table).getCards(job), 0);
    }

    function test_multiplePlayersCanHitAndGetMoreCards() public multiplePlayerTable {
        vm.startPrank(alice);
        BlackJack(table).StartGame();

        uint8 cardsRemainingBefore = info.getCardsRemaining(table);

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        uint8 cardsRemainingAfter = info.getCardsRemaining(table);

        assertEq(cardsRemainingBefore - 15, cardsRemainingAfter);

        vm.startPrank(alice);
        uint8 cardsBefore = BlackJack(table).getCards(alice);
        uint8 cardsRemainingBeforeAlice = info.getCardsRemaining(table);
        BlackJack(table).drawCard();
        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(2, address(table));
        uint8 cardsRemainingAfterAlice = info.getCardsRemaining(table);

        uint8 cardsAfter = BlackJack(table).getCards(alice);

        assertGt(cardsAfter, cardsBefore);
        assertEq((cardsRemainingBeforeAlice - 1), cardsRemainingAfterAlice);

        // bob

        vm.startPrank(bob);
        uint8 cardsBefore2 = BlackJack(table).getCards(bob);
        uint8 cardsRemainingBeforeBob = info.getCardsRemaining(table);
        BlackJack(table).drawCard();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(3, address(table));

        uint8 cardsAfter2 = BlackJack(table).getCards(bob);

        uint8 cardsRemainingAfterBob = info.getCardsRemaining(table);

        assertEq((cardsRemainingBeforeBob - 1), cardsRemainingAfterBob);

        assertGt(cardsAfter2, cardsBefore2);

        // cas

        vm.startPrank(cas);
        uint8 cardsBefore3 = BlackJack(table).getCards(cas);
        uint8 cardsRemainingBeforeCas = info.getCardsRemaining(table);
        BlackJack(table).drawCard();
        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(4, address(table));
        uint8 cardsAfter3 = BlackJack(table).getCards(cas);

        uint8 cardsRemainingAfterCas = info.getCardsRemaining(table);

        assertEq((cardsRemainingBeforeCas - 1), cardsRemainingAfterCas);

        assertGt(cardsAfter3, cardsBefore3);

        // mei

        vm.startPrank(mei);
        uint8 cardsBefore4 = BlackJack(table).getCards(mei);
        uint8 cardsRemainingBeforeMei = info.getCardsRemaining(table);
        BlackJack(table).drawCard();
        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(5, address(table));
        uint8 cardsAfter4 = BlackJack(table).getCards(mei);

        uint8 cardsRemainingAfterMei = info.getCardsRemaining(table);

        assertEq((cardsRemainingBeforeMei - 1), cardsRemainingAfterMei);

        assertGt(cardsAfter4, cardsBefore4);

        // son

        vm.startPrank(son);
        uint8 cardsBefore5 = BlackJack(table).getCards(son);
        uint8 cardsRemainingBeforeSon = info.getCardsRemaining(table);
        BlackJack(table).drawCard();
        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(6, address(table));
        uint8 cardsAfter5 = BlackJack(table).getCards(son);

        uint8 cardsRemainingAfterSon = info.getCardsRemaining(table);

        assertEq((cardsRemainingBeforeSon - 1), cardsRemainingAfterSon);

        assertGt(cardsAfter5, cardsBefore5);

        // kim

        vm.startPrank(kim);
        uint8 cardsBefore6 = BlackJack(table).getCards(kim);
        uint8 cardsRemainingBeforeKim = info.getCardsRemaining(table);
        BlackJack(table).drawCard();
        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(7, address(table));
        uint8 cardsAfter6 = BlackJack(table).getCards(kim);

        uint8 cardsRemainingAfterKim = info.getCardsRemaining(table);

        assertEq((cardsRemainingBeforeKim - 1), cardsRemainingAfterKim);

        assertGt(cardsAfter6, cardsBefore6);

        // job

        vm.startPrank(job);
        uint8 cardsBefore7 = BlackJack(table).getCards(job);
        uint8 cardsRemainingBeforeJob = info.getCardsRemaining(table);
        BlackJack(table).drawCard();
        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(8, address(table));
        uint8 cardsAfter7 = BlackJack(table).getCards(job);

        uint8 cardsRemainingAfterJob = info.getCardsRemaining(table);

        assertEq((cardsRemainingBeforeJob - 1), cardsRemainingAfterJob);

        assertGt(cardsAfter7, cardsBefore7);
    }

    function test_playerCantLeaveWhenGameHasStarted() public createdTable {
        vm.startPrank(bob);
        BlackJack(table).joinTable(address(bob));
        // making sure the player has joined...
        assertEq(BlackJack(table).getPlayer(1), address(bob));
        assertEq(BlackJack(table).getPlayers(), 2);
        assertEq(BlackJack(table).getPlayer(1), address(bob));

        BlackJack(table).StartGame();
        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(1, address(table));
        vm.startPrank(bob);
        vm.expectRevert();
        BlackJack(table).leaveTable(address(bob));
    }

    function test_nonPlayerCannotInteractWithTheGame() public createdTable {
        vm.startPrank(bob);
        vm.expectRevert();
        BlackJack(table).StartGame();
        vm.expectRevert();
        BlackJack(table).StartGame();

        vm.expectRevert();
        BlackJack(table).stand();

        vm.expectRevert();

        BlackJack(table).drawCard();
    }

    function test_FinishGameWorksCorrectly() public multiplePlayerTable {
        address[] memory testie = new address[](7);

        testie[0] = address(cas);
        testie[1] = address(bob);
        testie[2] = address(kim);
        testie[3] = address(son);
        testie[4] = address(job);
        testie[5] = address(mei);
        testie[6] = address(alice);

        vm.startPrank(alice);
        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        for (uint256 i = 0; i < testie.length; i++) {
            vm.startPrank(address(testie[i]));
            BlackJack(table).drawCard();
            BlackJack.PlayerStates memory playerstate = BlackJack(table).getPlayerState(address(testie[i]));
            assertEq(playerstate.playerHit, true);
        }

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(2, address(table));

        vm.warp(3 minutes);
        vm.startPrank(bob);

        BlackJack(table).stand();
        vrf.fulfillRandomWords(3, address(table));

        for (uint256 i = 0; i < testie.length; i++) {
            BlackJack.PlayerStates memory playerstate = BlackJack(table).getPlayerState(address(testie[i]));
            assertEq(playerstate.playerHit, false);
            assertEq(playerstate.playerStand, false);
            assertEq(playerstate.playerBust, false);
            assertEq(BlackJack(table).getCards(address(testie[i])), 0);
            assertEq(info.getHouseCards(table), 0);
        }

        assertEq(info.getGameState(table), false);
    }

    function test_StartBlockTimeStampIsEqualToStartTime() public createdTable {
        vm.startPrank(alice);
        uint256 beforeStartGame = BlackJack(table).startTimeStamp();

        vm.warp(5 minutes);
        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        uint256 afterStartGame = BlackJack(table).startTimeStamp();

        assertGt(afterStartGame, beforeStartGame);
    }

    function test_PlayerCannotJoinFullPublicTable() public multiplePlayerTable {
        address test = makeAddr("test");

        vm.startPrank(test);
        vm.expectRevert();
        BlackJack(table).joinTable(test);
    }

    function test_onlyEdenhallCanSetSubId() public createdTable {
        vm.startPrank(address(EH));

        BlackJack(table).setSubscriptionId(555);
        uint256 subId = BlackJack(table).SubscriptionId();
        assertEq(subId, 555);

        vm.startPrank(alice);
        vm.expectRevert();

        BlackJack(table).setSubscriptionId(1111);
    }

    function test_transferTableOwnerWorks() public privateTable {
        vm.startPrank(alice);

        assertEq(info.getTableOwner(table), address(alice));

        BlackJack(table).transferTableOwner(bob);

        assertEq(info.getTableOwner(table), address(bob));

        vm.expectRevert();
        BlackJack(table).transferTableOwner(alice);
    }

    function test_GameStateReturnsTheRightStates() public createdTable {
        vm.startPrank(alice);
        assertEq(info.getGameState(table), false);

        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(1, address(table));

        assertEq(info.getGameState(table), true);
    }

    function test_getArrayWorks() public multiplePlayerTable {
        vm.startPrank(alice);
        address[] memory lengthArray1 = BlackJack(table).getArray();
        assertEq(7, lengthArray1.length);

        BlackJack(table).leaveTable(address(alice));
        address[] memory lengthArray2 = BlackJack(table).getArray();

        assertEq(6, lengthArray2.length);
    }

    function test_PlayerCanLeaveTableWithNoProblem() public multiplePlayerTable {
        address[] memory testie = new address[](7);
        testie[0] = address(alice);
        testie[1] = address(bob);
        testie[2] = address(kim);
        testie[3] = address(son);
        testie[4] = address(job);
        testie[5] = address(mei);
        testie[6] = address(cas);

        for (uint256 i = 0; i < testie.length; i++) {
            vm.startPrank(address(testie[i]));
            uint256 playerBefore = BlackJack(table).getPlayers();
            BlackJack(table).leaveTable(address(testie[i]));
            uint256 playerAfter = BlackJack(table).getPlayers();
            console.log(i);
            assertEq(playerBefore - playerAfter, 1);
        }
    }

    function test_PlayCanJoinTableandPlayerCountIncreases() public createdTable {
        address[] memory testie = new address[](6);
        testie[0] = address(cas);
        testie[1] = address(bob);
        testie[2] = address(kim);
        testie[3] = address(son);
        testie[4] = address(job);
        testie[5] = address(mei);

        for (uint256 i = 0; i < testie.length; i++) {
            vm.startPrank(address(testie[i]));
            uint256 playerBefore = BlackJack(table).getPlayers();
            BlackJack(table).joinTable(address(testie[i]));
            uint256 playerAfter = BlackJack(table).getPlayers();
            console.log(i);
            assertEq(playerAfter - playerBefore, 1);
        }
    }

    function test_PlayerAllStartWithFalsseBustAndStand_AndGetPlayerBUstAndStandWorks() public multiplePlayerTable {
        address[] memory testie = new address[](7);

        testie[0] = address(cas);
        testie[1] = address(bob);
        testie[2] = address(kim);
        testie[3] = address(son);
        testie[4] = address(job);
        testie[5] = address(mei);
        testie[6] = address(alice);

        for (uint256 i = 0; i < testie.length; i++) {
            BlackJack.PlayerStates memory playerState = BlackJack(table).getPlayerState(address(testie[i]));

            bool playerStand = playerState.playerStand;
            bool playerBust = playerState.playerBust;

            assertEq(playerStand, false);
            assertEq(playerBust, false);
        }

        for (uint256 i = 0; i < testie.length; i++) {
            BlackJack.PlayerStates memory playerState = BlackJack(table).getPlayerState(address(testie[i]));
            vm.startPrank(testie[i]);
            BlackJack(table).stand();

            bool playerStand = playerState.playerStand;
            bool playerBust = playerState.playerBust;

            assertEq(playerStand, true);
            assertEq(playerBust, false);

            vm.expectRevert();
            BlackJack(table).drawCard();
        }
    }

    function test_drawCardWorksWhenVRFRespondsLaterOn() public multiplePlayerTable {
        address[] memory testie = new address[](7);

        testie[0] = address(cas);
        testie[1] = address(bob);
        testie[2] = address(kim);
        testie[3] = address(son);
        testie[4] = address(job);
        testie[5] = address(mei);
        testie[6] = address(alice);

        vm.startPrank(alice);
        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        for (uint256 i = 0; i < testie.length; i++) {
            BlackJack.PlayerStates memory playerState = BlackJack(table).getPlayerState(address(testie[i]));
            vm.startPrank(address(testie[i]));
            BlackJack(table).drawCard();
            bool playerHit = playerState.playerHit;
            assertEq(playerHit, true);
        }

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(2, address(table));
    }

    function test_EveryPlayerCanHitAndWillHaveMoreCardsThanBefore() public multiplePlayerTable {
        address[] memory testie = new address[](7);

        testie[0] = address(cas);
        testie[1] = address(bob);
        testie[2] = address(kim);
        testie[3] = address(son);
        testie[4] = address(job);
        testie[5] = address(mei);
        testie[6] = address(alice);

        vm.startPrank(alice);
        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        for (uint256 i = 0; i < testie.length; i++) {
            BlackJack.PlayerStates memory playerState = BlackJack(table).getPlayerState(address(testie[i]));
            uint8 playerCardsBeforeHit = BlackJack(table).getCards(address(testie[i]));
            vm.startPrank(address(testie[i]));

            BlackJack(table).drawCard();
            bool playerHit = playerState.playerHit;
            assertEq(playerHit, true);
            vrf.fulfillRandomWords(i + 2, address(table));

            uint8 cardsAfter = BlackJack(table).getCards(address(testie[i]));
            assertGt(cardsAfter, playerCardsBeforeHit);
        }
    }

    function test_sameCardCannotBeDrawnAgain() public multiplePlayerTable {
        address[] memory testie = new address[](7);

        testie[0] = address(cas);
        testie[1] = address(bob);
        testie[2] = address(kim);
        testie[3] = address(son);
        testie[4] = address(job);
        testie[5] = address(mei);
        testie[6] = address(alice);

        vm.startPrank(alice);
        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));
    }

    function test_startGameWithPlayersRemoves3Cards() public createdTable {
        vm.startPrank(alice);
        BlackJack(table).StartGame();

        uint8 cardsBefore = info.getCardsRemaining(table);

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(1, address(table));

        uint8 cardsAfters = info.getCardsRemaining(table);

        uint8 length = uint8(BlackJack(table).getPlayers());
        assertEq(cardsBefore - ((length * 2) + 1), cardsAfters);
    }

    function test_getCard() public createdTable {
        vm.expectRevert();
        (uint8 test, uint8 test2) = BlackJack(table).getCard(1);

        vm.startPrank(alice);
        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(1, address(table));

        (uint8 test3, uint8 test4) = BlackJack(table).getCard(1);

        assert(test3 != 0);
        assert(test4 < 4);
    }

    function test_nonPlayerCannotLeaveTable() public createdTable {
        vm.startPrank(bob);
        vm.expectRevert();
        BlackJack(table).leaveTable(address(alice));
    }

    function test_kickplayerWorks() public multiplePlayerPrivateTable {
        // vm.startPrank(alice);

        // // Kicking player2
        // // address Player2 = BlackJack(table).playerTwo();

        // asse

        // BlackJack(table).kickPlayer(Player2);

        // // assertEq(BlackJack(table).playerTwo(), address(0x0));

        // // Kicking player3
        // // address Player3 = BlackJack(table).playerThree();

        // BlackJack(table).kickPlayer(Player3);

        // // assertEq(BlackJack(table).playerThree(), address(0x0));

        // // Kicking player4
        // // address Player4 = BlackJack(table).playerFour();

        // BlackJack(table).kickPlayer(Player4);

        // // assertEq(BlackJack(table).playerFour(), address(0x0));

        // // Kicking player5
        // // address Player5 = BlackJack(table).playerFive();

        // BlackJack(table).kickPlayer(Player5);

        // // assertEq(BlackJack(table).playerFive(), address(0x0));

        // // Kicking player6

        // // address Player6 = BlackJack(table).playerSix();

        // BlackJack(table).kickPlayer(Player6);

        // // assertEq(BlackJack(table).playerSix(), address(0x0));

        // // Kicking player7

        // // address Player7 = BlackJack(table).playerSeven();

        // BlackJack(table).kickPlayer(Player7);

        // // assertEq(BlackJack(table).playerSeven(), address(0x0));

        // // kicking non player()
        // vm.expectRevert();
        // BlackJack(table).kickPlayer(address(vrf));
    }

    function test_requestIdsGetReturnedRight() public createdTable {
        vm.startPrank(alice);

        uint256 requestId = BlackJack(table).StartGame();

        vrf.fulfillRandomWords(1, address(table));

        assertEq(requestId, 1);

        uint256 requestId2 = BlackJack(table).drawCard();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(2, address(table));

        assertEq(requestId2, 2);
    }

    function test_playerOneLeavesAndComesBack() public createdTable {
        vm.startPrank(alice);
        assertEq(BlackJack(table).getPlayer(0), address(alice));
        BlackJack(table).leaveTable(address(alice));
        vm.expectRevert();
        BlackJack(table).getPlayer(0);

        BlackJack(table).joinTable(address(alice));

        assertEq(BlackJack(table).getPlayers(), 1);
    }

    // Testing Queens/Aces/Kings...

    function test_ace_WorksWithDealerAndPlayer() public createdTable {
        vm.startPrank(alice);
        BlackJack(table).StartGame();
        vm.startPrank(address(vrf));

        uint256[] memory words = new uint256[](24);
        words[0] = 12;
        words[1] = 12;
        words[2] = 12;
        // dealer:
        words[3] = 12;
        words[4] = 12;
        words[5] = 12;
        words[6] = 12;
        // dealer:
        words[7] = 12;
        words[8] = 12;
        words[9] = 12;
        words[10] = 12;
        // dealer:
        words[11] = 12;
        words[12] = 12;
        words[13] = 12;
        words[14] = 12;
        // dealer:
        words[15] = 12;
        words[16] = 12;
        words[17] = 13;
        words[18] = 13;
        words[19] = 12;
        words[20] = 12;
        words[21] = 12;
        words[22] = 12;
        words[23] = 12;

        vrf.fulfillRandomWordsWithOverride(1, address(table), words);
        (uint8 card, uint8 suit) = BlackJack(table).getCard(13);

        uint8 cardsAlice = BlackJack(table).getCards(address(alice));

        assertEq(cardsAlice, 12);

        vm.startPrank(alice);

        BlackJack(table).drawCard();
        vm.startPrank(address(vrf));

        vrf.fulfillRandomWordsWithOverride(2, address(table), words);

        uint8 cardsAlice2 = BlackJack(table).getCards(address(alice));

        assertEq(cardsAlice2, 13);

        vm.warp(5 minutes);

        vm.startPrank(alice);

        BlackJack(table).stand();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWordsWithOverride(3, address(table), words);
    }

    function test_KingAndQueensWillTurnInto10() public createdTable {
        vm.startPrank(alice);
        BlackJack(table).StartGame();
        vm.startPrank(address(vrf));
        uint256[] memory words = new uint256[](24);
        // Queen turns into
        words[0] = 11;
        words[1] = 11;
        words[2] = 11;
        // dealer:
        words[3] = 11;
        words[4] = 11;
        words[5] = 11;
        words[6] = 11;
        // dealer:
        words[7] = 11;
        words[8] = 11;
        words[9] = 11;
        words[10] = 11;
        // dealer:
        words[11] = 11;
        words[12] = 11;
        words[13] = 11;
        words[14] = 11;
        // dealer:
        words[15] = 11;
        words[16] = 11;
        words[17] = 11;
        words[18] = 11;
        words[19] = 11;
        words[20] = 11;
        words[21] = 11;
        words[22] = 11;
        words[23] = 11;

        vrf.fulfillRandomWordsWithOverride(1, address(table), words);

        uint8 cardsAlice = BlackJack(table).getCards(address(alice));
        uint8 housecardie = info.getHouseCards(table);

        assertEq(cardsAlice, 20);
        assertEq(housecardie, 10);
    }

    function test_kingswillworkcorrectly() public createdTable {
        vm.startPrank(alice);
        BlackJack(table).StartGame();
        vm.startPrank(address(vrf));

        uint256[] memory words = new uint256[](24);
        // Queen turns into
        words[0] = 10;
        words[1] = 10;
        words[2] = 10;
        // dealer:
        words[3] = 10;
        words[4] = 10;
        words[5] = 10;
        words[6] = 10;
        // dealer:
        words[7] = 10;
        words[8] = 10;
        words[9] = 10;
        words[10] = 10;
        // dealer:
        words[11] = 10;
        words[12] = 10;
        words[13] = 10;
        words[14] = 10;
        // dealer:
        words[15] = 10;
        words[16] = 10;
        words[17] = 10;
        words[18] = 10;
        words[19] = 10;
        words[20] = 10;
        words[21] = 10;
        words[22] = 10;
        words[23] = 10;

        vrf.fulfillRandomWordsWithOverride(1, address(table), words);
        uint8 cardsAlice = BlackJack(table).getCards(address(alice));
        uint8 housecardie = info.getHouseCards(table);
        (uint8 cardie, uint8 suitie) = BlackJack(table).getCard(12);

        console.log("Cardie:", cardie);

        assertEq(cardsAlice, 20);
        assertEq(housecardie, 10);
    }

    function test_AceWillBecome11At10OrUnder() public createdTable {
        vm.startPrank(alice);
        BlackJack(table).StartGame();
        vm.startPrank(address(vrf));
        uint256[] memory words = new uint256[](24);
        // Queen turns into
        words[0] = 3;
        words[1] = 1;
        words[2] = 1;
        // dealer:
        words[3] = 1;
        words[4] = 1;
        words[5] = 1;
        words[6] = 1;
        // dealer:
        words[7] = 1;
        words[8] = 1;
        words[9] = 1;
        words[10] = 1;
        // dealer:
        words[11] = 1;
        words[12] = 1;
        words[13] = 1;
        words[14] = 1;
        // dealer:
        words[15] = 1;
        words[16] = 1;
        words[17] = 1;
        words[18] = 1;
        words[19] = 1;
        words[20] = 1;
        words[21] = 1;
        words[22] = 1;
        words[23] = 1;

        vrf.fulfillRandomWordsWithOverride(1, address(table), words);

        vm.startPrank(alice);

        BlackJack(table).drawCard();
        uint256[] memory words2 = new uint256[](24);
        words2[0] = 12;
        words2[1] = 12;
        words2[2] = 12;
        // dealer:
        words2[3] = 12;
        words2[4] = 12;
        words2[5] = 12;
        words2[6] = 12;
        // dealer:
        words2[7] = 12;
        words2[8] = 12;
        words2[9] = 12;
        words2[10] = 12;
        // dealer:
        words2[11] = 12;
        words2[12] = 12;
        words2[13] = 12;
        words2[14] = 12;
        // dealer:
        words2[15] = 12;
        words2[16] = 12;
        words2[17] = 12;
        words2[18] = 12;
        words2[19] = 12;
        words2[20] = 12;
        words2[21] = 12;
        words2[22] = 12;
        words2[23] = 12;

        vrf.fulfillRandomWordsWithOverride(2, address(table), words2);

        uint8 cardsAlice = BlackJack(table).getCards(address(alice));
        uint8 housecardie = info.getHouseCards(table);

        assertEq(cardsAlice, 17);

        vm.startPrank(alice);
        vm.warp(5 minutes);

        BlackJack(table).stand();

        vrf.fulfillRandomWordsWithOverride(3, address(table), words2);
    }

    function test_playerEmitsBustWhenBusted() public multiplePlayerTable {
        uint256[] memory words = new uint256[](24);

        // Queen turns into
        words[0] = 11;
        words[1] = 11;
        words[2] = 11;
        // dealer:
        words[3] = 11;
        words[4] = 11;
        words[5] = 11;
        words[6] = 11;
        // dealer:
        words[7] = 11;
        words[8] = 11;
        words[9] = 11;
        words[10] = 11;
        // dealer:
        words[11] = 11;
        words[12] = 11;
        words[13] = 11;
        words[14] = 11;
        // dealer:
        words[15] = 11;
        words[16] = 11;
        words[17] = 11;
        words[18] = 11;
        words[19] = 11;
        words[20] = 11;
        words[21] = 11;
        words[22] = 11;
        words[23] = 11;

        address[] memory testie = new address[](7);

        testie[0] = address(cas);
        testie[1] = address(bob);
        testie[2] = address(kim);
        testie[3] = address(son);
        testie[4] = address(job);
        testie[5] = address(mei);
        testie[6] = address(alice);

        vm.startPrank(alice);
        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWordsWithOverride(1, address(table), words);

        for (uint8 i = 0; i < testie.length; i++) {
            BlackJack.PlayerStates memory playerState = BlackJack(table).getPlayerState(address(testie[i]));
            uint8 playerCardsBeforeHit = BlackJack(table).getCards(address(testie[i]));
            vm.startPrank(address(testie[i]));

            BlackJack(table).drawCard();
            bool playerHit = playerState.playerHit;
            assertEq(playerHit, true);

            address player = testie[i];

            if (player == BlackJack(table).getPlayer(i)) {
                vm.expectEmit();
                emit PlayerDrawn(player, 12, 0);
                emit PlayerBust(address(BlackJack(table).getPlayer(i)), 30);
            } else if (player == BlackJack(table).getPlayer(i)) {
                vm.expectEmit();
                emit PlayerDrawn(player, 12, 0);
                emit PlayerBust(address(BlackJack(table).getPlayer(i)), 30);
            } else if (player == BlackJack(table).getPlayer(i)) {
                vm.expectEmit();
                emit PlayerDrawn(player, 12, 0);
                emit PlayerBust(address(BlackJack(table).getPlayer(i)), 30);
            } else if (player == BlackJack(table).getPlayer(i)) {
                vm.expectEmit();
                emit PlayerDrawn(player, 12, 0);
                emit PlayerBust(address(BlackJack(table).getPlayer(i)), 30);
            } else if (player == BlackJack(table).getPlayer(i)) {
                vm.expectEmit();
                emit PlayerDrawn(player, 12, 0);
                emit PlayerBust(address(BlackJack(table).getPlayer(i)), 30);
            } else if (player == BlackJack(table).getPlayer(i)) {
                vm.expectEmit();
                emit PlayerDrawn(player, 12, 0);
                emit PlayerBust(address(BlackJack(table).getPlayer(i)), 30);
            } else {
                vm.expectEmit();
                emit PlayerDrawn(player, 12, 0);
                emit PlayerBust(address(BlackJack(table).getPlayer(i)), 30);
            }

            vrf.fulfillRandomWordsWithOverride(i + 2, address(table), words);

            uint8 cardsAfter = BlackJack(table).getCards(address(testie[i]));
            assertEq(cardsAfter, 30);
        }
    }

    function test_AddHouseCardsAndAddPlayerCardsCanOnlyBeCalledByBJUtils() public createdTable {
        vm.startPrank(alice);
        BlackJack(table).StartGame();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(1, address(table));
        vm.expectRevert();
        BlackJack(table).addHouseCards(10);
        vm.expectRevert();
        BlackJack(table).addPlayerCard(10, address(alice));
        uint8 houseCardsB = BlackJack(table).houseCards();
        vm.startPrank(address(BJU));
        BlackJack(table).addHouseCards(10);
        uint8 houseCards = BlackJack(table).houseCards();
        assertGt(houseCards, houseCardsB);
    }
}
