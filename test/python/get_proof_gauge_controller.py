import os, sys, rlp, subprocess

from web3 import Web3
from eth_abi import encode
from hexbytes import HexBytes
from dotenv import load_dotenv
from eth_utils import keccak

load_dotenv()

args = sys.argv[1:]
# Initialize a Web3.py instance
RPC_URL = (
    "https://mainnet.infura.io/v3/" + os.getenv("INFURA_KEY")
    if args[0] == "mainnet"
    else "http://localhost:8545"
)

web3 = Web3(Web3.HTTPProvider(RPC_URL))

GAUGES_SLOTS = {
    "0xc128468b7ce63ea702c1f104d55a2566b13d3abd": {
        "last_user_vote": 1000000007,
        "point_weights": 1000000008,
        "vote_user_slope": 1000000005,
        "type": "new",
    },
    "0x3669c421b77340b2979d1a00a792cc2ee0fce737": {
        "last_user_vote": 1000000010,
        "point_weights": 10000000013,
        "vote_user_slope": 1000000008,
        "type": "new",
    },
}


def generate_proofs(gc, user, gauge, block_number, timestamp):
    block = web3.eth.get_block(int(block_number))

    gc = gc.lower()

    # Get positions of gc
    last_user_vote_base_slot = GAUGES_SLOTS[gc]["last_user_vote"]
    point_weights_base_slot = GAUGES_SLOTS[gc]["point_weights"]
    vote_user_slope_base_slot = GAUGES_SLOTS[gc]["vote_user_slope"]

    timestamp = int(timestamp)

    # Positions array : [lastUserVotes; pointWeights.bias; pointsWeigths.slope; voteUserSlope.slope; voteUserSlope.power; voteUserSlope.end]
    # 61631521168299689871618715479280866927801819302010895179907038285020035817513
    # 43191216227952913941400108316074680035164138003980457889292844412181225935807
    # 43191216227952913941400108316074680035164138003980457889292844412181225935808
    # 17969391893915224584872991688491589142280908254174880360086302791287691034494
    # 17969391893915224584872991688491589142280908254174880360086302791287691034495
    # 17969391893915224584872991688491589142280908254174880360086302791287691034496

    if GAUGES_SLOTS[gc]["type"] == "new":
        last_user_vote_position = get_position_from_user_gauge(
            user, gauge, last_user_vote_base_slot
        )
        point_weights_position = get_position_from_gauge_time(
            gauge, timestamp, point_weights_base_slot
        )
        vote_user_slope_position = get_position_from_user_gauge(
            user, gauge, vote_user_slope_base_slot
        )

    vote_user_slope_slope = vote_user_slope_position
    vote_user_slope_power = vote_user_slope_position + 1
    vote_user_slope_end = vote_user_slope_position + 2

    points_weights_bias = point_weights_position
    points_weights_slope = point_weights_position + 1

    positions = [last_user_vote_position, points_weights_bias, points_weights_slope, vote_user_slope_slope, vote_user_slope_power, vote_user_slope_end]

    # Encode RLP proofs
    rlp_proof = encode_rlp_proofs(
        web3.eth.get_proof(web3.to_checksum_address(gc), positions, block_identifier=int(block_number))
    )

    toji_output = run_toji("https://eth.llamarpc.com", block_number)

    parsed_data = parse_toji_output(toji_output)

    rlp_encoded_block = parsed_data["RLP Encoded Block Header"]
    rlp_encoded_block = bytes.fromhex(rlp_encoded_block)

    data = encode(
        ["bytes32", "bytes", "bytes"],
        [block["hash"], rlp_encoded_block, rlp_proof],
    ).hex()

    print("0x" + data)


def parse_toji_output(data):
    # Initialize an empty dictionary to hold the parsed data
    parsed_data = {}

    # Split the data into lines and iterate over each line
    lines = data.split("\n")
    for line in lines:
        # Check if line is not empty
        if line.strip() != "":
            # Split the line by the first occurrence of ":", which separates the key and value
            parts = line.split(":", 1)
            if len(parts) == 2:  # Ensure there are two parts
                key = parts[0].strip()  # Strip whitespace from the key
                value = (
                    parts[1].strip().replace('"', "")
                )  # Strip whitespace from the value and remove "
                parsed_data[key] = value

    return parsed_data


def encode_rlp_proofs(proofs):
    account_proof = list(map(rlp.decode, map(HexBytes, proofs["accountProof"])))
    storage_proofs = [
        list(map(rlp.decode, map(HexBytes, proof["proof"])))
        for proof in proofs["storageProof"]
    ]
    return rlp.encode([account_proof, *storage_proofs])


def run_toji(url, block_number):
    # Construct the command as a list of arguments
    command = ["toji", "-r", url, "-n", str(block_number)]

    # Run the command
    result = subprocess.run(command, capture_output=True, text=True)

    # Check if the command was successful
    if result.returncode == 0:
        # Command was successful, process result.stdout
        return result.stdout
    else:
        # There was an error
        return result.stderr


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


def main():
    gc = args[1]
    user = args[2]
    gauge = args[3]
    block_number = args[4]
    timestamp = args[5]

    return generate_proofs(gc, user, gauge, block_number, timestamp)


__name__ == "__main__" and main()
