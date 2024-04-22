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

    //address internal constant _user = 0x989AEb4d175e16225E39E87d0D97A3360524AD80;
    //address internal constant _gauge = 0xd5f2e6612E41bE48461FDBA20061E3c778Fe6EC4;
    address internal constant _user = 0xecdED8b1c603cF21299835f1DFBE37f10F2a29Af;
    address internal constant _gauge = 0x26F7786de3E6D9Bd37Fcf47BE6F2bC455a21b74A;

    // Gauge controller
    address internal constant _gaugeController = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB;
    address internal constant _deployer = 0x8898502BA35AB64b3562aBC509Befb7Eb178D4df;

    uint256 arbitrumForkId;
    uint256 ethereumForkId;

    /*
    address _blacklistedA = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6; // Stake Locker
    address _blacklistedB = 0x989AEb4d175e16225E39E87d0D97A3360524AD80; // Convex Locker
    address _blacklistedC = 0xF147b8125d2ef93FB6965Db97D6746952a133934; // Yearn Locker
    */

    address _blacklistedA = 0x425d16B0e08a28A3Ff9e4404AE99D78C0a076C5A;
    address _blacklistedB = 0x39415255619783A2E71fcF7d8f708A951d92e1b6;
    address _blacklistedC = 0x7a16fF8270133F063aAb6C9977183D9e72835428;
    address _blacklistedD = 0xF89501B77b2FA6329F94F5A05FE84cEbb5c8b1a0;
    address _blacklistedE = 0x9B44473E223f8a3c047AD86f387B80402536B029;
    address _blacklistedF = 0x32D03DB62e464c9168e41028FFa6E9a05D8C6451;
    address _blacklistedG = 0xCf72b6323bD64D861E7A33B50f6b53aceA46976B;
    address _blacklistedH = 0x0e5e736101542b6c0b5724724F3B4bF4e85baFB4;

    function setUp() public {
        arbitrumForkId = vm.createFork(vm.rpcUrl("arb"), 201_977_642);
        ethereumForkId = vm.createFork(vm.rpcUrl("mainnet"), 19710129);
        //ethereumForkId = vm.createFork(vm.rpcUrl("mainnet"), 19675722);
        // ethereumForkId = vm.createFork(vm.rpcUrl("mainnet"), 19420040); // Pre Cancun

        // Deploy StateSender
        vm.selectFork(ethereumForkId);
        sender = new EthereumStateSender(_deployer);

        vm.selectFork(arbitrumForkId);

        // Deploy Oracle + MockPlatform
        oracle = new CurveGaugeControllerOracle(address(0)); // No Axelar executable

        // Deploy MockPlatform
        platform = new MockPlatform(address(oracle), _deployer, _deployer);

        mockToken = new MockERC20("MockToken", "MTK", 18);
        // Mint MockToken to user
        mockToken.mint(address(this), 9000e18);
        // Approve
        mockToken.approve(address(platform), 1000e18);
    }

    function test_ClaimWithProofsOnEthereum() public {
        // Blacklist an address (liquid locker Stake dao)
        address[] memory blacklist = new address[](8);
        blacklist[0] = _blacklistedA;
        blacklist[1] = _blacklistedB;
        blacklist[2] = _blacklistedC;
        blacklist[3] = _blacklistedD;
        blacklist[4] = _blacklistedE;
        blacklist[5] = _blacklistedF;
        blacklist[6] = _blacklistedG;
        blacklist[7] = _blacklistedH;

        // Create a bribe on Platform , for gauge with MockToken
        platform.createBounty(_gauge, address(this), address(mockToken), 2, 10e18, 900e18, blacklist, false);

        // Check if bounty is created
        (address gauge,,,,,,) = platform.bounties(0);
        assertEq(gauge, _gauge);

        // Check if user has correctly voted / swicth to Ethereum Mainnet
        vm.selectFork(ethereumForkId);

        /*
        // Check slopes before
        GaugeController.VotedSlope memory voted_slope_og =
            GaugeController(_gaugeController).vote_user_slopes(_user, _gauge);
        */

        // Check last user vote
        //uint256 last_user_vote = GaugeController(_gaugeController).last_user_vote(_user, _gauge);

        //assertEq(last_user_vote, 1713276131);

        // Generate proof and block_hash, to allow him to claim on Arbitrum
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, block.timestamp / 1 weeks * 1 weeks);

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", _gaugeController, _positions, _blockNumber);

        // since there is blacklist, need the proofs also
        (,,, _positions,) = sender.generateEthProofParams(_blacklistedA, _gauge, block.timestamp / 1 weeks * 1 weeks);

        (,, bytes memory _blacklistedA_proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // since there is blacklist, need the proofs also
        (,,, _positions,) = sender.generateEthProofParams(_blacklistedB, _gauge, block.timestamp / 1 weeks * 1 weeks);

        (,, bytes memory _blacklistedB_proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // since there is blacklist, need the proofs also
        (,,, _positions,) = sender.generateEthProofParams(_blacklistedC, _gauge, block.timestamp / 1 weeks * 1 weeks);

        (,, bytes memory _blacklistedC_proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // since there is blacklist, need the proofs also
        (,,, _positions,) = sender.generateEthProofParams(_blacklistedD, _gauge, block.timestamp / 1 weeks * 1 weeks);

        (,, bytes memory _blacklistedD_proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // since there is blacklist, need the proofs also
        (,,, _positions,) = sender.generateEthProofParams(_blacklistedE, _gauge, block.timestamp / 1 weeks * 1 weeks);

        (,, bytes memory _blacklistedE_proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // since there is blacklist, need the proofs also
        (,,, _positions,) = sender.generateEthProofParams(_blacklistedF, _gauge, block.timestamp / 1 weeks * 1 weeks);

        (,, bytes memory _blacklistedF_proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // since there is blacklist, need the proofs also
        (,,, _positions,) = sender.generateEthProofParams(_blacklistedG, _gauge, block.timestamp / 1 weeks * 1 weeks);

        (,, bytes memory _blacklistedG_proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // since there is blacklist, need the proofs also
        (,,, _positions,) = sender.generateEthProofParams(_blacklistedH, _gauge, block.timestamp / 1 weeks * 1 weeks);

        (,, bytes memory _blacklistedH_proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Get back to Arbitrum to set block hash on oracle
        vm.selectFork(arbitrumForkId);

        console.log("Block Number: %s", _blockNumber);

        console.logBytes32(_block_hash);

        oracle.setEthBlockHash(_blockNumber, _block_hash);

        /*
        // Submit State to Oracle.
        oracle.submit_state(_user, _gauge, _block_header_rlp, _proof_rlp);

        /// Retrive the values from the oracle.
        (uint256 slope, uint256 power, uint256 end) = oracle.voteUserSlope(_blockNumber, _user, _gauge);

        assertEq(slope, voted_slope_og.slope);
        assertEq(power, voted_slope_og.power);
        assertEq(end, voted_slope_og.end);
        */

        bytes[] memory _blacklistedProofs = new bytes[](8);
        _blacklistedProofs[0] = _blacklistedA_proof_rlp;
        _blacklistedProofs[1] = _blacklistedB_proof_rlp;
        _blacklistedProofs[2] = _blacklistedC_proof_rlp;
        _blacklistedProofs[3] = _blacklistedD_proof_rlp;
        _blacklistedProofs[4] = _blacklistedE_proof_rlp;
        _blacklistedProofs[5] = _blacklistedF_proof_rlp;
        _blacklistedProofs[6] = _blacklistedG_proof_rlp;
        _blacklistedProofs[7] = _blacklistedH_proof_rlp;

        // ProofData
        MockPlatform.ProofData memory _proofData = MockPlatform.ProofData({
            user: _user,
            headerRlp: _block_header_rlp,
            userProofRlp: _proof_rlp,
            blackListedProofsRlp: _blacklistedProofs
        });

        /*
            struct ProofData {
        // Address of user.
        address user;
        // RLP Encoded header.
        bytes headerRlp;
        // RLP Encoded proof.
        bytes userProofRlp;
        // RLP Encoded blacklisted addresses proof.
        bytes[] blackListedProofsRlp;
    }

        */

        //console.logBytes(abi.encode(platform.claimable(0, _proofData)));
        // Claim
        platform.claim(0, _proofData);

        // Check user balance of MockToken
        console.log(mockToken.balanceOf(_user));
    }
}
