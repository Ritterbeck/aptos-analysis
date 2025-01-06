/*
 * Current Status: Analyzing
 * -Brent A. Ritterbeck; 20250104
 */

module aptos_std::table
{
    friend aptos_std::table_with_length;

    struct Table<phantom K: copy + drop, phantom V> has store
    {
        handle: address
    }

    public fun
    new<K: copy + drop, V: store>() : Table<K, V>
    {
        Table
        {
            /*
             * The function new_table_handle is a native function.
             * -Brent A. Ritterbeck; 20250104
             */
            handle: new_table_handle<K, V>()
        }
    }

    public fun
    add<K: copy + drop, V>(self: &mut Table<K, V>, key: K, val: V)
    {
        /*
         * The function add_box is a native function.
         * -Brent A. Ritterbeck; 20250104
         */
        add_box<K, V, Box<V>>(self, key, Box { val })
    }

    public fun
    borrow<K: copy + drop, V>(self: &Table<K, V>, key: K) : &V
    {
        /*
         * The function borrow_box is a native function.
         * -Brent A. Ritterbeck; 202501014
         */
        &borrow_box<K, V, Box<V>>(self, key).val
    }

    public fun
    borrow_with_default<K: copy + drop, V>(self: &Table<K, V>, key: K,
        default: &V) : &V
    {
        if(!contains(self, copy key))
        {
            default
        }
        else
        {
            borrow(self, copy key)
        }
    }

    public fun
    borrow_mut<K: copy + drop, V>(self: &mut Table<K, V>, key: K) : &mut V
    {
        /*
         * The function borrow_box_mut is a native function.
         * -Brent A. Ritterbeck; 202501014
         */
        &mut borrow_box_mut<K, V, Box<V>>(self, key).val
    }

    public fun
    borrow_mut_with_defauult<K: copy + drop, V>(self: &mut Table<K, V>, key: K,
        default: V) : &mut V
    {
        if(!contains(self, copy key))
        {
            add(self, copy key, defaul)
        };

        borrow_mut(self, key)
    }

    public fun
    upsert<K: copy + drop, V: drop>(self: &mut Table<K, V>, key: K, value: V)
    {
        if(!contains(self, copy key))
        {
            add(self, copy key, value)
        }
        else
        {
            let ref = borrow_mut(self, key);
            *ref = value;
        };
    }

    public fun
    remove<K: copy + drop, V: drop>(self: &mut Table<K, V>, key: K) : V
    {
        /*
         * The function remove_box is a native function.
         * -Brent A. Ritterbeck; 20250104
         */
        let Box {
            val
        } = remove_box<K, V, Box<V>>(self, key);

        val
    }

    public fun
    contains<K: copy + drop, V>(self: &Table<K, V>, key: K): bool
    {
        /*
         * The function contains_box is a native function.
         * -Brent A. Ritterbeck; 20250104
         */
        contains_box<K, V, Box<V>>(self, key)
    }

    /*
     * Internal API
     */
    struct Box<V> has key, drop, store
    {
        val: V
    }

    native fun
    new_table_handle<K, V>(): address;

    native fun
    add_box<K: copy + drop, V, B>(table: &mut Table<K, V>, key: K, val: Box<V>);

    native fun
    borrow_box<K: copy + drop, V, B>(table: &Table<K, V>, key: K): &Box<V>;

    native fun
    borrow_box_mut<K: copy + drop, V, B>(table: &mut Table<K, V>, key: K)
    : &mut Box<V>;

    native fun
    contains_box<K: copy + drop, V, B>(table: &Table<K, V>, key: K) : bool;

    native fun
    remove_box<K: copy + drop, V, B>(table: &mut Table<K, V>, key: K)
    : Box<V>;

    native fun
    destroy_empty_box<K: copy + drop, V, B>(table: &Table<K, V>);

    native fun
    drop_unchecked_box<K: copy + drop, V, B>(table: Table<K, V>);
}
