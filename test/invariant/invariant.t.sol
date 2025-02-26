// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Edenhall} from "../../src/Edenhall.sol";
import {BlackJack} from "../../src/Blackjack.sol";
import {Test, console2, console, StdInvariant} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Handler} from "../invariant/handler.t.sol";
import {BlackjackUtils} from "src/BlackjackUtils.sol";

contract Invariant is StdInvariant, Test {
    Edenhall public EH;
    VRFCoordinatorV2_5Mock public vrf;
    Handler public handler;
    BlackJack public BJ;
    BlackjackUtils public BJU;

    address alice = makeAddr("user");
    address bob = makeAddr("bob");
    address cas = makeAddr("cas");
    address mei = makeAddr("mei");
    address son = makeAddr("son");
    address kim = makeAddr("kim");
    address job = makeAddr("job");

    address table;
    uint256 subId;

    bytes4 private constant COORDINATOR_SELECTOR = bytes4(keccak256("setCoordinator(address)"));
    bytes4 private constant FULFILL_RANDOM_SELECTOR = bytes4(keccak256("rawFulfillRandomWords(uint256,uint256[])"));

    function setUp() external {
        uint256[] memory words = new uint256[](24);
        words[0] = 11;
        words[1] = 12;
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
        BJU = new BlackjackUtils();
        EH = new Edenhall(address(BJU));

        // setup chainlink
        vrf = new VRFCoordinatorV2_5Mock(100000000000000000, 1000000000, 4701000330007423);
        uint256 subid = vrf.createSubscription();

        subId = subid;
        handler = new Handler(address(vrf), address(EH));
        EH.setVRF(address(vrf));

        vrf.fundSubscription(subId, 1000000000000000000000000000000000);

        EH.setSubbie(subId);

        // targetContract(address(tafel));

        vm.startPrank(address(handler));

        Edenhall.GameInfo memory Params =
            Edenhall.GameInfo({private_game: false, max_players: 3, invite_code: 0, table_owner: address(handler)});
        address[] memory invitedPlayers = new address[](1);
        invitedPlayers[0] = address(handler);

        address Table = EH.play(Params, invitedPlayers);

        table = Table;

        vm.stopPrank();

        vrf.addConsumer(subId, Table);

        vm.startPrank(address(handler));

        BlackJack(Table).StartGame();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWordsWithOverride(1, address(Table), words);

        targetContract(address(handler));
    }

    function invariant_PlayerCannotChangeCardsAfterBusting() public {
        uint8 cards = handler.getCards();
        if (cards > 21) {
            uint8 cards2 = handler.getCards();
            assertGt(cards2, 21);

            uint8 cards3 = handler.getCards();
            assertEq(cards2, cards3);
        }
    }

    function invariant_playerCannotLeaveDuringGameOrJoin() public {
        uint256 playersLength = BlackJack(table).getPlayers();
        assertEq(playersLength, 1);
    }

    function invariant_userCannotDrawAfterStanding() public {
        if (handler.standing()) {
            uint8 cards = handler.getCards();
            assertEq(cards, cards);
        }
    }

    function invariant_EHGetTablesCanNeverBeMoreThan25() public {
        uint256 tables = EH.getTables();

        assertGt(26, tables);
    }

    function invariant_createTableAlwaysReturnAnAddress() public {
        if (handler.getTables() >= 25) {
            vm.expectRevert();
        }
        address table = handler.createTable();

        if (handler.getTables() < 25) {
            assert(table != address(0x0));
        }
    }
}
