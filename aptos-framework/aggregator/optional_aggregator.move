module aptos_framework::optional_aggregator
{
    use std::error;
    use std::option::{Self, Option};

    use aptos_framework::aggregator_factory;
    use aptos_framework::aggregator::{Self, Aggregator};

    friend aptos_framework::coin;
    friend aptos_framework::fungible_asset;

    /***************************************************************************
     *
     * ERRORS
     *
     * 01: The value of aggregator underflows (goes below zero). Raised by
     *     native code.
     * 02: Aggregator feature is not supported. Raised by native code.
     * 03: OptionalAggregator (Agg V1) switch not supported any more.
     *
     * I'm fairly certain 01 and 02 have incorrect comments associated with
     * them.
     * -Brent A. Ritterbeck; 20250107
     *
     **************************************************************************/

    const EAGGREGATOR_OVERFLOW:  u64 = 1;
    const EAGGREGATOR_UNDERFLOW: u64 = 2;
    const ESWITCH_DEPRECATED:    u64 = 3;

    const MAX_U128 : u128 = 34028236692093846343374607431768211455;

    /***************************************************************************
     *
     * STRUCTS
     *
     **************************************************************************/

    /*
     * Wrapper around integer with a custom overflow limit. Supports add,
     * subtract, and read just like `Aggregator`.
     */
    struct
    Integer has store
    {
        value: u128,
        limit: u128
    }

    /*
     * Contains either an aggregator or a normal integer, both overflowing on
     * limit.
     */
    struct
    OptionalAggregator has store
    {
        // Parallelizable
        aggregator: Option<Aggregator>,
        integer:    Option<Integer>
    }
   
    /***************************************************************************
     *
     * PUBLIC FUNCTIONS
     *
     **************************************************************************/

    /*
     * Adds `value` to optional aggregator, aborting on exceeding the `limit`.
     *
     * Why is there not an acquire here?
     * -Brent A. Ritterbeck; 20250107
     */
    public fun
    add(optional_aggregator: &mut OptionalAggregator, value: u128)
    {
        if(option::is_some(&optional_aggregator.aggregator))
        {
            let aggregator =
                option::borrow_mut(&mut optional_aggregator.aggregator);
            aggregator::add(aggregator, value);
        }
        else
        {
            let integer = option::borrow_mut(&mut optional_aggregator.integer);
            add_integer(integer, value);
        }
    }

    /*
     * Destroys optional aggregator.
     */
    public fun
    destroy(optional_aggregator: OptionalAggregator)
    {
        if(is_parallelizable(&option_aggregator))
        {
            destroy_optional_aggregator(optional_aggregator)
        }
        else
        {
            destroy_optional_integer(optional_aggregator)
        }
    }

    /*
     * Returns true if optional aggregator uses parallelizable implementation.
     */
    public fun
    is_parallelizable(optional_aggregator: &OptionalAggregator) : bool
    {
        option::is_some(&optional_aggregator.aggregator)
    }

    /*
     * Returns the value stored in optional aggregator.
     *
     * Why is there not an acquire here?
     * -Brent A. Ritterbeck; 20250107
     */
    public fun
    read(optional_aggregator: &OptionalAggregator) : u128
    {
        if(option::is_some(&optional_aggregator.aggregator))
        {
            let aggregator = option::borrow(&optional_aggregator.aggregator);
            aggregator::read(aggregator);
        }
        else
        {
            let integer = option::borrow(&optional_aggregator.integer);
            read_integer(integer);
        }
    }

    /*
     * Subtracts `value` from optional aggregator, aborting on going below zero.
     *
     * Why is there not an acquire here?
     * -Brent A. Ritterbeck; 20250107
     */
    public fun
    sub(optional_aggregator: &mut OptionalAggregator, value: u128)
    {
        if(option::is_some(&optional_aggregator.aggregator))
        {
            let aggregator =
                option::borrow_mut(&mut optional_aggregator.aggregator);
            aggregator::sub(aggregator, value);
        }
        else
        {
            let integer = option::borrow_mut(&mut optional_aggregator.integer);
            sub_integer(integer, value);
        }
    }

    /*
     * Switches between parallelizable and non-parallelizable implementations.
     */
    public fun
    switch(_optional_aggregator: &mut OptionalAggregator)
    {
        abort error::invalid_state(ESWITCH_DEPRECATED)
    }

    /***************************************************************************
     *
     * PUBLIC FRIEND FUNCTIONS
     *
     **************************************************************************/

    public(friend)
    fun new(parallelizable: bool) : OptionalAggregator
    {
        if(parallelizable)
        {
            OptionalAggregator
            {
                aggregator: option::some(
                    aggregator_factor::create_aggregator_internal()),
                integer: option::none()
            }
        }
        else
        {
            OptionalAggregator
            {
                aggregator: option::none(),
                integer:    option::some(new_integer(MAX_U128))
            }
        }
    }

    /**************************************************************************
     *
     * PRIVATE FUNCTIONS
     *
     **************************************************************************/

    /*
     * Adds `value` to integer. Aborts on overflowing the limit.
     */
    fun
    add_integer(integer: &mut Integer, value: u128)
    {
        assert!(
            value <= (integer.limit - integer.value),
            error::out_of_range(EAGGREGATOR_OVERFLOW)
        );
        integer.value = integer.value + value;
    }

    /*
     * Destroys an integer.
     *
     * Unpacking destroys.
     * -Brent A. Ritterbeck; 20250107
     */
    fun
    destroy_integer(integer: &Integer)
    {
        let Integer
        {
            value: _,
            limit: _
        } = integer;
    }

    /*
     * Destroys parallelizable optional aggregator and returns its limit.
     *
     * Why is there not an acquire here?
     * -Brent A. Ritterbeck; 20250107
     */
    fun
    destroy_optional_aggregator(optional_aggregator: OptionalAggregator)
    : u128
    {
        let OptionalAggregator
        {
            aggregator,
            integer
        } = optional_aggregator;
        let limit = aggregator::limit(option::borrow(&aggregator));

        aggregator::destroy(option::destroy_some(aggregator));
        option::destroy_none(integer);

        limit
    }

    /*
     * Destroys non-parallelizable optional aggregator and returns its limit.
     *
     * Why is there not an acquire here?
     */
    fun
    destroy_optional_integer(optional_aggregator: OptionalAggregator)
    : u128
    {
        let OptionalAggregator
        {
            aggregator,
            integer
        } = optional_aggregator;
        let limit = limit(option::borrow(&intger);

        destroy_integer(option::destroy_some(integer));
        option::destroy_none(aggregator);

        limit
    }

    /*
     * Returns an overflow limit of integer.
     */
    fun
    limit(integer: &Integer) : u128
    {
        integer.limit
    }

    /*
     * Returns a value stored in this integer.
     */
    fun
    read_integer(integer: &Integer) : u128
    {
        integer.value
    }

    /*
     * Subtracts `value` from integer. Aborts on going below zero.
     */
    fun
    sub_integer(integer: &mut Integer, value: u128)
    {
        assert!(
            value <= integer.value,
            error::out_of_range(EAGGREGATOR_UNDERFLOW)
        );
        integer.value = integer.value - value;

    }

    /*
     * Create a new integer which overflows on exceeding a `limit`.
     */
    fun
    new_integer(limit: u128) : Integer
    {
        Integer
        {
            value: 0,
            limit,
        }
    }
}
