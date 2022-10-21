// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256,uint256_mul,uint256_add
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp, get_block_number
from starkware.cairo.common.math import assert_nn, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_nn
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.cairo_keccak.keccak import (
    finalize_keccak,
    keccak_add_uint256,
    keccak_as_words,
)

from openzeppelin.token.erc721.library import ERC721
from openzeppelin.introspection.erc165.library import ERC165
from openzeppelin.access.ownable.library import Ownable

from dwutils.array import arr_concat
from dwutils.merkle import merkle_verify

from dwutils.Str import (
    literal_from_number,
    literal_concat_known_length_dangerous
)

//
// storage_var
//
@storage_var
func base_token_uri_len() -> (res : felt){
}

@storage_var
func base_token_uri(index : felt) -> (res : felt){
}

@storage_var
func token_lucky(token_id: Uint256) -> (lucky: Uint256){
}

@storage_var
func token_earn_tm(token_id: Uint256) -> (tm: felt){
}
// The time interval between two touches
const EARN_INTERVAL = 300;

//token growth counter
@storage_var
func token_counter() -> (counter: Uint256) {
}

@storage_var
func chip_token(chip_address: felt) -> (token_id_low: felt) {
}

@storage_var
func token_chip(token_id: Uint256) -> (chip_address: felt) {
}

@storage_var
func merkle_root() -> (root: felt) {
}

//Because storage cannot be deleted, set an abandoned token placeholder
const abandoned_id = 999999999999999999999;

@constructor
func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(owner: felt) {
    ERC721.initializer('DwGame', 'DG');
    Ownable.initializer(owner);
    return ();
}

//
// Getters
//

@view
func supportsInterface{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(interfaceId: felt) -> (success: felt) {
    return ERC165.supports_interface(interfaceId);
}

@view
func name{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}() -> (name: felt) {
    return ERC721.name();
}

@view
func symbol{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}() -> (symbol: felt) {
    return ERC721.symbol();
}

@view
func balanceOf{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(owner: felt) -> (balance: Uint256) {
    return ERC721.balance_of(owner);
}

@view
func ownerOf{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(token_id: Uint256) -> (owner: felt) {
    return ERC721.owner_of(token_id);
}

@view
func getApproved{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(token_id: Uint256) -> (approved: felt) {
    return ERC721.get_approved(token_id);
}

@view
func isApprovedForAll{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(owner: felt, operator: felt) -> (isApproved: felt) {
    let (isApproved) = ERC721.is_approved_for_all(owner, operator);
    return (isApproved=isApproved);
}

@view
func owner{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}() -> (owner: felt){
    let (owner) = Ownable.owner();
    return (owner=owner);
}

@view
func getLucky{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(token_id: Uint256) -> (lucky: Uint256){
    let (lucky) = token_lucky.read(token_id);
    return (lucky=lucky);
}

//support long url
@view
func tokenURI{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(token_id: Uint256) -> (token_uri_len : felt, token_uri : felt*){
    return getTokenUri(token_id);
}

func getTokenUri{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(token_id: Uint256) -> (token_uri_len : felt, token_uri : felt*){
    alloc_locals;

    // ensure token with token_id exists
    let exists = ERC721._exists(token_id);
    with_attr error_message("ERC721_Token_Metadata: URI query for nonexistent token"){
        assert exists = TRUE;
    }

    let (local ret_base_token_uri) = alloc();
    let (local ret_base_token_uri_len) = base_token_uri_len.read();
    if (ret_base_token_uri_len != 0) {
        let (token_uri_detail) = ERC721.token_uri(token_id);

        if (token_uri_detail != 0) {
            // We use the baseURI set by the owner, returning concat(baseURI,token_id);
            _base_token_uri(0, ret_base_token_uri_len, ret_base_token_uri);
            let (local res_token_uri) = alloc();
            res_token_uri[0] = token_uri_detail;
            let (ret_token_uri_len, ret_token_uri) = arr_concat(
                ret_base_token_uri_len, ret_base_token_uri, 1, res_token_uri
            );
            return (ret_token_uri_len, ret_token_uri);
        }
    }

    // If both base_token_uri and token_uri are undefined, return empty array
    return (token_uri_len=0, token_uri=ret_base_token_uri);
}

@view 
func baseTokenURI{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}() -> (token_uri_len : felt, token_uri : felt*){
    alloc_locals;

    let (local ret_base_token_uri) = alloc();
    let (local ret_base_token_uri_len) = base_token_uri_len.read();
    _base_token_uri(0, ret_base_token_uri_len, ret_base_token_uri);
    return (ret_base_token_uri_len, ret_base_token_uri);
}

func _base_token_uri{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
}(idx: felt, ret_base_token_uri_len : felt, ret_base_token_uri : felt*){
    if (idx == ret_base_token_uri_len) {
      return ();
    }

    let (base) = base_token_uri.read(idx);
    assert ret_base_token_uri[idx] = base;
    _base_token_uri(idx=idx+1, ret_base_token_uri_len=ret_base_token_uri_len, ret_base_token_uri=ret_base_token_uri);
    return ();
}

@view
func getLastEarnTime{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(token_id: Uint256) -> (tm: felt){
    let tm = token_earn_tm.read(token_id);
    return (tm);
}

//
// Externals
//

@external
func approve{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(to: felt, token_id: Uint256) {
    ERC721.approve(to, token_id);
    return ();
}

@external
func setApprovalForAll{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(operator: felt, approved: felt) {
    ERC721.set_approval_for_all(operator, approved);
    return ();
}

@external
func transferFrom{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(from_: felt, to: felt, token_id: Uint256) {
    ERC721.transfer_from(from_, to, token_id);
    return ();
}

@external
func safeTransferFrom{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(from_: felt, to: felt, token_id: Uint256, data_len: felt, data: felt*) {
    ERC721.safe_transfer_from(from_, to, token_id, data_len, data);
    return ();
}

@external
func transferOwnership{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(newOwner: felt) {
    Ownable.transfer_ownership(newOwner);
    return ();
}

@external
func renounceOwnership{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}() {
    Ownable.renounce_ownership();
    return ();
}

@external
func setMerkleRoot{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
}(m_root: felt) {
    Ownable.assert_only_owner();
    merkle_root.write(m_root);
    return ();
}

@external
func setBaseTokenUri{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
}(s_base_token_uri_len : felt, s_base_token_uri : felt*){
    let (caller) = get_caller_address();
    let (owner) = Ownable.owner();
    with_attr error_message("Caller doesn't own the asset"){
      assert caller = owner;
    }

    _set_base_token_uri(s_base_token_uri_len=s_base_token_uri_len, s_base_token_uri=s_base_token_uri, idx=0);
    base_token_uri_len.write(s_base_token_uri_len);
    return ();
}

func _set_base_token_uri{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
}(s_base_token_uri_len : felt, s_base_token_uri : felt*, idx: felt){
    if (s_base_token_uri_len == idx) {
        return ();
    }

    base_token_uri.write(idx, s_base_token_uri[idx]);
    return _set_base_token_uri(s_base_token_uri_len=s_base_token_uri_len, s_base_token_uri=s_base_token_uri, idx=idx+1);
}

@external
func unBlindChip{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(token_id: Uint256) {
    alloc_locals;
    let (local chip_address: felt) = token_chip.read(token_id);

    token_chip.write(token_id, '');
    chip_token.write(chip_address, abandoned_id);
    return ();
}

@external
func reBlindChip{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(chip_address: felt, proof_len: felt, proof: felt*, token_id: Uint256) {
    alloc_locals;

    let (amount_hash) = hash2{hash_ptr=pedersen_ptr}(1, 0);
    let (leaf) = hash2{hash_ptr=pedersen_ptr}(chip_address, amount_hash);
    let (root) = merkle_root.read();
    let (proof_valid) = merkle_verify(leaf, root, proof_len, proof);
    with_attr error_message("Proof not valid") {
        assert proof_valid = 1;
    }

    let (caller) = get_caller_address();
    let (local token_owner: felt) = ownerOf(token_id=token_id);
    with_attr error_message("Caller doesn't own the asset"){
        assert caller = token_owner;
    }

    let (old_chip_address) = token_chip.read(token_id);

    token_chip.write(token_id, chip_address);
    chip_token.write(chip_address, token_id.low);
    //unblind old
    chip_token.write(old_chip_address, abandoned_id);
    return ();
}

//
// Calling Another Contract 
//

@contract_interface
namespace IMyTokenContract{
    func touchToEarn(user: felt, amount : Uint256){
    }
    func burnToUpgrade(user : felt, amount : Uint256){
    }
}

const XOROSHIRO_ADDR = 0x052661d79186acaf916da3404d883e2ba8b899ddb2190c77419b262865e68896;

@contract_interface
namespace IXoroshiro{
    func next(seed : felt) -> (rnd : felt){
    }
}

func _is_abandoned_chip{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
}(token_id_low: felt) -> felt {
    if (token_id_low == abandoned_id) {
        return TRUE;
    }

    return FALSE;
}

@external
func touchToEarn{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
}(contract_20_address: felt, chip_address: felt, proof_len: felt, proof: felt*){ 
    alloc_locals;

    let (amount_hash) = hash2{hash_ptr=pedersen_ptr}(1, 0);
    let (leaf) = hash2{hash_ptr=pedersen_ptr}(chip_address, amount_hash);
    let (root) = merkle_root.read();
    let (proof_valid) = merkle_verify(leaf, root, proof_len, proof);
    with_attr error_message("Proof not valid") {
        assert proof_valid = 1;
    }

    let (token_id_low) = chip_token.read(chip_address);

    let (caller) = get_caller_address();

    let (now_tm) = get_block_timestamp();
    // is exist chip
    if (token_id_low == 0) {
        // token id must stark from 1, because read cannot check not exist or zero
        let (current_counter) = token_counter.read();
        let (next_token_id, _) = uint256_add(current_counter, Uint256(1, 0));
        let _isabandonedChip = _is_abandoned_chip(next_token_id.low);
        if (_isabandonedChip == TRUE) {
            let (next_id, _) = uint256_add(next_token_id, Uint256(1, 0));
            token_counter.write(next_id);
        } else {
            token_counter.write(next_token_id);
        }
        let (token_id) = token_counter.read();

        let _data_len : felt = 0;
        let (local _data : felt*) = alloc();
        ERC721._safe_mint(caller, token_id, _data_len, _data);

        token_chip.write(token_id, chip_address);
        chip_token.write(chip_address, token_id.low);
        token_lucky.write(token_id, Uint256(1, 0));

        let _token_uri: felt = token_uri_by_lucky(token_id);
        ERC721._set_token_uri(token_id, _token_uri);

        do_each(token_id, contract_20_address, caller, now_tm);
        return ();
    } else {
        let (token_id_low) = chip_token.read(chip_address);
        let _isabandonedChip = _is_abandoned_chip(token_id_low);
        with_attr error_message("This Chip is abandoned"){
            assert _isabandonedChip = FALSE;
        }
        let token_id = Uint256(token_id_low, 0);

        let (local token_owner: felt) = ownerOf(token_id=token_id);
        with_attr error_message("Caller doesn't own the asset"){
            assert caller = token_owner;
        }
        let (last_tm) = token_earn_tm.read(token_id);
        tempvar diff = now_tm - last_tm;

        with_attr error_message("please wait for some time"){
            assert_nn(diff - EARN_INTERVAL);
        }

        do_each(token_id, contract_20_address, caller, now_tm);
        return ();
    }
}

func do_each{
        syscall_ptr : felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
}(token_id: Uint256, contract_20_address: felt, caller: felt, now_tm: felt) {
    let lucky: Uint256 = token_lucky.read(token_id);
    let amount: Uint256 = earn_amount_by_lucky(lucky);
    IMyTokenContract.touchToEarn(
        contract_address=contract_20_address, user=caller, amount=amount
    );

    token_earn_tm.write(token_id, now_tm);
    return ();
}

func earn_amount_by_lucky{
        syscall_ptr : felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
}(lucky: Uint256) -> (amount: Uint256){
    let rnd: felt = get_next_rnd();
    let r = Uint256(rnd * 100, 0);
    let (tmp, _) = uint256_mul(lucky, r);
    let w = Uint256(1000000000000000000, 0);
    let (amount, _) = uint256_mul(tmp, w);
    return (amount=amount);
}

func get_next_rnd{
        syscall_ptr : felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}() -> (rnd : felt){
    let (caller) = get_caller_address();
    let (tm) = get_block_timestamp();
    let (bn) = get_block_number();
    let (rnd) = IXoroshiro.next(contract_address=XOROSHIRO_ADDR, seed=caller + tm + bn);
    let (result, remainder) = unsigned_div_rem(rnd, 6);
    return (rnd=remainder);
}

@external
func burnToUpgrade{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
}(contract_20_address: felt, token_id: Uint256) {
    alloc_locals;
    let (caller) = get_caller_address();

    let (local token_owner: felt) = ownerOf(token_id=token_id);
    with_attr error_message("Caller doesn't own the asset") {
        assert caller = token_owner;
    }

    let lucky: Uint256 = getLucky(token_id=token_id);
    let amount: Uint256 = burn_amount_by_lucky(lucky);

    IMyTokenContract.burnToUpgrade(
        contract_address=contract_20_address, user=caller, amount=amount
    );

    let (new_lucky, _) = uint256_add(lucky, Uint256(1, 0));
    token_lucky.write(token_id, new_lucky);
    let new_token_uri: felt = token_uri_by_lucky(token_id);
    ERC721._set_token_uri(token_id, new_token_uri);

    return ();
}

func burn_amount_by_lucky{
    syscall_ptr : felt*,
    range_check_ptr,
}(lucky: Uint256) -> (amount: Uint256) {
    let r = Uint256(10, 0);
    let (tmp, _) = uint256_mul(lucky, r);
    let w = Uint256(1000000000000000000, 0);
    let (amount, _) = uint256_mul(tmp, w);
    return (amount=amount);
}

func token_uri_by_lucky{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
}(token_id: Uint256) -> (token_uri:felt) {
    alloc_locals;

    let (local token_id_len: felt) = get_num_length(token_id.low, 1, 10);
    let (local s_token_id: felt) = literal_from_number(token_id.low);
    let lucky: Uint256 = getLucky(token_id);
    if (lucky.low == 1) {
        let (local step1: felt) = literal_concat_known_length_dangerous(s_token_id, '.json', token_id_len + 5);
        return (token_uri=step1);
    } else {
        let (local lucky_length: felt) = get_num_length(lucky.low, 1, 10);

        let (local step1: felt) = literal_concat_known_length_dangerous(s_token_id, '-', token_id_len + 1);
        let (local s_lucky: felt) = literal_from_number(lucky.low);
        tempvar len_2 = token_id_len + lucky_length;
        let (local step2: felt) = literal_concat_known_length_dangerous(step1, s_lucky, len_2 + 1);
        let (local step3: felt) = literal_concat_known_length_dangerous(step2, '.json', len_2 + 6);

        return (token_uri=step3);
    }
}

func get_num_length{
        range_check_ptr
}(num: felt, idx: felt, m: felt)->(len: felt) {
    alloc_locals;

    let n: felt = num + 1;
    local r: felt = is_nn(m - n);
    if (r == 1) {
        return (len=idx);
    }

    return get_num_length(num, idx + 1, m * 10);
}
