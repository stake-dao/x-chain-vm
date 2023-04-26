import sys, rlp

from web3 import Web3
from eth_abi import encode
from hexbytes import HexBytes

args = sys.argv[1:]
# Initialize a Web3.py instance
RPC_URL = "https://mainnet.infura.io/v3/b5dc2199e2254c10b4bd4a39b78a7e89" if args[0] == "mainnet" else "http://localhost:8545"

web3 = Web3(Web3.HTTPProvider(RPC_URL))

BLOCK_HEADER = (
    "parentHash",
    "sha3Uncles",
    "miner",
    "stateRoot",
    "transactionsRoot",
    "receiptsRoot",
    "logsBloom",
    "difficulty",
    "number",
    "gasLimit",
    "gasUsed",
    "timestamp",
    "extraData",
    "mixHash",
    "nonce",
    "baseFeePerGas",
    "withdrawalsRoot"
)


def generate_proofs(account, proof, block_number):
    block = web3.eth.get_block(int(block_number))

    # Encode RLP block
    rlp_block = encode_rlp_block(block)

    # Encode RLP proofs
    rlp_proof = encode_rlp_proofs(
        web3.eth.get_proof(account, proof, block_identifier=int(block_number))
    )

    data = encode(
        ["bytes32", "bytes", "bytes"],
        [block["hash"], rlp_block, rlp_proof],
    ).hex()

    print("0x" + data)


def encode_rlp_block(block):
    block_header = [
        HexBytes("0x")
        if isinstance((block[k]), int) and block[k] == 0
        else HexBytes(block[k])
        for k in BLOCK_HEADER
        if k in block
    ]
    return rlp.encode(block_header)


def encode_rlp_proofs(proofs):
    account_proof = list(map(rlp.decode, map(HexBytes, proofs["accountProof"])))
    storage_proofs = [
        list(map(rlp.decode, map(HexBytes, proof["proof"])))
        for proof in proofs["storageProof"]
    ]
    return rlp.encode([account_proof, *storage_proofs])


def main():
    account = args[1]
    keys = [int(x) for x in args[2:8]]
    block_number = args[8]

    return generate_proofs(account, keys, block_number)


__name__ == "__main__" and main()
