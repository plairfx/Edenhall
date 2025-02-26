// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {IBlackjack} from "../interface/IBlackJack.sol";

library info {
    function getGameState(address table) public view returns (bool) {
        return IBlackjack(table).gameStarted();
    }

    function getCardsRemaining(address table) public view returns (uint8) {
        return IBlackjack(table).cardsRemaining();
    }

    function getPrivateBool(address table) public view returns (bool) {
        return IBlackjack(table).privateGame();
    }

    function getHouseCards(address table) public view returns (uint8) {
        return IBlackjack(table).houseCards();
    }

    function getTableOwner(address table) public view returns (address) {
        return IBlackjack(table).tableOwner();
    }
}
