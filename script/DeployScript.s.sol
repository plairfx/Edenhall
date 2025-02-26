//SPDX-License-Identifier: MIT

import {Edenhall} from "../src/Edenhall.sol";
import {BlackJack} from "../src/Blackjack.sol";
import {Test, console2, console} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {BlackjackUtils} from "src/BlackjackUtils.sol";

pragma solidity 0.8.28;

contract DeployScript is Script {
    Edenhall public EH;
    VRFCoordinatorV2_5Mock public vrf;
    BlackjackUtils public BJU;

    function run() external {
        if (block.chainid == 11155111) {
            vm.startBroadcast();
            // Launch Edenhall contract.

            BJU = new BlackjackUtils();
            EH = new Edenhall(address(BJU));
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            vm.roll(10);
            // Launch Edenhall contract.
            BJU = new BlackjackUtils();
            EH = new Edenhall(address(BJU));
            // setup chainlink
            vrf = new VRFCoordinatorV2_5Mock(1, 1, 4);
            uint256 subId = vrf.createSubscription();
            EH.setVRF(address(vrf));
            vrf.fundSubscription(subId, 1 ether);

            EH.setSubbie(subId);
        }
    }
}
