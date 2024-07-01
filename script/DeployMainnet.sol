// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {EthereumStateSender} from "src/EthereumStateSender.sol";

contract DeploySideChains is Script {
    EthereumStateSender sender;

    address internal constant DEPLOYER = 0x8898502BA35AB64b3562aBC509Befb7Eb178D4df;

    address internal constant arbitrumAxelarExecutable = 0xAe86A3993D13C8D77Ab77dBB8ccdb9b7Bc18cd09;
    address internal constant optimismAxelarExecutable = 0xe742141075767106FeD9F6FFA99f07f33bd66312;
    address internal constant baseAxelarExecutable = 0xe742141075767106FeD9F6FFA99f07f33bd66312;

    function run() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        sender = new EthereumStateSender(DEPLOYER);

        address[] memory arbAxelarExecutables = new address[](1);
        address[] memory opAxelarExecutables = new address[](1);
        address[] memory baseAxelarExecutables = new address[](1);

        arbAxelarExecutables[0] = arbitrumAxelarExecutable;
        opAxelarExecutables[0] = optimismAxelarExecutable;
        baseAxelarExecutables[0] = baseAxelarExecutable;

        sender.addChain("arbitrum", arbAxelarExecutables);
        sender.addChain("optimism", opAxelarExecutables);
        sender.addChain("base", baseAxelarExecutables);

        // Setting the State Sender as strEss on AxelarExecutables

        vm.stopBroadcast();
    }
}
