/*
 *
 * Current Status: Analyzing
 * -Brent A. Ritterbeck; 20250103
 */

module aptos_std::math64
{
    use std::fixed_point32::FixedPoint32;
    use std::fixed_point32;

    const EINVALID_ARG_FLOOR_LOG2: u64 = 1;

    public fun
    max(a: u64, b: u64) : u64
    {
        if(a >= b) a else b
    }

    public fun
    min(a: u64, b: u64) : u64
    {
        if(a < b) a else b
    }

    public fun
    average(a: u64, b: u64) : u64
    {
        /*
         * ASSUMPTION:
         * Logic is split in an attempt to prevent oveflow.
         * -Brent A. Ritterbeck; 20250103
         */
        if(a < b)
        {
            /*
             * a + (b - a) / 2 = a + (b / 2) - (a / 2)
             *                 = (a / 2) + (b / 2)
             *                 = (a + b) / 2
             */
            a + (b - a) / 2
        }
        else
        {
            /*
             * b + (a - b) / 2 = b + (a / 2) - (b / 2)
             *                 = (b / 2) + (a / 2)
             *                 = (a / 2) + (b / 2)
             *                 = (a + b) / 2
             */
            b + (a - b) / 2
        }
    }

    public inline fun
    gcd(a: u64, b: u64) : u64
    {
        let (large, small) = if (a > b) (a, b) else (b, a);

        while(small != 0)
        {
            let temp = small;
            small    = large % small;
            large    = temp;
        };

        large
    }
}
