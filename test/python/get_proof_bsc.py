import os, sys, rlp, subprocess

from eth_abi import encode
from hexbytes import HexBytes
from dotenv import load_dotenv
from proofs import usersProof

load_dotenv()

args = sys.argv[1:]

def generate_proofs(rpc_url, block_number, user):
    proofs = usersProof[user]

    rlp_proof = encode_rlp_proofs(proofs)

    toji_output = run_toji(rpc_url, block_number)

    parsed_data = parse_toji_output(toji_output)

    rlp_encoded_block = parsed_data["RLP Encoded Block Header"]
    rlp_encoded_block = bytes.fromhex(rlp_encoded_block)

    data = encode(
        ["bytes32", "bytes", "bytes"],
        [proofs["blockHash"], rlp_encoded_block, rlp_proof],
    ).hex()

    print("0x" + data)

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

def main():
    rpc_url = args[0]
    block_number = args[1]
    user = args[2]

    return generate_proofs(rpc_url, block_number, user)


__name__ == "__main__" and main()

