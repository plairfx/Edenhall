// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Edenhall} from "../src/Edenhall.sol";
import {info} from "./library/info.sol";
import {Errors} from "./library/Errors.sol";
import {Events} from "./library/Events.sol";
import {IBlackjackUtils} from "src/interface/IBlackJackUtils.sol";

contract BlackJack is VRFConsumerBaseV2Plus, ReentrancyGuard {
    Edenhall public EH;

    struct Cards {
        uint8 value;
        uint8 suit;
    }

    struct PlayerStates {
        bool playerBust;
        uint8 playerCards;
        bool playerStand;
        bool playerHit;
        bool playerJoined;
    }

    mapping(address player => PlayerStates) public playerState;

    address public tableOwner;
    address public EdenhallAdd;
    address Utils;

    // Game Info
    Cards[] public deck;
    address[] public joinedPlayers;

    uint8 public cardsRemaining;

    // Game
    bool public privateGame;
    bool public gameStarted;
    uint256 public startTimeStamp;
    uint8 constant BLACKJACK = 21;

    // Chainlink
    bytes32 public immutable keyHash;
    uint32 public immutable callbackGasLimit = 2400000;
    uint16 public immutable requestConfirmations = 3;
    uint32 public immutable numWords = 24;
    uint256 public SubscriptionId;

    // Dealer/House
    uint8 public houseCards;

    modifier onlyTableOwner() {
        require(msg.sender == tableOwner, Errors.NotTheTableOwner());
        _;
    }

    modifier onlyEdenHall() {
        require(msg.sender == address(EdenhallAdd), Errors.NotEdenHall());
        _;
    }

    modifier onlyBJUtils() {
        require(msg.sender == address(Utils), Errors.NotBJUtils());
        _;
    }

    constructor(
        address[] memory players,
        uint256 subscriptionId,
        address _vrfCoordinator,
        bytes32 KEY_HASH,
        bool GamePrivate,
        address EH,
        address TableOwner,
        address utils
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        //Chainlink
        SubscriptionId = subscriptionId;
        keyHash = KEY_HASH;
        Utils = utils;

        privateGame = GamePrivate;
        if (GamePrivate) {
            tableOwner = TableOwner;
            joinedPlayers = players;
        } else {
            joinedPlayers = players;
        }

        EdenhallAdd = EH;
    }

    function joinTable(address Player) public {
        require(Player == msg.sender || msg.sender == EdenhallAdd || msg.sender == Utils);
        require(!privateGame);
        require(!gameStarted, Errors.GameHasAlreadyStarted());
        _joinTable(Player);
    }

    function joinPrivateTable(address Player) public {
        require(privateGame);
        if (msg.sender == EdenhallAdd) {} else {
            require(address(Player) == msg.sender);
        }

        require(_checkInvitedPlayer(Player), Errors.PlayerNotInvited());
        emit Events.PlayerJoined(Player);
    }

    /**
     * @dev Allows a player in the game to stand.
     * which allows him not to use the `drawCard` function anymore
     */
    function stand() public {
        (address currentPlayer, bool isPlayer) = _checkPlayer();
        require(isPlayer, Errors.NotAPlayer());
        require(msg.sender == currentPlayer);
        require(!playerState[currentPlayer].playerBust, Errors.PlayerHasAlreadyBusted());
        _stand(currentPlayer);
    }

    function leaveTable(address player) public {
        require(!gameStarted);
        require(player == msg.sender);
        _removePlayer(player);
        emit Events.PlayerLeft(player);
    }

    /**
     * @dev StartGame offers a ingame player to start the game.
     * for each player we draw 2 cards.
     */
    function StartGame() public nonReentrant returns (uint256) {
        (address currentPlayer, bool isPlayer) = _checkPlayer();

        require(isPlayer);
        require(!gameStarted);
        if (cardsRemaining < 24) {
            _shuffleDeck();
        }

        uint8 amountPlayers;
        for (uint8 i = 0; i < joinedPlayers.length; i++) {
            amountPlayers += 1;
        }

        uint256 requestId = requestRandomWords();

        startTimeStamp = block.timestamp;

        return requestId;
    }

    function kickPlayer(address Player) public onlyTableOwner {
        require(privateGame, Errors.GameIsNotPrivate());
        require(!gameStarted, Errors.GameHasAlreadyStarted());
        _removePlayer(Player);
        emit Events.PlayerKicked(Player);
    }

    /**
     * @dev Allows a player in the game too draw a card.
     */
    function drawCard() public returns (uint256) {
        (address Player, bool isPlayer) = _checkPlayer();
        require(isPlayer, Errors.NotAPlayer());

        PlayerStates storage playerstate = playerState[Player];

        // player cannot draw at 21 to lose deliberately
        require(playerstate.playerCards < 21);
        // player cannot be busted (aka over 21.).
        require(!playerstate.playerBust);
        // player should not standing.
        require(!playerstate.playerStand, Errors.PlayerAlreadyStanding());

        playerstate.playerHit = true;

        uint256 requestId = requestRandomWords();

        startTimeStamp += 12 seconds;

        return requestId;
    }

    /**
     * @dev Allows BJUtils contract to addhouseCard and a playerCards to players.
     */
    function addHouseCards(uint8 value) public onlyBJUtils {
        houseCards += value;
        cardsRemaining -= 1;
    }

    function addPlayerCard(uint8 value, address player) public onlyBJUtils {
        playerState[player].playerCards += value;
        cardsRemaining -= 1;
    }

    function transferTableOwner(address _owner) public onlyTableOwner {
        tableOwner = _owner;
    }

    /**
     * @dev checks if a player is in the game, and returns boolie true if the player is in the game and if false  0x0 player & false.
     */
    function _checkPlayer() internal view returns (address thePlayer, bool boolie) {
        for (uint8 i = 0; i < joinedPlayers.length; i++) {
            address player = joinedPlayers[i];

            if (player == msg.sender) {
                return (player, true);
            }
        }
    }

    function _checkInvitedPlayer(address Player) internal view returns (bool) {
        uint8 playerLength;
        address invitedPlayer;
        for (playerLength = 0; playerLength < joinedPlayers.length; playerLength++) {
            address player = joinedPlayers[playerLength];
            if (player == Player) {
                invitedPlayer = player;
                break;
            }
        }
        if (invitedPlayer == Player) {
            return true;
        }
    }

    function _stand(address Player) internal {
        playerState[Player].playerStand = true;
        if (_NoHitPlayers() && (block.timestamp - startTimeStamp) > 1 minutes) {
            uint256 requestId = requestRandomWords();
        }
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        if (!gameStarted) {
            _play(randomWords);
        } else if (gameStarted && _NoHitPlayers()) {
            _finishGame(randomWords);
        } else {
            _drawCard(randomWords);
        }
    }

    /**
     * @dev internal function which is used with _stand to finishUp the game.
     */
    function _NoHitPlayers() internal view returns (bool yes) {
        uint256 joinedplayerslength = joinedPlayers.length;
        uint256 x = 0;
        for (uint8 i = 0; i < joinedplayerslength; i++) {
            address player = joinedPlayers[i];

            if (!playerState[player].playerHit) {
                x += 1;
            }
            if (x == joinedplayerslength) {
                return true;
            }
        }
    }

    function requestRandomWords() internal returns (uint256 requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: SubscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        return requestId;
    }

    /**
     * @dev Function that finishes the game,
     * the dealer/house will keep drawing until they are at 17 or +.
     * this will reset all the values to false/0 so a new game can start.
     */
    function _finishGame(uint256[] memory randomWords) internal {
        IBlackjackUtils(Utils).emitPlayerEvents(joinedPlayers, randomWords);

        _resetGame();
    }

    function _resetGame() private {
        address[] memory players = joinedPlayers;
        // Deleting all values from the 7 players..

        for (uint8 i = 0; i < joinedPlayers.length; i++) {
            delete playerState[players[i]];
        }

        houseCards = 0;
        gameStarted = false;
    }

    function _joinTable(address Player) private {
        uint256 joinedPlayerlength = joinedPlayers.length;
        if (joinedPlayerlength < 8 && joinedPlayerlength != 7) {
            joinedPlayers.push(Player);
            emit Events.PlayerJoined(Player);
        } else {
            revert();
        }
    }

    function _play(uint256[] memory randomWords) private {
        IBlackjackUtils(Utils)._playGame(randomWords, joinedPlayers);
        gameStarted = true;
    }

    function _drawCard(uint256[] memory randomWords) private {
        for (uint8 i = 0; i < joinedPlayers.length; i++) {
            address player = joinedPlayers[i];
            PlayerStates storage playerstate = playerState[player];
            if (playerstate.playerHit) {
                uint8 cardIndex = uint8(randomWords[i] % cardsRemaining);
                (uint8 card, uint8 suit) = (deck[cardIndex].value, deck[cardIndex].suit);

                _playerDrawn(player, card, suit);
                playerstate.playerHit = false;
                cardsRemaining -= 1;
            }
        }
    }

    function _shuffleDeck() private {
        require(cardsRemaining < 24);
        // removing the deck...
        delete deck;
        deck = new Cards[](52);
        // Intializing deck to suit all the cards we need...
        for (uint8 i = 0; i < 52; i++) {
            deck[i] = Cards({value: (i % 13) + 1, suit: (i / 13)});
        }
        cardsRemaining = 52;
    }

    function _removePlayer(address removingPlayer) private {
        uint8 playerLength;
        for (playerLength = 0; playerLength < joinedPlayers.length; playerLength++) {
            address player = joinedPlayers[playerLength];
            if (player == removingPlayer) {
                if (joinedPlayers.length - 1 != 0) {
                    address Jplayer = joinedPlayers[joinedPlayers.length - 1];
                    joinedPlayers[playerLength] = Jplayer;
                }
                joinedPlayers.pop();
            }
        }
    }

    function _playerDrawn(address player, uint8 card, uint8 suit) private {
        IBlackjackUtils(Utils)._playerEmit(card, suit, 0, 0, player, false, joinedPlayers);

        PlayerStates storage playerstate = playerState[player];

        uint8 playerCardsBefore = playerstate.playerCards;

        uint8 newCard = IBlackjackUtils(Utils)._playerDrawnCheck(playerCardsBefore, card);

        card = newCard;
        playerstate.playerCards += card;

        uint8 playerCardsValue = playerstate.playerCards;

        if (playerCardsValue > 21) {
            playerstate.playerBust = true;
            emit Events.PlayerBust(player, playerCardsValue);
        }
    }

    function setSubscriptionId(uint256 sub_id) public onlyEdenHall {
        SubscriptionId = sub_id;
    }

    function getCard(uint256 index) public view returns (uint8, uint8) {
        Cards memory cards = deck[index];
        return (cards.value, cards.suit);
    }

    function getPlayers() public view returns (uint256) {
        return joinedPlayers.length;
    }

    function getArray() public view returns (address[] memory) {
        return joinedPlayers;
    }

    function getPlayer(uint8 playerOrder) public view returns (address) {
        return joinedPlayers[playerOrder];
    }

    function getCards(address Player) public view returns (uint8) {
        return playerState[Player].playerCards;
    }

    function getPlayerState(address player) public view returns (PlayerStates memory) {
        return playerState[player];
    }

    function getDeck() public view returns (Cards[] memory) {
        return deck;
    }
}
