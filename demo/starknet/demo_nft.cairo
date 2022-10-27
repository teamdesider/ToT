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
func token_lucky(tokenId: Uint256) -> (lucky: Uint256){
}

@storage_var
func token_earn_tm(tokenId: Uint256) -> (tm: felt){
}
// The time interval between two touches
const EARN_INTERVAL = 300;

//token growth counter
@storage_var
func token_counter() -> (counter: Uint256) {
}

@storage_var
func chip_token(chip_address: felt) -> (tokenId_low: felt) {
}

@storage_var
func token_chip(tokenId: Uint256) -> (chip_address: felt) {
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
}(tokenId: Uint256) -> (owner: felt) {
    return ERC721.owner_of(tokenId);
}

@view
func getApproved{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(tokenId: Uint256) -> (approved: felt) {
    return ERC721.get_approved(tokenId);
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
}(tokenId: Uint256) -> (lucky: Uint256){
    let (lucky) = token_lucky.read(tokenId);
    return (lucky=lucky);
}

//support long url
@view
func tokenURI{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(tokenId: Uint256) -> (tokenURI_len : felt, tokenURI : felt*){
    return getTokenUri(tokenId);
}

func getTokenUri{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(tokenId: Uint256) -> (tokenURI_len : felt, tokenURI : felt*){
    alloc_locals;

    // ensure token with tokenId exists
    let exists = ERC721._exists(tokenId);
    with_attr error_message("ERC721_Token_Metadata: URI query for nonexistent token"){
        assert exists = TRUE;
    }

    let (local ret_base_token_uri) = alloc();
    let (local ret_base_token_uri_len) = base_token_uri_len.read();
    if (ret_base_token_uri_len != 0) {
        let (token_uri_detail) = ERC721.token_uri(tokenId);

        _base_token_uri(0, ret_base_token_uri_len, ret_base_token_uri);
        let (local res_token_uri) = alloc();
        if (token_uri_detail != 0) {
            // We use the baseURI set by the owner, returning concat(baseURI,tokenId);
            res_token_uri[0] = token_uri_detail;
            let (ret_token_uri_len, ret_token_uri) = arr_concat(
                ret_base_token_uri_len, ret_base_token_uri, 1, res_token_uri
            );
            return (ret_token_uri_len, ret_token_uri);
        } else {
            assert res_token_uri[0] = tokenId.low;
            let (lucky) = token_lucky.read(tokenId);
            if (lucky.low == 1) {
                assert res_token_uri[1] = '.json';
                let (ret_token_uri_len, ret_token_uri) = arr_concat(
                    ret_base_token_uri_len, ret_base_token_uri, 2, res_token_uri
                );
                return (ret_token_uri_len, ret_token_uri);
            } else {
                assert res_token_uri[1] = '-';
                assert res_token_uri[2] = lucky.low;
                assert res_token_uri[3] = '.json';
                let (ret_token_uri_len, ret_token_uri) = arr_concat(
                    ret_base_token_uri_len, ret_base_token_uri, 4, res_token_uri
                );
                return (ret_token_uri_len, ret_token_uri);
            }
            
        }
    }

    // If both base_token_uri and token_uri are undefined, return empty array
    return (tokenURI_len=0, tokenURI=ret_base_token_uri);
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
}(tokenId: Uint256) -> (tm: felt){
    let tm = token_earn_tm.read(tokenId);
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
}(to: felt, tokenId: Uint256) {
    ERC721.approve(to, tokenId);
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
}(from_: felt, to: felt, tokenId: Uint256) {
    ERC721.transfer_from(from_, to, tokenId);
    return ();
}

@external
func safeTransferFrom{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(from_: felt, to: felt, tokenId: Uint256, data_len: felt, data: felt*) {
    ERC721.safe_transfer_from(from_, to, tokenId, data_len, data);
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
}(tokenId: Uint256) {
    alloc_locals;
    let (local chip_address: felt) = token_chip.read(tokenId);

    token_chip.write(tokenId, '');
    chip_token.write(chip_address, abandoned_id);
    return ();
}

@external
func reBlindChip{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(chip_address: felt, proof_len: felt, proof: felt*, tokenId: Uint256) {
    alloc_locals;
    
    let (amount_hash) = hash2{hash_ptr=pedersen_ptr}(1, 0);
    let (leaf) = hash2{hash_ptr=pedersen_ptr}(chip_address, amount_hash);
    let (root) = merkle_root.read();
    let (proof_valid) = merkle_verify(leaf, root, proof_len, proof);
    with_attr error_message("Proof not valid") {
        assert proof_valid = 1;
    }

    let (caller) = get_caller_address();
    let (local token_owner: felt) = ownerOf(tokenId=tokenId);
    with_attr error_message("Caller doesn't own the asset"){
        assert caller = token_owner;
    }
    let (is_exist_id) = chip_token.read(chip_address);
    with_attr error_message("chip has been used"){
        assert is_exist_id = 0;
    }

    let (old_chip_address) = token_chip.read(tokenId);

    token_chip.write(tokenId, chip_address);
    chip_token.write(chip_address, tokenId.low);
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
}(tokenId_low: felt) -> felt {
    if (tokenId_low == abandoned_id) {
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

    let (tokenId_low) = chip_token.read(chip_address);

    let (caller) = get_caller_address();

    let (now_tm) = get_block_timestamp();
    // is exist chip
    if (tokenId_low == 0) {
        // token id must stark from 1, because read cannot check not exist or zero
        let (current_counter) = token_counter.read();
        let (next_tokenId, _) = uint256_add(current_counter, Uint256(1, 0));
        let _isabandonedChip = _is_abandoned_chip(next_tokenId.low);
        if (_isabandonedChip == TRUE) {
            let (next_id, _) = uint256_add(next_tokenId, Uint256(1, 0));
            token_counter.write(next_id);
        } else {
            token_counter.write(next_tokenId);
        }
        let (tokenId) = token_counter.read();

        let _data_len : felt = 0;
        let (local _data : felt*) = alloc();
        ERC721._safe_mint(caller, tokenId, _data_len, _data);

        token_chip.write(tokenId, chip_address);
        chip_token.write(chip_address, tokenId.low);
        token_lucky.write(tokenId, Uint256(1, 0));

        do_each(tokenId, contract_20_address, caller, now_tm);
        return ();
    } else {
        let (tokenId_low) = chip_token.read(chip_address);
        let _isabandonedChip = _is_abandoned_chip(tokenId_low);
        with_attr error_message("This Chip is abandoned"){
            assert _isabandonedChip = FALSE;
        }
        let tokenId = Uint256(tokenId_low, 0);

        let (local token_owner: felt) = ownerOf(tokenId=tokenId);
        with_attr error_message("Caller doesn't own the asset"){
            assert caller = token_owner;
        }
        let (last_tm) = token_earn_tm.read(tokenId);
        tempvar diff = now_tm - last_tm;

        with_attr error_message("please wait for some time"){
            assert_nn(diff - EARN_INTERVAL);
        }

        do_each(tokenId, contract_20_address, caller, now_tm);
        return ();
    }
}

func do_each{
        syscall_ptr : felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
}(tokenId: Uint256, contract_20_address: felt, caller: felt, now_tm: felt) {
    let lucky: Uint256 = token_lucky.read(tokenId);
    let amount: Uint256 = earn_amount_by_lucky(lucky);
    IMyTokenContract.touchToEarn(
        contract_address=contract_20_address, user=caller, amount=amount
    );

    token_earn_tm.write(tokenId, now_tm);
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
}(contract_20_address: felt, tokenId: Uint256) {
    alloc_locals;
    let (caller) = get_caller_address();

    let (local token_owner: felt) = ownerOf(tokenId=tokenId);
    with_attr error_message("Caller doesn't own the asset") {
        assert caller = token_owner;
    }

    let lucky: Uint256 = getLucky(tokenId=tokenId);
    let amount: Uint256 = burn_amount_by_lucky(lucky);

    IMyTokenContract.burnToUpgrade(
        contract_address=contract_20_address, user=caller, amount=amount
    );

    let (new_lucky, _) = uint256_add(lucky, Uint256(1, 0));
    token_lucky.write(tokenId, new_lucky);

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
