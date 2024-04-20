// Gauge : 0xd5f2e6612E41bE48461FDBA20061E3c778Fe6EC4 (msUSD-FRAXBP)
// User : 0x989aeb4d175e16225e39e87d0d97a3360524ad80 (Convex Locker)

import "test/utils/Utils.sol";

import {MockPlatform} from "src/MockPlatform.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {GaugeController} from "src/interfaces/GaugeController.sol";
import {EthereumStateSender} from "src/EthereumStateSender.sol";
import {CurveGaugeControllerOracle} from "src/CurveGaugeControllerOracle.sol";
import {StateProofVerifier as Verifier} from "src/merkle-utils/StateProofVerifier.sol";

contract MockPlatformTest is Utils {
    EthereumStateSender sender;
    CurveGaugeControllerOracle oracle;
    MockPlatform platform;
    MockERC20 mockToken;

    address internal constant _user = 0x989AEb4d175e16225E39E87d0D97A3360524AD80;
    address internal constant _gauge = 0xd5f2e6612E41bE48461FDBA20061E3c778Fe6EC4;

    // Gauge controller
    address internal constant _gaugeController = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB;
    address internal constant _deployer = 0x8898502BA35AB64b3562aBC509Befb7Eb178D4df;

    uint256 arbitrumForkId;
    uint256 ethereumForkId;

    function setUp() public {
        arbitrumForkId = vm.createFork(vm.rpcUrl("arb"), 201_977_642);
        ethereumForkId = vm.createFork(vm.rpcUrl("mainnet"), 19675722);
        // ethereumForkId = vm.createFork(vm.rpcUrl("mainnet"), 19420040); // Pre Cancun

        vm.selectFork(ethereumForkId);

        // Deploy Oracle + MockPlatform
        oracle = new CurveGaugeControllerOracle(address(0)); // No Axelar executable

        // Deploy MockPlatform
        platform = new MockPlatform(address(oracle), _deployer, _deployer);

        sender = new EthereumStateSender(_deployer);

        mockToken = new MockERC20("MockToken", "MTK", 18);
        // Mint MockToken to user
        mockToken.mint(address(this), 1000e18);
        // Approve
        mockToken.approve(address(platform), 1000e18);
    }

    function test_ClaimWithProofsOnEthereum() public {
        // Create a bribe on Platform , for gauge with MockToken
        platform.createBounty(_gauge, address(this), address(mockToken), 2, 10e18, 1000e18, new address[](0), false);

        // Check if bounty is created
        (address gauge,,,,,,) = platform.bounties(0);
        assertEq(gauge, _gauge);

        // Check if user has correctly voted / swicth to Ethereum Mainnet
        //vm.selectFork(ethereumForkId);

        // Check slopes before
        GaugeController.VotedSlope memory voted_slope =
            GaugeController(_gaugeController).vote_user_slopes(_user, _gauge);

        //assertEq(voted_slope.slope, 62860244516071143); // Slope by the time of the fork

        // Check last user vote
        uint256 last_user_vote = GaugeController(_gaugeController).last_user_vote(_user, _gauge);

        //assertEq(last_user_vote, 1713276131);

        // Generate proof and block_hash, to allow him to claim on Arbitrum
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, block.timestamp / 1 weeks * 1 weeks);

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", _gaugeController, _positions, _blockNumber);

        // Get back to Arbitrum to set block hash on oracle
        //vm.selectFork(arbitrumForkId);
        oracle.setEthBlockHash(_blockNumber, _block_hash);

        console.log("Block Hash");
        console.logBytes32(_block_hash);

        console.log("Block Hash from RLP");
        console.logBytes32(keccak256(_block_header_rlp)); // Should be block hash

        /*

        // Submit State to Oracle.
        oracle.submit_state(_user, _gauge, _block_header_rlp, _proof_rlp);

        /// Retrive the values from the oracle.
        (uint256 slope, uint256 power, uint256 end) = oracle.voteUserSlope(_blockNumber, _user, _gauge);

        console.log("slope: ", slope);
        console.log("power: ", power);
        console.log("end: ", end);
        */
    }
}
