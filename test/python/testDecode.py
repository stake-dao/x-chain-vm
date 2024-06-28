import os, sys, rlp, subprocess
from web3 import Web3
from eth_abi import encode
from hexbytes import HexBytes
from eth_utils import keccak, to_bytes
from dotenv import load_dotenv

load_dotenv()

# Initialize a Web3.py instance
RPC_URL = "https://mainnet.infura.io/v3/" + os.getenv("INFURA_KEY")
web3 = Web3(Web3.HTTPProvider(RPC_URL))


def generate_proofs():
    block = web3.eth.get_block(20179427)
    timestamp = 1719446400
    # gauge_controller = "0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB"  # Curve
    # user = "0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6"
    # gauge = "0x16A3a047fC1D388d5846a73ACDb475b11228c299"

    # Positions array : [lastUserVotes; pointWeights.bias; pointsWeigths.slope; voteUserSlope.slope; voteUserSlope.power; voteUserSlope.end]
    # 61631521168299689871618715479280866927801819302010895179907038285020035817513
    # 43191216227952913941400108316074680035164138003980457889292844412181225935807
    # 43191216227952913941400108316074680035164138003980457889292844412181225935808
    # 17969391893915224584872991688491589142280908254174880360086302791287691034494
    # 17969391893915224584872991688491589142280908254174880360086302791287691034495
    # 17969391893915224584872991688491589142280908254174880360086302791287691034496
    
    gauge_controller = "0xC128468b7Ce63eA702C1f104D55A2566b13D3ABD"  # Balancer
    user = "0x04e8e5aA372D8e2233D2EF26079e23E3309003D5"
    gauge = "0x2D02Bf5EA195dc09854E18E7d2857A16bF376963"

    # Test multiple base slots (from 0 to 100)
    last_user_vote_base_slot = 1000000007 # user -> gauge
    point_weights_base_slot = 1000000008 # user -> time
    vote_user_slope_base_slot = 1000000005 # user -> gauge

    last_user_vote_position = get_position_from_user_gauge(user, gauge, last_user_vote_base_slot)
    point_weights_position = get_position_from_gauge_time(gauge, timestamp, point_weights_base_slot)
    vote_user_slope_position = get_position_from_user_gauge(user, gauge, vote_user_slope_base_slot)

    vote_user_slope_slope = vote_user_slope_position
    vote_user_slope_power = vote_user_slope_position + 1
    vote_user_slope_end = vote_user_slope_position + 2

    points_weights_bias = point_weights_position
    points_weights_slope = point_weights_position + 1

    print(last_user_vote_position)
    print(points_weights_bias)
    print(points_weights_slope)
    print(vote_user_slope_slope)
    print(vote_user_slope_power)
    print(vote_user_slope_end)


    # Calculate the storage slot for the admin addres
    #proof = web3.eth.get_proof(gauge_controller, [position], block.number)

    #print(int.from_bytes(proof.storageProof[0].value, byteorder="big"))

    """
    # Encode the proof
    encoded_proof = encode_rlp_proofs(proof)
    #print("Encoded Proof:", encoded_proof.hex())

    # Decode and verify the proof
    #verify_proof(encoded_proof, [0], admin)
    """


def get_position_from_user_gauge(user, gauge, base_slot):
    # Encode the user address with the base slot and hash
    user_encoded = keccak(encode(["uint256", "address"], [base_slot, user]))

    # Encode the result with the gauge address and hash
    final_slot = keccak(encode(["bytes32", "address"], [user_encoded, gauge]))

    # Convert the final hash to an integer slot number
    return int.from_bytes(final_slot, byteorder="big")

def get_position_from_gauge_time(gauge, time, base_slot):
    # Encode the user address with the base slot and hash
    gauge_encoded = keccak(encode(["uint256", "address"], [base_slot, gauge]))

    # Encode the result with the user address and time
    final_slot = keccak(encode(["bytes32", "uint256"], [gauge_encoded, time]))

    # Convert the final hash to an integer slot number
    return int.from_bytes(final_slot, byteorder="big")

def encode_rlp_proofs(proofs):
    account_proof = list(map(rlp.decode, map(HexBytes, proofs["accountProof"])))
    storage_proofs = [
        list(map(rlp.decode, map(HexBytes, proof["proof"])))
        for proof in proofs["storageProof"]
    ]
    return rlp.encode([account_proof, *storage_proofs])


def verify_proof(encoded_proof, storage_key, expected_address):
    decoded_proof = rlp.decode(encoded_proof)


def main():
    return generate_proofs()


__name__ == "__main__" and main()
