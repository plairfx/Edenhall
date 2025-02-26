// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

library Errors {
    error GameHasAlreadyStarted();
    error CardsAmountIs21OrAbove();
    error NotAPlayer();
    error PlayerHasAlreadyBusted();
    error NotTheTableOwner();
    error NotEdenHall();
    error PlayerNotInvited();
    error GameIsNotPrivate();
    error PlayerAlreadyStanding();
    error TableAlreadyFull();
    error NotBJUtils();
}
