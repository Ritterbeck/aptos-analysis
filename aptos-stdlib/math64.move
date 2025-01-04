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
         *
         * I have a proof this prevents overflow. I need to write it down here
         * at some point.
         * -Brent A. Ritterbeck; 20250104
         *
         * The following shows the expressions used in the if-else structure
         * are indeed the average of a and b. This does not constitute the
         * proof I mention above.
         * -Brent A. Ritterbeck; 20250104
         *
         * Without loss of generality, assume a <= b. We now have
         * a + (b - a) / 2 = a + (b / 2) - (a / 2)
         *                 = (a / 2) + (b / 2)
         *                 = (a + b) / 2
         */
        if(a < b)
        {
            a + (b - a) / 2
        }
        else
        {
            b + (a - b) / 2
        }
    }

    /*
     * I know the general idea behind this algorithm; however, I need to
     * properly cite a source for it.
     * -Brent A. Ritterbeck; 20250104
     */
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

    /*
     * The first part of the if-else structure is immediately obvious. I need
     * produce a proof of the else portion.
     * -Brent A. Ritterbeck; 20250104
     */
    public inline fun
    lcm(a: u64, b: u64) : u64
    {
        if(a == 0 || b == 0)
        {
            0
        }
        else
        {
            a / gcd(a, b) * b
        }
    }

    /*
     * Compute a * b / c
     *
     * The function uses u128 to prevent overflow.
     */
    public inline fun
    mul_div(a: u64, b: u64, c: u64) : u64
    {
        /*
         * The source file has the following quote:
         * "Inline functions cannot take constants, as then every module
         * using it needs the constant."
         *
         * I need to return to this comment once I better understand things.
         * -Brent A. Ritterbeck; 20250104
         */
        assert!(c != 0, std::error::inavlid_argument(4));
        (((a as u128) * (b as u128) / (c as u128)) as u64) 
    }

    public fun
    clamp(x: u64, lower: u64, upper: u64) : u64
    {
        min(upper, max(lower, x))
    }

    public fun
    pow(n: u64, e: u64) : u64
    {
        if(e == 0)
        {
            1
        }
        else
        {
            let p = 1;

            while(e > 1)
            {
                if(e % 2 == 1)
                {
                    p = p * n;
                };

                e = e / 2;
                n = n * n;
            };

            p * n
        }
    }

    public fun
    floor_log2(x: u64) : u8
    {
        let res = 0;

        /*
         * This assertion comes after the let statement. Shouldn't the
         * assertion come first? Why create a variable if this function
         * would immediately fail with a zero input?
         * -Brent A. Ritterbeck; 20250104
         */
        assert!(x != 0, std::error::invalid_argument(EINVALID_ARG_FLOOR_LOG2));

        /*
         * The source makes the following comment:
         * "Effectively the position of the most significant set bit"
         *
         * I need to understand what is meant by the comment.
         * -Brent A. Ritterbeck; 20250104
         */
        let n = 32;

        while(n > 0)
        {
            if(x >= (1 << n))
            {
                x = x >> n;
                res = res + n;
            };
            n = n >> 1;
        };

        res
    }

    /*
     * I should be able to understand this without having to think deeply
     * about the logic here. Unfortunately, my bit manipulating abilities
     * are severely limited. This is a weakness I need to remedy.
     * -Brent A. Ritterbeck; 20250104
     */
    public fun
    log2(x: u64) : FixedPoint32
    {
        let integer_part = floor_log2(x);

        let y = (
            if(x >= 1 << 32)
            {
                x >> (integer_part - 32)
            }
            else
            {
                x << (32 - integer_part)
            }
        as u128);
        
        let frac  = 0;
        let delta = 1 << 31;

        while(delta != 0)
        {
            y = (y * y) >> 32;

            if(y >= (2 << 32))
            {
                frac = frac + delta;
                y    = y >> 1;
            };

            delta = delta >> 1;
        };

        fixed_point32::create_from_raw_value(((integer_part as u64) << 32) + frac)
    }

    /*
     * There are several comments in the source that I have not yet explored.
     * I need a proper proof this logic is correct. Review these comments and
     * develop a proof.
     * -Brent A. Ritterbeck; 20250104
     */
    public fun
    sqrt(x: u64) : u64
    {
        if(x == 0)
        {
            return 0;
        }

        let res = 1 << ((floor_log2(x) + 1) >> 1);
        res = (res + x / res) >> 1;
        res = (res + x / res) >> 1;
        res = (res + x / res) >> 1;
        res = (res + x / res) >> 1;

        min(res, x / res);
    }
}
