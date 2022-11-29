from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_blake2s.blake2s import blake2s_add_uint256_bigend, blake2s_bigend
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.math import assert_nn, assert_nn_le, unsigned_div_rem
from starkware.cairo.common.pow import pow
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.stark_verifier.core.channel import (
    Channel,
    ChannelSentFelt,
    ChannelUnsentFelt,
    read_truncated_hash_from_prover,
)

// Commitment values for a vector commitment. Used to generate a commitment by "reading" these
// values from the channel.
struct VectorUnsentCommitment {
    commitment_hash: ChannelUnsentFelt,
}

// Commitment for a vector of field elements.
struct VectorCommitment {
    config: VectorCommitmentConfig*,
    commitment_hash: ChannelSentFelt,
}

struct VectorCommitmentConfig {
    height: felt,
}

// Witness for a decommitment over queries.
struct VectorCommitmentWitness {
    // The authentication values: all the siblings of the subtree generated by the queried indices,
    // bottom layer up, left to right.
    n_authentications: felt,
    authentications: Uint256*,
}

// A query to the vector commitment.
struct VectorQuery {
    index: felt,
    value: Uint256,
}

func vector_commit{
    blake2s_ptr: felt*, bitwise_ptr: BitwiseBuiltin*, channel: Channel, range_check_ptr
}(unsent_commitment: VectorUnsentCommitment, config: VectorCommitmentConfig*) -> (
    res: VectorCommitment*
) {
    let (commitment_hash_value) = read_truncated_hash_from_prover(
        value=unsent_commitment.commitment_hash
    );
    return (res=new VectorCommitment(config=config, commitment_hash=commitment_hash_value));
}

// Decommits a VectorCommitment at multiple indices.
// Indices must be sorted and unique.
func vector_commitment_decommit{range_check_ptr, blake2s_ptr: felt*, bitwise_ptr: BitwiseBuiltin*}(
    commitment: VectorCommitment*,
    n_queries: felt,
    queries: VectorQuery*,
    witness: VectorCommitmentWitness*,
) {
    alloc_locals;

    // Shift query indices.
    let (shift) = pow(2, commitment.config.height);
    let (shifted_queries: VectorQuery*) = alloc();
    shift_queries(
        n_queries=n_queries, queries=queries, shifted_queries=shifted_queries, shift=shift
    );

    let authentications = witness.authentications;
    let (expected_commitment) = verify_authentications{authentications=authentications}(
        queue_head=shifted_queries, queue_tail=&shifted_queries[n_queries]
    );
    assert authentications = &witness.authentications[witness.n_authentications];

    // Make sure hash is truncated.
    assert_nn(expected_commitment.low / 2 ** 96);
    tempvar expected_truncated_hash = (
        expected_commitment.low + expected_commitment.high * 2 ** 128
    ) / 2 ** 96;
    assert expected_truncated_hash = commitment.commitment_hash.value;
    return ();
}

// Shifts the query indices by 2**height, to convert index representation to heap-like.
// Validates the query index range.
func shift_queries{range_check_ptr}(
    n_queries: felt, queries: VectorQuery*, shifted_queries: VectorQuery*, shift: felt
) {
    if (n_queries == 0) {
        return ();
    }
    assert_nn_le(queries.index, shift - 1);
    assert [shifted_queries] = VectorQuery(
        index=queries.index + shift,
        value=queries.value);
    return shift_queries(
        n_queries=n_queries - 1,
        queries=&queries[1],
        shifted_queries=&shifted_queries[1],
        shift=shift,
    );
}

// Verifies a queue of merkle queries. [queue_head, queue_tail) is a queue, where each element
// represents a node index (given in a heap-like indexing) and value (either an inner
// node or a leaf).
func verify_authentications{
    range_check_ptr, blake2s_ptr: felt*, bitwise_ptr: BitwiseBuiltin*, authentications: Uint256*
}(queue_head: VectorQuery*, queue_tail: VectorQuery*) -> (hash: Uint256) {
    alloc_locals;

    let current: VectorQuery = queue_head[0];
    let next: VectorQuery* = &queue_head[1];

    // Check if we're at the root.
    if (current.index == 1) {
        // Make sure the queue is empty.
        assert next = queue_tail;
        return (hash=current.value);
    }

    // Extract parent.
    local bit;
    %{ ids.bit = ids.current.index & 1 %}
    assert bit = bit * bit;
    local parent = (current.index - bit) / 2;
    assert [range_check_ptr] = parent;
    let range_check_ptr = range_check_ptr + 1;

    // Write parent to queue.
    assert queue_tail.index = parent;
    if (bit == 0) {
        if (next != queue_tail and current.index + 1 == next.index) {
            // next holds the sibling.
            let (hash) = truncated_blake2s(current.value, next.value);
            assert queue_tail.value = hash;
            return verify_authentications(queue_head=&queue_head[2], queue_tail=&queue_tail[1]);
        }
        let (hash) = truncated_blake2s(current.value, authentications[0]);
    } else {
        let (hash) = truncated_blake2s(authentications[0], current.value);
    }

    assert queue_tail.value = hash;
    let authentications = &authentications[1];
    return verify_authentications(queue_head=&queue_head[1], queue_tail=&queue_tail[1]);
}

// A 160 MSB truncated version of blake2s.
// hash:
//   blake2s(x, y) & ~((1<<96) - 1).
func truncated_blake2s{range_check_ptr, blake2s_ptr: felt*, bitwise_ptr: BitwiseBuiltin*}(
    x: Uint256, y: Uint256
) -> (res: Uint256) {
    let (data: felt*) = alloc();
    let data_start = data;
    blake2s_add_uint256_bigend{data=data}(x);
    blake2s_add_uint256_bigend{data=data}(y);
    let (hash) = blake2s_bigend(data=data_start, n_bytes=64);
    let (low_h, low_l) = unsigned_div_rem(hash.low, 2 ** 96);
    return (res=Uint256(low=low_h * 2 ** 96, high=hash.high));
}
