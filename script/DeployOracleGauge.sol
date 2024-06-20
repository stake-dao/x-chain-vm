// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "test/utils/Utils.sol";
import "forge-std/Script.sol";

import {GaugeControllerOracle} from "src/GaugeControllerOracle.sol";
import {AxelarExecutable} from "src/AxelarExecutable.sol";

contract DeployOracleGauge is Script, Utils {
    address internal constant DEPLOYER = 0x8898502BA35AB64b3562aBC509Befb7Eb178D4df;
    // GAUGES 
    address internal constant CURVE_GAUGE_CONTROLLER = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB;


    // Contracts
    address internal constant AXELAR_EXECUTABLE = 0xAe86A3993D13C8D77Ab77dBB8ccdb9b7Bc18cd09;
    address internal constant BALANCER_ORACLE=0x575b26EcF33169a394ed654EeCB141497e29bDF3;
    address internal constant FRAX_ORACLE=0xb409a2F7840acfCd3a17B27eC045F80d6f10Eff2;
    address internal constant FXN_ORACLE=0x560306228f913cB4e7A23d11716e8198Cb2c29b5;


    function run() public {
        vm.createSelectFork(vm.rpcUrl("arbitrum"));

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        // Deploy oracles for Curve, Balancer, Frax, FXN
        GaugeControllerOracle oracle = new GaugeControllerOracle(address(0), CURVE_GAUGE_CONTROLLER);
        
        address[] memory oracles = new address[](4);
        oracles[0] = address(oracle);
        oracles[1] = BALANCER_ORACLE;
        oracles[2] = FRAX_ORACLE;
        oracles[3] = FXN_ORACLE;

        oracle.setAxelarExecutable(AXELAR_EXECUTABLE);


        AxelarExecutable(AXELAR_EXECUTABLE).setOracles(oracles);

        // Set block hash now 
        oracle.setEthBlockHash(20129647, bytes32(0x0761399d81362d138c185989539b8fc085d50b332bff8a640330d5ab6bf5c00b));
    }
}