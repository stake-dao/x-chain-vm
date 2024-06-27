// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "test/utils/Utils.sol";
import "forge-std/Script.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

contract sdMAV is Script, Utils {
    address constant sdMAV = 0x50687515e93C43964733282F9DB8683F80BB02f9;
    address constant sdMAV_Gauge = 0x5B75C60D45BfB053f91B5a9eAe22519DFaa37BB6;
    address constant sdMAV_BSC = 0x75289388d50364c3013583d97bd70cED0e183e32;

    function run() public {
        vm.createSelectFork(vm.rpcUrl("bsc"), 39331960);

        // const amount = userBalance * airdropAmount / totalUserBalance;

        ERC20 sdMAV = ERC20(sdMAV_BSC);

        address user = address(0x1525D8fcAD680088245055fFB43179367D3EFfC0);

        uint256 balance = sdMAV.balanceOf(user) / 10 ** 18;

        console.log("balance", balance);
    }
}
