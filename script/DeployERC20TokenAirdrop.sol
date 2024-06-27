// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "test/utils/Utils.sol";
import "forge-std/Script.sol";

import "src/ERC20TokenAirdrop.sol";

contract DeployERC20TokenAirdrop is Script, Utils {
    function run() public {
        vm.createSelectFork(vm.rpcUrl("base"));

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        ERC20TokenAirdrop airdroper = new ERC20TokenAirdrop();
    }
}
