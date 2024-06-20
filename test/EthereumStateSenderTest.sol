// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "test/utils/Utils.sol";

import {IAxelarGateway} from "../src/interfaces/IAxelarGateway.sol";
import {IAxelarGasReceiverProxy} from "../src/interfaces/IAxelarGasReceiverProxy.sol";
import {EthereumStateSender} from "../src/EthereumStateSender.sol";
import {MockAxelarGateway} from "./mocks/MockAxelarGateway.sol";
import {MockAxelarGasReceiver} from "./mocks/MockAxelarGasReceiver.sol";

contract EthereumStateSenderTest is Utils {
    EthereumStateSender public ethereumStateSender;
    MockAxelarGateway public mockAxelarGateway;
    MockAxelarGasReceiver public mockAxelarGasReceiver;

    address public constant AXELAR_GATEWAY = 0x4F4495243837681061C4743b74B3eEdf548D56A5;
    address public constant AXELAR_GAS_RECEIVER = 0x2d5d7d31F671F86C782533cc367F14109a082712;

    function setUp() public {
        // Set current timestamp and block (preventing block(0))

        vm.warp(1700000000);
        vm.roll(1000);

        ethereumStateSender = new EthereumStateSender(address(this));

        // Replace both real AxelarGateway and AxelarGasReceiver with mocks
        mockAxelarGateway = new MockAxelarGateway();
        mockAxelarGasReceiver = new MockAxelarGasReceiver();

        bytes memory axelarMockCode = address(mockAxelarGateway).code;
        bytes memory axelarGasReceiverMockCode = address(mockAxelarGasReceiver).code;

        vm.etch(AXELAR_GATEWAY, axelarMockCode);
        vm.etch(AXELAR_GAS_RECEIVER, axelarGasReceiverMockCode);
    }

    function test_sendBlockhashWithSufficientValue() public {
        uint256 sendValue = ethereumStateSender.sendBlockHashMinValue();
        vm.deal(address(this), sendValue);

        ethereumStateSender.sendBlockhash{value: sendValue}("arbitrum", address(0x123));

        uint256 blockNumber = block.number - 1;
        bytes32 blockHash = blockhash(blockNumber);

        checkPayloadAndDestination(address(0x123), "arbitrum", blockNumber, blockHash);
    }

    function test_sendBlockhashWithInsufficientValue() public {
        vm.expectRevert(EthereumStateSender.VALUE_TOO_LOW.selector);
        ethereumStateSender.sendBlockhash{value: 0}("arbitrum", address(0x123));
    }

    function test_sendBlockhashTwiceReverts() public {
        uint256 sendValue = ethereumStateSender.sendBlockHashMinValue();
        ethereumStateSender.sendBlockhash{value: sendValue}("arbitrum", address(0x123));

        uint256 blockNumber = block.number - 1;
        bytes32 blockHash = blockhash(blockNumber);

        checkPayloadAndDestination(address(0x123), "arbitrum", blockNumber, blockHash);

        vm.expectRevert(EthereumStateSender.ALREADY_SENT.selector);
        ethereumStateSender.sendBlockhash{value: sendValue}("arbitrum", address(0x123));
    }

    function test_setAdminOnlyByAdmin() public {
        vm.prank(address(0xdead)); // Impersonate a non-admin address
        vm.expectRevert(EthereumStateSender.ONLY_ADMIN.selector);
        ethereumStateSender.setAdmin(address(0xdead));
    }

    function test_setSendBlockHashMinValueOnlyByAdmin() public {
        uint256 newValue = 0.005 ether;
        vm.prank(address(this));
        ethereumStateSender.setSendBlockHashMinValue(newValue);

        assertEq(ethereumStateSender.sendBlockHashMinValue(), newValue);
    }

    function test_sendBlockhashEmergencyOnlyByAdmin() public {
        uint256 sendValue = ethereumStateSender.sendBlockHashMinValue();
        vm.deal(address(0xdead), sendValue);
        vm.prank(address(0xdead));
        vm.expectRevert(EthereumStateSender.ONLY_ADMIN.selector);
        ethereumStateSender.sendBlockhashEmergency{value: sendValue}("ETH", address(0x123));
    }

    // Multi-send

    function test_sendMultipleChainsContracts() public {
        // function sendBlockhash(string[] calldata _destinationChains, address[][] calldata _destinationContracts)
        // value must be min value * number of contracts * number of chains

        uint256 _numberOfChains = 2;
        uint256 _numberOfContractsPerChain = 2;

        uint256 sendValue = ethereumStateSender.sendBlockHashMinValue() * _numberOfChains * _numberOfContractsPerChain;

        string[] memory destinationChains = new string[](_numberOfChains);
        destinationChains[0] = "arbitrum";
        destinationChains[1] = "base";

        address[][] memory destinationContracts = new address[][](_numberOfChains);
        destinationContracts[0] = new address[](_numberOfContractsPerChain);
        destinationContracts[1] = new address[](_numberOfContractsPerChain);

        // Fill destinationContracts for each chain
        destinationContracts[0][0] = address(0x123);
        destinationContracts[0][1] = address(0x234);
        destinationContracts[1][0] = address(0x456);
        destinationContracts[1][1] = address(0x678);

        vm.deal(address(this), sendValue);
        ethereumStateSender.sendBlockhash{value: sendValue}(destinationChains, destinationContracts);

        uint256 blockNumber = block.number - 1;
        bytes32 blockHash = blockhash(blockNumber);

        // Should have called callContract 4 times
        MockAxelarGateway _mockAxelarGateway = MockAxelarGateway(AXELAR_GATEWAY);
        (string memory chainA, string memory storedAddressStringA, bytes memory payloadA) =
            _mockAxelarGateway.getDestination(0); // First => 0x123
        (string memory chainB, string memory storedAddressStringB, bytes memory payloadB) =
            _mockAxelarGateway.getDestination(1); // Second => 0x234
        (string memory chainC, string memory storedAddressStringC, bytes memory payloadC) =
            _mockAxelarGateway.getDestination(2); // Third => 0x456
        (string memory chainD, string memory storedAddressStringD, bytes memory payloadD) =
            _mockAxelarGateway.getDestination(3); // Fourth => 0x678

        address storedAddressA = stringToAddress(storedAddressStringA);
        address storedAddressB = stringToAddress(storedAddressStringB);
        address storedAddressC = stringToAddress(storedAddressStringC);
        address storedAddressD = stringToAddress(storedAddressStringD);

        // Assert values
        assertEq(chainA, "arbitrum");
        assertEq(storedAddressA, address(0x123));
        assertEq(payloadA, abi.encodeWithSignature("setEthBlockHash(uint256,bytes32)", blockNumber, blockHash));

        assertEq(chainB, "arbitrum");
        assertEq(storedAddressB, address(0x234));
        assertEq(payloadB, abi.encodeWithSignature("setEthBlockHash(uint256,bytes32)", blockNumber, blockHash));

        assertEq(chainC, "base");
        assertEq(storedAddressC, address(0x456));
        assertEq(payloadC, abi.encodeWithSignature("setEthBlockHash(uint256,bytes32)", blockNumber, blockHash));

        assertEq(chainD, "base");
        assertEq(storedAddressD, address(0x678));
        assertEq(payloadD, abi.encodeWithSignature("setEthBlockHash(uint256,bytes32)", blockNumber, blockHash));
    }

    function test_sendBlockhashNoDestinationChainsReverts() public {
        string[] memory destinationChains = new string[](0);
        address[][] memory destinationContracts = new address[][](0);

        vm.expectRevert(EthereumStateSender.NO_DESTINATION_CHAINS.selector);
        ethereumStateSender.sendBlockhash{value: 0.01 ether}(destinationChains, destinationContracts);
    }

    function test_sendBlockhashAlreadySentReverts() public {
        string[] memory destinationChains = new string[](1);
        destinationChains[0] = "arbitrum";

        address[][] memory destinationContracts = new address[][](1);
        destinationContracts[0] = new address[](1);
        destinationContracts[0][0] = address(0x123);

        uint256 sendValue = ethereumStateSender.sendBlockHashMinValue();
        vm.deal(address(this), sendValue*2);

        // First call should succeed
        ethereumStateSender.sendBlockhash{value: sendValue}(destinationChains, destinationContracts);

        // Second call should revert
        vm.expectRevert(EthereumStateSender.ALREADY_SENT.selector);
        ethereumStateSender.sendBlockhash{value: sendValue}(destinationChains, destinationContracts);
    }

    function checkPayloadAndDestination(
        address expectedAddress,
        string memory expectedChain,
        uint256 expectedBlockNumber,
        bytes32 expectedBlockHash
    ) internal {
        MockAxelarGateway _mockAxelarGateway = MockAxelarGateway(AXELAR_GATEWAY);
        (string memory chain, string memory storedAddress, bytes memory payload) = _mockAxelarGateway.getDestination(0);

        address destinationAddress = stringToAddress(storedAddress);
        bytes memory expectedPayload =
            abi.encodeWithSignature("setEthBlockHash(uint256,bytes32)", expectedBlockNumber, expectedBlockHash);

        assertEq(destinationAddress, expectedAddress);
        assertEq(chain, expectedChain);
        assertEq(payload, expectedPayload);
    }
}
