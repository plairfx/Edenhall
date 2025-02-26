// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

interface IBlackjack {
    struct PlayerStates {
        bool playerBust;
        uint8 playerCards;
        bool playerStand;
        bool playerHit;
        bool playerJoined;
    }

    struct Cards {
        uint8 value;
        uint8 suit;
    }

    function cardsRemaining() external view returns (uint8);

    function privateGame() external view returns (bool);

    function tableOwner() external view returns (address);

    function houseCards() external view returns (uint8);

    function gameStarted() external view returns (bool);

    function joinedPlayers() external view returns (address[] memory);

    function joinTable(address player) external;

    function getPlayers() external view returns (uint256);

    function getPlayerState(address player) external view returns (PlayerStates calldata);

    function addHouseCards(uint8 value) external;
    function addPlayerCard(uint8 value, address player) external;

    function getDeck() external view returns (Cards[] memory);

    function EdenhallAdd() external view returns (address);
}
