// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

interface IBlackjackUtils {
    function _playerDrawnCheck(uint8, uint8) external view returns (uint8);
    function _AceAndQueenCheck(uint8, uint8) external view returns (uint8, uint8);

    function checkInvitedPlayer(address[] memory joinedPlayers, address Player) external view returns (bool);
    function checkTables(address[] memory tables, address player) external returns (bool);
    function emitPlayerEvents(address[] memory joinedPlayers, uint256[] memory randomWords) external;
    function _playerEmit(
        uint8 card,
        uint8 suit,
        uint8 card2,
        uint8 suit2,
        address player,
        bool play,
        address[] memory joinedPlayers
    ) external;

    function _playGame(uint256[] memory randomWords, address[] memory joinedPlayers) external;
}
