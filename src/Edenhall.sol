// SPDX-License-Identifier:MIT

import {BlackJack} from "src/Blackjack.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {info} from "./library/info.sol";
import {IBlackjackUtils} from "src/interface/IBlackJackUtils.sol";

pragma solidity 0.8.28;

contract Edenhall is ReentrancyGuard {
    BlackJack BJ;

    struct GameInfo {
        bool private_game;
        uint64 max_players;
        uint256 invite_code;
        address table_owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(address UTILS) {
        owner = msg.sender;
        utils = UTILS;
    }

    error TooManyTables();

    address[] public tables;
    address owner;
    uint256 public subbie;
    address public vrf;
    address utils;

    // Chainlink Sepolia
    bytes32 public immutable keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 public constant callbackGasLimit = 2400000;
    uint16 public constant requestConfirmations = 3;
    uint32 public constant numWords = 24;
    uint256 public s_subscriptionId;

    function play(GameInfo memory params, address[] memory invitedPlayers)
        public
        nonReentrant
        returns (address newTable)
    {
        require(invitedPlayers.length < 8);
        if (params.private_game) {
            return _createTable(true, invitedPlayers);
        } else if (!params.private_game && !_checkAndJoinTables()) {
            return _createTable(false, invitedPlayers);
        }
    }

    function _createTable(bool privateGame, address[] memory invitedPlayers) internal returns (address table) {
        require(tables.length < 25, TooManyTables());

        if (privateGame) {
            BlackJack privateTable =
                new BlackJack(invitedPlayers, subbie, vrf, keyHash, true, address(this), msg.sender, utils);
            tables.push(address(privateTable));
            return address(privateTable);
        } else {
            address[] memory player = new address[](1);
            player[0] = msg.sender;
            BlackJack publicTable = new BlackJack(player, subbie, vrf, keyHash, false, address(this), address(0), utils);

            tables.push(address(publicTable));

            return address(publicTable);
        }
    }

    /**
     * @dev checks if there are any avaliable tables to join, that have less than the full amount of players (7).
     */
    function _checkAndJoinTables() internal returns (bool joined) {
        return IBlackjackUtils(utils).checkTables(tables, msg.sender);
    }

    /**
     * @dev returns the amount of tables there are right now.
     */
    function getTables() public view returns (uint256) {
        return tables.length;
    }

    /**
     * @dev returns a specific table.
     */
    function getTable(uint64 tableNumber) public view returns (address) {
        return tables[tableNumber];
    }

    /**
     * @dev returns true if the table is private .
     */
    function getPrivateBool(address Table) public view returns (bool privateGame) {
        return BlackJack(Table).privateGame();
    }

    /**
     * @dev internal function to set the subID
     */
    function setSubbie(uint256 sub) public onlyOwner {
        subbie = sub;
    }

    /**
     * @dev internal function to set the VRF.
     */
    function setVRF(address _vrf) public onlyOwner {
        vrf = _vrf;
    }
}
