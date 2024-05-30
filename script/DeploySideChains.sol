// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "test/utils/Utils.sol";
import "forge-std/Script.sol";

import {Platform} from "src/Platform.sol";
import {PlatformClaimable} from "src/PlatformClaimable.sol";

contract DeploySideChains is Script, Utils {
    Platform internal constant platform = Platform(0xB854cF650F5492d23e52cb2A7a58B787fC25B0Bb);
    address internal constant oracle = 0x9ED11340850DA2DEeeE3B471b335dA90272B066F;

    address internal constant DEPLOYER = 0x8898502BA35AB64b3562aBC509Befb7Eb178D4df;

    function run() public {
        vm.startBroadcast(DEPLOYER);

        PlatformClaimable platformClaimable = new PlatformClaimable(platform, oracle);

        assertEq(address(platformClaimable.platform()), address(platform));
        assertEq(address(platformClaimable.gaugeController()), oracle);
        
        vm.stopBroadcast();
    }
}
