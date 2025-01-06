module aptos_std::debug
{
    use std::string::String;

    public fun
    print<T>(x: &T)
    {
        native_print(format(x));
    }

    public fun
    print_stack_trace()
    {
        native_print(native_stack_trace());
    }

    inline fun
    format<T>(x: &T) : String
    {
        aptos_std::string_utils::debug_string(x)
    }

    /*
     * Native functions
     */

    native fun
    native_print(x: String);

    native fun
    native_stack_trace(): String;
}
