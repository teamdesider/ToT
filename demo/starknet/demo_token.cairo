// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.bool import TRUE
from starkware.starknet.common.syscalls import get_caller_address

from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.messages import send_message_to_l1

from openzeppelin.token.erc20.library import ERC20
from openzeppelin.access.ownable.library import Ownable

const L1_CONTRACT_ADDRESS = (
    0x2e82c3977B5de7b5Eb25c0a4b1C97DF7e3C5359c);
const MESSAGE_TK_TRANSFER = 100;

@storage_var
func white_list(contr : felt) -> (luck: felt) {
}

@constructor
func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(owner: felt) {
    ERC20.initializer('ADTK', 'ADTH', 18);
    Ownable.initializer(owner);
    return ();
}

//
// Getters
//

@view
func name{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}() -> (name: felt) {
    return ERC20.name();
}

@view
func symbol{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}() -> (symbol: felt) {
    return ERC20.symbol();
}

@view
func totalSupply{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}() -> (totalSupply: Uint256) {
    let (totalSupply) = ERC20.total_supply();
    return (totalSupply=totalSupply);
}

@view
func decimals{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}() -> (decimals: felt) {
    return ERC20.decimals();
}

@view
func balanceOf{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(account: felt) -> (balance: Uint256) {
    return ERC20.balance_of(account);
}

@view
func allowance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(owner: felt, spender: felt) -> (remaining: Uint256) {
    return ERC20.allowance(owner, spender);
}

@view
func owner{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}() -> (owner: felt) {
    return Ownable.owner();
}

//
// Externals
//

@external
func setWhiteList{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
}(contr : felt) {
    let (caller) = get_caller_address();
    let (owner) = Ownable.owner();
    with_attr error_message("Caller doesn't own the asset") {
      assert caller = owner;
    }
    white_list.write(contr, 1);
    return ();
}

@external
func transfer{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(recipient: felt, amount: Uint256) -> (success: felt) {
    return ERC20.transfer(recipient, amount);
}

@external
func transferFrom{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(sender: felt, recipient: felt, amount: Uint256) -> (success: felt) {
    return ERC20.transfer_from(sender, recipient, amount);
}

@external
func approve{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(spender: felt, amount: Uint256) -> (success: felt) {
    return ERC20.approve(spender, amount);
}

@external
func increaseAllowance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(spender: felt, added_value: Uint256) -> (success: felt) {
    return ERC20.increase_allowance(spender, added_value);
}

@external
func decreaseAllowance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(spender: felt, subtracted_value: Uint256) -> (success: felt) {
    return ERC20.decrease_allowance(spender, subtracted_value);
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
func transferToL1{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(l1_recipient: felt, amount: Uint256) {
    let (caller) = get_caller_address();
    ERC20._burn(caller, amount);

    // Call L1
    let (message_payload: felt*) = alloc();
    assert message_payload[0] = MESSAGE_TK_TRANSFER;
    assert message_payload[1] = amount.low;
    assert message_payload[2] = amount.high;
    assert message_payload[3] = l1_recipient;
    
    send_message_to_l1(
        to_address=L1_CONTRACT_ADDRESS,
        payload_size=4,
        payload=message_payload
    );

    return ();
}


@external
func touchToEarn{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
}(to: felt, amount: Uint256) {
    let (caller) = get_caller_address();
    let (is_exist) = white_list.read(caller);

    with_attr error_message("don't have enough permission") {
      assert is_exist = 1;
    }

    ERC20._mint(to, amount);
    return ();
}

@external
func burnToUpgrade{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}(user : felt, amount : Uint256) {
    // Make sure the message was sent by the intended L1 contract.
    let (caller) = get_caller_address();
    let (is_exist) = white_list.read(caller);

    with_attr error_message("don't have enough permission") {
      assert is_exist = 1;
    }

    ERC20._burn(user, amount);

    return ();
}

//
// l1_handler
//

@l1_handler
func deposit{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}(from_address : felt, user : felt, amount_low : felt, amount_high : felt) {
    // Make sure the message was sent by the intended L1 contract.
    assert from_address = L1_CONTRACT_ADDRESS;

    let amount: Uint256 = Uint256(low=amount_low, high=amount_high);
    ERC20._mint(user, amount);

    return ();
}
