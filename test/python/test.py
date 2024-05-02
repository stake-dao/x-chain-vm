# test_block_encoding.py

import time
import math
import json
from typing import Union, List
from urllib import request
from hexbytes.main import HexBytes
from rlp import Serializable, encode
from web3.types import BlockData
from rlp.sedes import (
    BigEndianInt,
    big_endian_int,
    Binary,
    binary,
)
from web3 import Web3



# Define the block header classes
address = Binary.fixed_length(20, allow_empty=True)
hash32 = Binary.fixed_length(32)
int256 = BigEndianInt(256)
trie_root = Binary.fixed_length(32, allow_empty=True)

class BlockHeader(Serializable):
    fields = (
        ('parentHash', hash32),
        ('unclesHash', hash32),
        ('coinbase', address),
        ('stateRoot', trie_root),
        ('transactionsRoot', trie_root),
        ('receiptsRoot', trie_root),
        ('logsBloom', int256),
        ('difficulty', big_endian_int),
        ('number', big_endian_int),
        ('gasLimit', big_endian_int),
        ('gasUsed', big_endian_int),
        ('timestamp', big_endian_int),
        ('extraData', binary),
        ('mixHash', binary),
        ('nonce', Binary(8, allow_empty=True)),
    )

    def hash(self) -> HexBytes:
        _rlp = encode(self)
        return Web3.keccak(_rlp)
    
    def raw_rlp(self) -> bytes:
        return encode(self)

class BlockHeaderEIP1559(BlockHeader):
    fields = BlockHeader.fields + (('baseFeePerGas', big_endian_int),)

class BlockHeaderShangai(BlockHeaderEIP1559):
    fields = BlockHeaderEIP1559.fields + (('withdrawalsRoot', trie_root),)

# Function to build block headers from block data
def build_block_header(block: BlockData) -> Union[BlockHeader, BlockHeaderEIP1559, BlockHeaderShangai]:
    if 'withdrawalsRoot' in block:
        return BlockHeaderShangai(**block)
    elif 'baseFeePerGas' in block:
        return BlockHeaderEIP1559(**block)
    else:
        return BlockHeader(**block)


def rpc_request(url, rpc_request):
    headers = {"Content-Type": "application/json"}
    response = request.post(url=url, headers=headers, data=json.dumps(rpc_request))
    # print(f"Status code: {response.status_code}")
    # print(f"Response content: {response.content}")
    return response.json()


# Function to fetch blocks from an RPC endpoint
def fetch_blocks_from_rpc_no_async(range_from: int, range_till: int, rpc_url: str, delay=0.1) -> List[Union[BlockHeader, BlockHeaderEIP1559, BlockHeaderShangai]]:
    assert range_from < range_till, "Invalid range"
    number_of_blocks = range_till - range_from
    rpc_batches_amount = math.ceil(number_of_blocks / 1450)
    last_batch_size = number_of_blocks % 1450

    all_results = []

    for i in range(rpc_batches_amount):
        current_batch_size = last_batch_size if (i == rpc_batches_amount - 1 and last_batch_size) else 1450
        requests = [
            {
                "jsonrpc": "2.0",
                "method": "eth_getBlockByNumber",
                "params": [hex(range_from + j), False],
                "id": str(j),
            }
            for j in range(current_batch_size)
        ]
        results = rpc_request(rpc_url, requests)
        for result in results:
            block_header = build_block_header(result["result"])
            all_results.append(block_header)
        time.sleep(delay)
    return all_results

# Test function
def test_block_encoding():
    rpc_url = "https://mainnet.infura.io/v3/b5dc2199e2254c10b4bd4a39b78a7e89"
    block_number_start = 19710129
    block_number_end = 19710129

    blocks = fetch_blocks_from_rpc_no_async(block_number_start, block_number_end, rpc_url)

    print("Fetched", len(blocks), "blocks")

    print(blocks)

    for block in blocks:
        print("Block Number:", block.number)
        print("RLP Encoded Data:", block.raw_rlp().hex())
        print("Block Hash:", block.hash().hex())
        print()

if __name__ == "__main__":
    test_block_encoding()