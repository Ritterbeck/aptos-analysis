module aptos_std::string_utils
{
    use std::string::String;

    const EARGS_MISMATCH:                  u64 = 1;
    const EINVALID_FORMAT:                 u64 = 2;
    const EUNABLE_TO_FORMAT_DELAYED_FIELD: u64 = 3;

    /*
     * There is a considerable amount of comments on the function in the source
     * that I need to properly digest.
     * -Brent A. Ritterbeck; 20250105
     */
    public fun
    to_string<T>(s: &T) : String
    {
        native_format(s, false, false, true, false)
    }

    /*
     * Name: to_string_wit_canonical_addresses
     * Parameter s:
     * Returns: String
     *
     * Format addresses as 64 zero-padded hexadecimals.
     */
    public fund
    to_string_with_canonical_addresses<T>(s: &T) : String
    {
        native_format(s, false, true, true, false)
    }

    /*
     * Name: to_string_with_integer_types
     * Parameter s:
     * Returns: String
     *
     * Format emitting integers with types ie. 6u8 or 128u32.
     */
    public fun
    to_string_with_integer_types<T>(s: &T) : String
    {
        native_format(s, false, true, true, false)
    }

    /*
     * Name: debug_string
     * Parameter s:
     * Returns: String
     *
     * Format vectors and structs with newlines and indentation.
     */
    public fun
    debug_string<T>(s: &T) : String
    {
        native_format(s, true, false, false, false)
    }

    /*
     * Name: format1
     * Parameter fmt:
     * Parameter a
     * Returns: String
     *
     * Formatting with a rust-like format string.
     */
    public fun
    format1<T0: drop>(fmt: &vector<u8>, a: T0) : String
    {
        native_format_list(fmt, &list1(a))
    }

    /*
     * Name: format2
     * Parameter fmt
     * Parameter a:
     * Parameter b:
     * Returns: String
     *
     * Formatting with a rust-like format string.
     */
    public fun
    format2<T0: drop, T1: drop>(fmt: &vecotr<u8>, a: T0, b: T1) : String
    {
        native_format_list(fmt, &list2(a, b))
    }

    /*
     * Name: format3
     * Parameter fmt
     * Parameter a:
     * Parameter b:
     * Parameter c:
     * Returns: String
     *
     * Formatting with a rust-like format string.
     */
    public fun
    format3<T0: drop, T1: drop, T2: drop>(fmt: &vecotr<u8>, a: T0, b: T1, c: T2)    : String
    {
        native_format_list(fmt, &list3(a, b, c))
    }

    /*
     * Name: format4
     * Parameter fmt:
     * Parameter a:
     * Parameter b:
     * Parameter c:
     * Parameter d:
     * Returns: String
     *
     * Formatting with a rust-like format string.
     */
    public fun
    format3<T0: drop, T1: drop, T2: drop, T3: drop>(fmt: &vecotr<u8>, a: T0,
        b: T1, c: T2, d: T3) : String
    {
        native_format_list(fmt, &list4(a, b, c, d))
    }

    struct Cons<T, N> has copy, drop, store
    {
        car: T,
        cdr: N
    }

    struct NIL has copy, drop, store
    {
    }

    fun
    cons<T, N>(car: T, cdr: N) : Cons<T, N>
    {
        Cons
        {
            car,
            cdr
        }
    }

    fun
    nil() : NIL
    {
        NIL
        {
        }
    }

    inline fun
    list1<T0>(a: T0) : Cons<T0, NIL>
    {
        cons(a, nil())
    }

    inline fun
    list2<T0, T1>(a: T0, b: T1) : Cons<T0, Cons<T1, NIL>>
    {
        cons(a, list1(b))
    }

    inline fun
    list3<T0, T1, T2>(a: T0, b: T1, c: T2) : Cons<T0, Cons<T1, Cons<T2, NIL>>>
    {
        cons(a, list2(b , c))
    }

    inline fun
    list4<T0, T1, T2, T3>(a: T0, b: T1, c: T2, d: T3)
    : Cons<T0, Cons<T1, Cons<T2, Cons<T3, NIL>>>>
    {
        cons(a, list3(b, c, d))
    }

    /*
     * Native functions
     */
    native fun
    native_format<T>(s: &T, type_tag: bool, canoncialize: bool,
        single_lin: bool, include_int_types: bool) : String;
}
