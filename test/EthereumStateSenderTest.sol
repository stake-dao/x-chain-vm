// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.20;

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
    address public constant ARB_A = address(0x123);
    address public constant ARB_B = address(0x456);
    address public constant BASE_A = address(0x789);
    address public constant BASE_B = address(0x012);

    function setUp() public {
        vm.warp(1700000000);
        vm.roll(1000);

        ethereumStateSender = new EthereumStateSender(address(this));
        mockAxelarGateway = new MockAxelarGateway();
        mockAxelarGasReceiver = new MockAxelarGasReceiver();

        bytes memory axelarMockCode = address(mockAxelarGateway).code;
        bytes memory axelarGasReceiverMockCode = address(mockAxelarGasReceiver).code;

        vm.etch(AXELAR_GATEWAY, axelarMockCode);
        vm.etch(AXELAR_GAS_RECEIVER, axelarGasReceiverMockCode);

        EthereumStateSender.ChainContract[] memory chains = new EthereumStateSender.ChainContract[](2);

        address[] memory arbContracts = new address[](2);
        arbContracts[0] = ARB_A;
        arbContracts[1] = ARB_B;

        address[] memory baseContracts = new address[](2);
        baseContracts[0] = BASE_A;
        baseContracts[1] = BASE_B;

        ethereumStateSender.addChain("arbitrum", arbContracts);
        ethereumStateSender.addChain("base", baseContracts);
    }

    function test_InitialState() public {
        assertEq(ethereumStateSender.governance(), address(this));
        assertEq(ethereumStateSender.getEnabledContracts(), 4);

        address[] memory arbContracts = new address[](2);
        arbContracts[0] = ARB_A;
        arbContracts[1] = ARB_B;
        validateChain(0, "arbitrum", arbContracts);

        address[] memory baseContracts = new address[](2);
        baseContracts[0] = BASE_A;
        baseContracts[1] = BASE_B;
        validateChain(1, "base", baseContracts);
    }

    function test_sendBlockHash() public {
        uint256 sendValue = ethereumStateSender.sendBlockHashMinValue() * ethereumStateSender.getEnabledContracts();
        vm.deal(address(0xBABA), sendValue);
        ethereumStateSender.sendBlockHash{value: sendValue}();

        // Check mappings
        assertEq(ethereumStateSender.blockNumbers(ethereumStateSender.getCurrentPeriod()), block.number - 1);
        assertEq(ethereumStateSender.blockHashes(ethereumStateSender.getCurrentPeriod()), blockhash(block.number - 1));

        checkPayloadAndDestination(0, ARB_A, "arbitrum", block.number - 1, blockhash(block.number - 1));
        checkPayloadAndDestination(1, ARB_B, "arbitrum", block.number - 1, blockhash(block.number - 1));

        checkPayloadAndDestination(2, BASE_A, "base", block.number - 1, blockhash(block.number - 1));
        checkPayloadAndDestination(3, BASE_B, "base", block.number - 1, blockhash(block.number - 1));
    }

    function testFail_SendWithInsufficientValue() public {
        uint256 insufficientValue =
            ethereumStateSender.sendBlockHashMinValue() * ethereumStateSender.getEnabledContracts() - 0.001 ether;
        vm.expectRevert(bytes("InsufficientValue"));
        ethereumStateSender.sendBlockHash{value: insufficientValue}();

        vm.expectRevert(bytes("InsufficientValue"));
        ethereumStateSender.sendBlockHashEmergency{value: insufficientValue}(
            "arbitrum", new address[](1), block.number, blockhash(block.number - 1)
        );
    }

    function testFail_SendTooCloseToCurrentPeriod() public {
        uint256 currentPeriod = ethereumStateSender.getCurrentPeriod();
        vm.warp(currentPeriod + 4 minutes);
        uint256 sufficientValue =
            ethereumStateSender.sendBlockHashMinValue() * ethereumStateSender.getEnabledContracts();
        vm.expectRevert(bytes("TooCloseToCurrentPeriod"));
        ethereumStateSender.sendBlockHash{value: sufficientValue}();
    }

    function testFail_AddChainNotByGovernance() public {
        address nonGovernanceUser = address(0xABC);
        vm.prank(nonGovernanceUser);
        vm.expectRevert(bytes("GovernanceOnly"));
        ethereumStateSender.addChain("newChain", new address[](1));
    }

    function testSendBlockHashEmergency() public {
        string memory chain = "arbitrum";
        address[] memory contracts = new address[](2);
        contracts[0] = address(0xCACA);
        contracts[1] = address(0xBACA);
        uint256 blockNumber = block.number - 1;
        bytes32 blockHash = blockhash(block.number - 1);
        uint256 sendValue = ethereumStateSender.sendBlockHashMinValue() * contracts.length;

        // Test successful sending
        vm.deal(address(this), sendValue);
        ethereumStateSender.sendBlockHashEmergency{value: sendValue}(chain, contracts, blockNumber, blockHash);

        checkPayloadAndDestination(0, address(0xCACA), "arbitrum", block.number - 1, blockhash(block.number - 1));
        checkPayloadAndDestination(1, address(0xBACA), "arbitrum", block.number - 1, blockhash(block.number - 1));
    }

    function testSendBlockHashEmergency_AlreadySent() public {
        string memory chain = "arbitrum";
        address[] memory contracts = new address[](2);
        contracts[0] = ARB_A;
        contracts[1] = ARB_B;
        uint256 blockNumber = block.number - 1;
        bytes32 blockHash = blockhash(block.number - 1);
        uint256 sendValue = ethereumStateSender.sendBlockHashMinValue() * contracts.length;

        // First send
        vm.deal(address(this), sendValue);
        ethereumStateSender.sendBlockHashEmergency{value: sendValue}(chain, contracts, blockNumber, blockHash);

        // Attempt to send again for the same period
        vm.deal(address(this), sendValue);
        ethereumStateSender.sendBlockHashEmergency{value: sendValue}(chain, contracts, blockNumber, blockHash);
    }

    function testRemoveChainAndSendBlockHash() public {
        ethereumStateSender.removeChain("base");

        uint256 enabledContractsAfterRemoval = ethereumStateSender.getEnabledContracts();
        assertEq(enabledContractsAfterRemoval, 2);

        // Send block hash with the correct value for the remaining contracts
        uint256 sendValue = ethereumStateSender.sendBlockHashMinValue() * enabledContractsAfterRemoval;
        vm.deal(address(this), sendValue);
        ethereumStateSender.sendBlockHash{value: sendValue}();

        // Check that the block hash was sent correctly to the remaining contracts
        address[] memory arbContracts = new address[](2);
        arbContracts[0] = ARB_A;
        arbContracts[1] = ARB_B;
        for (uint256 i = 0; i < arbContracts.length; i++) {
            checkPayloadAndDestination(i, arbContracts[i], "arbitrum", block.number - 1, blockhash(block.number - 1));
        }

        address[] memory baseContracts = new address[](2);
        baseContracts[0] = BASE_A;
        baseContracts[1] = BASE_B;

        // Ensure that the removed contracts did not receive any data
        MockAxelarGateway _mockAxelarGateway = MockAxelarGateway(AXELAR_GATEWAY);
        for (uint256 i = 0; i < baseContracts.length; i++) {
            (,, bytes memory payload) = _mockAxelarGateway.getDestination(i + arbContracts.length);
            assertEq(payload.length, 0, "Removed contract should not receive data");
        }
    }

    ////////////////////////////////////////////////////////////
    /// --- UTILS
    ////////////////////////////////////////////////////////////

    function checkPayloadAndDestination(
        uint256 index,
        address expectedAddress,
        string memory expectedChain,
        uint256 expectedBlockNumber,
        bytes32 expectedBlockHash
    ) internal {
        MockAxelarGateway _mockAxelarGateway = MockAxelarGateway(AXELAR_GATEWAY);
        (string memory chain, string memory storedAddress, bytes memory payload) =
            _mockAxelarGateway.getDestination(index);

        address destinationAddress = stringToAddress(storedAddress);
        bytes memory expectedPayload =
            abi.encodeWithSignature("setEthBlockHash(uint256,bytes32)", expectedBlockNumber, expectedBlockHash);

        assertEq(destinationAddress, expectedAddress);
        assertEq(chain, expectedChain);
        assertEq(payload, expectedPayload);
    }

    function validateChain(uint256 index, string memory expectedChain, address[] memory expectedContracts) internal {
        EthereumStateSender.ChainContract memory chain = ethereumStateSender.getChain(index);
        assertEq(chain.chain, expectedChain);
        for (uint256 i = 0; i < expectedContracts.length; i++) {
            assertEq(chain.contracts[i], expectedContracts[i]);
        }
    }
}
