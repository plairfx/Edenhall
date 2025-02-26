// SPDX-License-Identifier: MIT

import {IBlackjack} from "./interface/IBlackJack.sol";
import {Events} from "./library/Events.sol";

pragma solidity 0.8.28;

contract BlackjackUtils {
    address Edenhall;

    function _AceAndQueenCheck(uint8 card, uint8 card2) public returns (uint8, uint8) {
        // Queen/king check & conversion.
        if (card == 11 || card == 12) {
            card = 10;
        }
        // Queen/King check & conversion.
        if (card2 == 11 || card2 == 12) {
            card2 = 10;
        }

        // Ace checks & conversions.

        // First Ace Check
        if (card == 13) {
            card = 11;
        }
        // Second Ace Check
        if (card2 == 13) {
            card2 = 11;
        }

        uint8 houseCards = IBlackjack(msg.sender).houseCards();
        if (card2 == 0) {
            if (card == 11 && (card + houseCards) > 21) {
                card = 1;
            }
        }

        if (card == 11 && (card + card2) > 21) {
            card = 1;
        }

        return (card, card2);
    }

    function _playerDrawnCheck(uint8 playerCardsBefore, uint8 card) external returns (uint8) {
        if (card == 11 || card == 12) {
            card = 10;
        }

        if (card == 13) {
            if (playerCardsBefore <= 10) {
                card = 11;
            } else if (playerCardsBefore >= 11) {
                card = 1;
            }
        }

        return card;
    }

    function checkTables(address[] memory tables, address player) external returns (bool) {
        if (tables.length == 0) {
            return false;
        }
        for (uint8 i; i < tables.length; i++) {
            uint256 playerLength = IBlackjack(tables[i]).getPlayers();

            if (playerLength < 7) {
                IBlackjack(tables[i]).joinTable(player);
                return true;
            }
        }
    }

    function emitPlayerEvents(address[] memory joinedPlayers, uint256[] memory randomWords) public {
        uint8 index1 = 1;
        uint8 houseCardsB = IBlackjack(msg.sender).houseCards();

        IBlackjack.Cards[] memory deck = IBlackjack(msg.sender).getDeck();

        while (houseCardsB < 17) {
            uint8 cardsRemaining = IBlackjack(msg.sender).cardsRemaining();
            uint8 cardIndex = uint8(randomWords[index1] % cardsRemaining - 1);
            (uint8 value, uint8 suit) = (deck[cardIndex].value, deck[cardIndex].suit);
            emit Events.CardDrawnDealer(value, suit);

            (uint8 newValue, uint8 unused) = _AceAndQueenCheck(value, 0);

            value = newValue;

            IBlackjack(msg.sender).addHouseCards(value);
            if (index1 == 1 && houseCardsB == 21) {
                emit Events.BlackjackHouse(houseCardsB);
            }
            index1 += 1;
            houseCardsB = IBlackjack(msg.sender).houseCards();
        }

        ///////////////////////////////////////

        uint8 houseCards = IBlackjack(msg.sender).houseCards();
        for (uint8 i = 0; i < joinedPlayers.length; i++) {
            address player = joinedPlayers[i];

            IBlackjack.PlayerStates memory playerstate = IBlackjack(msg.sender).getPlayerState(player);

            uint8 playerCards = playerstate.playerCards;
            bool playerBusting = playerstate.playerBust;

            if (!playerBusting && playerCards > houseCards || playerBusting && houseCards == 0) {
                emit Events.PlayerWon(player, playerCards);
                if (playerCards == 21) {
                    emit Events.BlackjackPlayer(player, playerCards);
                }
            } else if (houseCards < 21 && houseCards > playerCards) {
                emit Events.DealerWon(houseCards);
            }
        }
    }

    function _playGame(uint256[] memory randomWords, address[] memory joinedPlayers) public {
        IBlackjack.Cards[] memory deck = IBlackjack(msg.sender).getDeck();
        for (uint256 i = 0; i < joinedPlayers.length; i++) {
            uint8 cardsRemaining = IBlackjack(msg.sender).cardsRemaining();
            address player = joinedPlayers[i];

            // first card..
            uint8 cardIndex = uint8((randomWords[i] % cardsRemaining));
            (uint8 card, uint8 suit) = (deck[cardIndex].value, deck[cardIndex].suit);

            uint8 cardIndex2 = uint8(randomWords[7 + i] % cardsRemaining);
            (uint8 card2, uint8 suit3) = (deck[cardIndex2].value, deck[cardIndex2].suit);

            cardsRemaining -= uint8(1 * 2);

            _playerEmit(card, suit, card2, card2, player, true, joinedPlayers);

            (uint8 newCard, uint8 newCard2) = _AceAndQueenCheck(card, card2);

            IBlackjack.PlayerStates memory playerstate = IBlackjack(msg.sender).getPlayerState(player);

            card = newCard;
            card2 = newCard2;

            IBlackjack(msg.sender).addPlayerCard(card, player);
            IBlackjack(msg.sender).addPlayerCard(card2, player);
        }

        uint8 cardsRemaining2 = IBlackjack(msg.sender).cardsRemaining();

        uint8 cardIndex3 = uint8(randomWords[16] % cardsRemaining2);

        (uint8 carddealer, uint8 suitdealer) = (deck[cardIndex3].value, deck[cardIndex3].suit);

        emit Events.CardDrawnDealer(carddealer, suitdealer);

        (uint8 dealerCard, uint8 notUsed) = _AceAndQueenCheck(carddealer, 0);

        carddealer = dealerCard;

        IBlackjack(msg.sender).addHouseCards(carddealer);
    }

    function _playerEmit(
        uint8 card,
        uint8 suit,
        uint8 card2,
        uint8 suit2,
        address player,
        bool play,
        address[] memory joinedPlayers
    ) public {
        address PlayerA;

        for (uint8 i = 0; i < joinedPlayers.length; i++) {
            address joinedplayer = joinedPlayers[i];
            if (joinedplayer == player) {
                PlayerA = player;
                break;
            }
        }
        if (play) {
            emit Events.PlayerDrawn(PlayerA, card, suit);
            emit Events.PlayerDrawn(PlayerA, card2, suit2);
        } else {
            emit Events.PlayerDrawn(PlayerA, card, suit);
        }
    }
}
