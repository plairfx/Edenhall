// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

library Events {
    event PlayerDrawn(address player, uint8 card, uint8 suit);
    event PlayerBust(address player, uint8 card);
    event PlayerWon(address player, uint8 card);
    event PlayerKicked(address player);
    event PlayerLeft(address player);
    event PlayerJoined(address player);
    event BlackjackPlayer(address winner, uint8 card);

    event BlackjackHouse(uint256 amount);
    event DealerBusted(uint8 value);
    event CardDrawnDealer(uint8 value, uint8 suit);
    event DealerWon(uint8 card);
}
