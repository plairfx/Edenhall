// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test, console} from "forge-std/Test.sol";
import {BlackJack} from "../../src/Blackjack.sol";
import {Invariant} from "./invariant.t.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Edenhall} from "../../src/Edenhall.sol";
import {info} from "src/library/info.sol";

contract Handler is CommonBase, StdCheats, StdUtils {
    VRFCoordinatorV2_5Mock public vrf;
    Edenhall public EH;
    bool public standing;
    bool joined = true;
    address vrf2;
    uint8 i;
    address table = 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac;

    constructor(address vrfie, address eh) {
        vrf2 = vrfie;
        vrf = VRFCoordinatorV2_5Mock(vrfie); // Cast the address to the contract type
        EH = Edenhall(eh);
    }

    function drawCard() public {
        if (getCards() > 21) {
            return;
        } else if (standing) {
            return;
        } else {
            BlackJack(table).drawCard();
            if (i == 0) {
                i++;
            }
            vrf.fulfillRandomWords(i + 1, address(table));
            i++;
        }
    }

    function stand() public {
        if (!standing) {
            BlackJack(table).stand();
            standing = true;
        }
    }

    function getCards() public returns (uint8 cards) {
        return BlackJack(table).getCards(address(this));
    }

    function joinTable() public {
        if (!joined) {
            BlackJack(table).joinTable(address(this));
        } else {
            return;
        }
    }

    function leaveTable() public {
        if (info.getGameState(table)) {
            return;
        } else {
            BlackJack(table).leaveTable(address(this));
        }
    }

    function getTables() public returns (uint256 tables) {
        return EH.getTables();
    }

    function createTable() public returns (address tables) {
        for (uint8 i = 49; i > getTables(); i--) {
            Edenhall.GameInfo memory Params2 =
                Edenhall.GameInfo({private_game: true, max_players: 7, invite_code: 0, table_owner: address(this)});
            address[] memory addressie2 = new address[](1);
            addressie2[0] = address(this);
            return EH.play(Params2, addressie2);
        }
    }
}
