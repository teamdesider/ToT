// https://github.com/marcellobardus/starknet-l2-storage-verifier/blob/master/contracts/starknet/lib/concat_arr.cairo
// https://github.com/sekai-studio/starknet-libs/blob/main/cairo_string/Array.cairo

from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc

func array_concat {range_check_ptr} (
        arr1_len : felt,
        arr1 : felt*,
        arr2_len : felt,
        arr2 : felt*
    ) -> (
        res_len : felt,
        res : felt*
    ){
    alloc_locals;

    let (local res : felt*) = alloc();
    memcpy(res, arr1, arr1_len);
    memcpy(res + arr1_len, arr2, arr2_len);

    return (arr1_len + arr2_len, res);
}

func arr_concat{range_check_ptr}(
    a_len: felt,
    a: felt*,
    b_len: felt,
    b: felt*,
    ) -> (res_len: felt, res: felt*){
    alloc_locals;
    let (local a_cpy: felt*) = alloc();

    memcpy(a_cpy, a, a_len);
    memcpy(a_cpy + a_len, b, b_len);

    return (a_len + b_len, a_cpy);
}

func arr_eq(a_len: felt, a: felt*, b_len: felt, b: felt*) -> (res: felt){
    if (a_len != b_len) {
        return (res=0);
    }
    if (a_len == 0) {
        return (res=1);
    }
    return _arr_eq(a_len=a_len, a=a, b_len=b_len, b=b, current_index=a_len-1);
}

func _arr_eq(a_len: felt, a: felt*, b_len: felt, b: felt*, current_index: felt) -> (res: felt){
    if (current_index == -1) {
        return (res=1);
    }
    if (a[current_index] != b[current_index]) {
        return (res=0);
    }
    return _arr_eq(a_len=a_len, a=a, b_len=b_len, b=b, current_index=current_index-1);
}

