// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Edenhall} from "../src/Edenhall.sol";
import {BlackJack} from "../src/Blackjack.sol";
import {Test, console2, console} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {BlackjackUtils} from "src/BlackjackUtils.sol";

contract EdenhallTest is Test {
    Edenhall public EH;
    VRFCoordinatorV2_5Mock public vrf;
    BlackjackUtils public BJU;

    address alice = makeAddr("user");

    address table;

    uint256 subId;

    address bob = makeAddr("bob");
    address cas = makeAddr("cas");
    address mei = makeAddr("mei");
    address son = makeAddr("son");
    address kim = makeAddr("kim");
    address job = makeAddr("job");

    function setUp() external {
        // Launch Edenhall contract.

        BJU = new BlackjackUtils();

        EH = new Edenhall(address(BJU));

        // setup chainlink
        vrf = new VRFCoordinatorV2_5Mock(100000000000000000, 1000000000, 4701000330007423);
        uint256 subid = vrf.createSubscription();
        subId = subid;
        EH.setVRF(address(vrf));
        vrf.fundSubscription(subId, 100000000000000000000);

        EH.setSubbie(subId);
    }

    modifier tableCreated() {
        vm.prank(alice);
        Edenhall.GameInfo memory Params =
            Edenhall.GameInfo({private_game: false, max_players: 3, invite_code: 0, table_owner: alice});
        address[] memory invitedPlayers = new address[](1);

        invitedPlayers[0] = alice;
        address Table = EH.play(Params, invitedPlayers);
        table = Table;
        console.log(address(table));
        _;
    }

    function test_playWhenNoTables() public {
        vm.startPrank(alice);
        Edenhall.GameInfo memory Params =
            Edenhall.GameInfo({private_game: false, max_players: 3, invite_code: 0, table_owner: alice});
        address[] memory invitedPlayers = new address[](1);
        invitedPlayers[0] = alice;

        address table = EH.play(Params, invitedPlayers);

        assert(address(table) != address(0));
    }

    function test_whenTableIsAvaliableNoTableShouldBeCreated() public tableCreated {
        vm.startPrank(alice);

        address firstTable = EH.getTable(0);

        assertEq(BlackJack(table).getPlayers(), 1);
        assertEq(firstTable, table);

        Edenhall.GameInfo memory Params =
            Edenhall.GameInfo({private_game: false, max_players: 3, invite_code: 0, table_owner: alice});
        address[] memory invitedPlayers = new address[](1);
        invitedPlayers[0] = bob;
        address table1 = EH.play(Params, invitedPlayers);
        assertEq(BlackJack(table).getPlayers(), 2);
        assertEq(EH.getTable(0), address(table));
        vm.expectRevert();
        EH.getTable(1);
    }

    function test_CannotCreateTableWithMoreThan7Players() public {
        address bobby = makeAddr("bobby");
        vm.startPrank(alice);
        Edenhall.GameInfo memory Params =
            Edenhall.GameInfo({private_game: false, max_players: 7, invite_code: 0, table_owner: alice});
        address[] memory invitedPlayers = new address[](8);
        invitedPlayers[0] = alice;
        invitedPlayers[1] = bob;
        invitedPlayers[2] = cas;
        invitedPlayers[3] = mei;
        invitedPlayers[4] = son;
        invitedPlayers[5] = kim;
        invitedPlayers[6] = job;
        invitedPlayers[7] = bobby;
        vm.expectRevert();

        EH.play(Params, invitedPlayers);
    }

    function test_privateTableGetsAddedCorrectlyAndCanBeJoined() public {
        vm.startPrank(alice);
        Edenhall.GameInfo memory Params =
            Edenhall.GameInfo({private_game: false, max_players: 3, invite_code: 0, table_owner: alice});
        address[] memory invitedPlayers = new address[](1);

        invitedPlayers[0] = alice;

        address table = EH.play(Params, invitedPlayers);

        assertEq(BlackJack(table).getPlayers(), 1);
        // assertEq(BlackJack(table).playerOne(), address(alice));
        assertEq(EH.getTable(0), address(table));
        assert(address(table) != address(0x0));
    }

    function test_tooManyTablesItWillRevert() public {
        for (uint256 i = 50; i > EH.getTables(); i--) {
            vm.startPrank(alice);
            Edenhall.GameInfo memory Params =
                Edenhall.GameInfo({private_game: false, max_players: 7, invite_code: 0, table_owner: alice});
            address[] memory invitedPlayers = new address[](7);
            invitedPlayers[0] = alice;
            invitedPlayers[1] = bob;
            invitedPlayers[2] = cas;
            invitedPlayers[3] = mei;
            invitedPlayers[4] = son;
            invitedPlayers[5] = kim;
            invitedPlayers[6] = job;

            address table = EH.play(Params, invitedPlayers);

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
            uint256 tafels = EH.getTables();
            console.log(i, EH.getTables());
        }

        vm.startPrank(alice);
        Edenhall.GameInfo memory Params =
            Edenhall.GameInfo({private_game: false, max_players: 7, invite_code: 0, table_owner: alice});
        address[] memory invitedPlayers = new address[](7);
        invitedPlayers[0] = alice;
        invitedPlayers[1] = bob;
        invitedPlayers[2] = cas;
        invitedPlayers[3] = mei;
        invitedPlayers[4] = son;
        invitedPlayers[5] = kim;
        invitedPlayers[6] = job;
        // console.log(EH.getTables());

        vm.expectRevert();
        address table = EH.play(Params, invitedPlayers);
        assertEq(EH.getTables(), 25);
    }

    function test_tooManyPrivateTablesWillRevert() public {
        for (uint256 i = 50; i > EH.getTables(); i--) {
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

            address table = EH.play(Params, invitedPlayers);

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
            uint256 tafels = EH.getTables();
        }

        vm.startPrank(alice);
        Edenhall.GameInfo memory Params =
            Edenhall.GameInfo({private_game: false, max_players: 7, invite_code: 0, table_owner: alice});
        address[] memory invitedPlayers = new address[](7);
        invitedPlayers[0] = alice;
        invitedPlayers[1] = bob;
        invitedPlayers[2] = cas;
        invitedPlayers[3] = mei;
        invitedPlayers[4] = son;
        invitedPlayers[5] = kim;
        invitedPlayers[6] = job;

        vm.expectRevert();
        address table = EH.play(Params, invitedPlayers);

        assertEq(EH.getTables(), 25);
    }

    function test_setSubIDWorks() public {
        EH.setSubbie(1);

        assertEq(EH.subbie(), 1);
    }

    function test_setVRFWorks() public {
        EH.setVRF(address(alice));

        assertEq(EH.vrf(), address(alice));
    }

    function test_nonOwnerCannotSetVRFAndSubId() public {
        uint256 subID = EH.subbie();
        address vrfie = EH.vrf();
        vm.startPrank(bob);
        vm.expectRevert();
        EH.setVRF(address(alice));

        vm.expectRevert();
        EH.setSubbie(1);

        assertEq(EH.vrf(), vrfie);
        assertEq(EH.subbie(), subID);
    }

    function test_TableReturnsRightPrivateOrNotBool() public {
        vm.startPrank(alice);
        Edenhall.GameInfo memory Params =
            Edenhall.GameInfo({private_game: false, max_players: 3, invite_code: 0, table_owner: alice});
        address[] memory invitedPlayers = new address[](1);

        invitedPlayers[0] = alice;

        address table = EH.play(Params, invitedPlayers);

        assertEq(EH.getPrivateBool((table)), false);

        vm.startPrank(bob);
        Edenhall.GameInfo memory Params2 =
            Edenhall.GameInfo({private_game: true, max_players: 3, invite_code: 0, table_owner: alice});
        address[] memory invitedPlayers2 = new address[](1);

        invitedPlayers2[0] = bob;

        address table2 = EH.play(Params2, invitedPlayers2);

        assertEq(EH.getPrivateBool(table2), true);
        assert(address(table) != address(0x0));
    }
}
