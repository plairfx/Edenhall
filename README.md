## What is Edenhall?
Edenhall is a card game blockchain-project that offers people a way to play card-games in tables fully onchain powered by Chainlink VRF,

A player can create a `private` or a `public` table through `Edenhall.sol` which will in turn create a table which can be enjoyed by up to 7 players.

People can create a table for a BlackJack game, invite their friends and have fun.


## Documentation
Contracts on Sepolia:

Edenhall: https://sepolia.etherscan.io/address/0x3ff564f745ba65d2043a7ce7a25421d63915067d
BlackjackUtils: https://sepolia.etherscan.io/address/0xea32542dbf6b04548a0d3a2879e305b92a49eed7#code
Blackjack Table deployed from Edenhall -> https://sepolia.etherscan.io/address/0x36490c208ca981e47202bd243af910458bbdce12


### Installation

```shell
$ forge install
```

```shell
$ forge build
```


## Known issues/DesignIssues:
- Player can join other tables while being in game,
- TableOwners can only for now initially 'invite' players during 
tablecreation, but not after.
- PrivateTable joinPrivateTable is at this moment useless, as we switched from one simple array instead of 8 public variables.
- TableOwners in privateGames cannot invite new players.
- Contracts do not add a chainlink consumer/create a subId automatically/put it in.
- Right now `requestRandomWords` will request 24 words, instead of basing it around the amount of players.


# Note
This is not a deployment-ready project, The code is unaudited and has issues as stated below.















