module aptos_framework::coin
{
    use std::error;
    use std::features;
    use std::option::{Self, Option};
    use std::signer;
    use std::string::{Self, String};
    use aptos_std::table::{Self, Table};

    use aptos_framework::account;
    use aptos_framework::aggregator_factory;
    use aptos_framework::aggregator::Aggregator;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::guid;
    use aptos_framework::option_aggregator::{Self, OptionalAggregator};
    use aptos_framework::system_addresses;

    use aptos_framework::fungible_asset::{Self, FungibleAsset, Metadata, MinRef, TransferRef, BurnRef};
    use aptos_framework::object::{Self, Object, object_address};
    use aptos_framework::primary_fungible_store;
    use aptos_std::type_info::{Self, TypeInfo, type_name};
    use aptos_framework::create_signer;

    friend aptos_framework::aptos_coin;
    friend aptos_framework::genesis;
    friend aptos_framework::transaction_fee;

    /***************************************************************************
     *
     * ERRORS
     *
     * 01: Address of account which is used to initialize a `CoinType` doesn't
     *     match the deployer of the module
     * 02: `CoinType` is already initialized as a coin
     * 03: `CoinType` hasn't been initialized as a coin
     * 04: DEPRECATED
     * 05: Account hasn't registered `CoinStore` for `CoinType`
     * 06: Not enough coins to complete transaction
     * 07: Cannot destroy non-zero coins
     * 08: NOT ASSIGNED
     * 09: NOT ASSIGNED
     * 10: CoinStore is frozen. Coins cannot be deposited or withdrawn
     * 11: Cannot upgrade the total supply of coins to different implementation
     * 12: Name of the coin is too long
     * 13: Symbol of the coin is too long
     * 14: The value of aggregatable coin used for transaction fees
     *     redistribution does not fit in u64
     * 15: Error regarding paired coin type of the fungible asset metadata
     * 16: Erorr regarding paired fungible asset metadata of a coin type
     * 17: The coin type from the map does not match th calling function type
     *     argument
     * 18: The feature of migration from coin to fungible asset is not enabled
     * 19: PairedFungibleAssetRefs resource does not exist
     * 20: The MintRefReceipt does not match the MintRef to be return
     * 21: The MintRef does not exist
     * 22: The TransferRefReceipt does not match the TransferRef to be returned
     * 23: The TransferRef does not exist
     * 24: The BurnRefReceipt dos not match the BurnRef to be returned
     * 25: The BurnRef does not exist
     * 26: The migration process from coin to fungible asset is not enabled yet
     * 27: The coin conversion map is not yet created
     * 28: APT pairing is not yet enabled
     *
     **************************************************************************/

    const ECOIN_INFO_ADDRESS_MISMATCH:                 u64 =  1;
    const ECOIN_INFO_ALREADY_PUBLISHED:                u64 =  2;
    const ECOIN_INFO_NOT_PUBLISHED:                    u64 =  3;
    const ECOIN_STORE_ALREADY_PUBLISHED:               u64 =  4;
    const ECOIN_STORE_NOT_PUBLISHED:                   u64 =  5;
    const EINSUFFICIENT_BALANCE:                       u64 =  6;
    const EDESTRUCTION_OF_NONZERO_TOKEN:               u64 =  7;
    const EFROZEN:                                     u64 = 10;
    const ECOIN_SUPPLY_UPGRADE_NOT_SUPPORTED:          u64 = 11;
    const ECOIN_NAME_TOO_LONG:                         u64 = 12;
    const ECOIN_SYMBOL_TOO_LONG:                       u64 = 13;
    const EAGGREGATABLE_COIN_VALUE_TOOL_LARGE:         u64 = 14;
    const EPAIRED_COIN:                                u64 = 15;
    const EPAIRED_FUNGIBLE_ASSET:                      u64 = 16;
    const ECOIN_TYPE_MISMATCH:                         u64 = 17;
    const ECOIN_TO_FUNGIBLE_ASSET_FEATURE_NOT_ENABLED: u64 = 18;
    const EPAIRED_FUNGIBLE_ASSET_REFS_NOT_FOUND:       u64 = 19;
    const EMINT_REF_RECEIPT_MISMATCH:                  u64 = 20;
    const EMINT_REF_NOT_FOUND:                         u64 = 21;
    const ETRANSFER_REF_RECEIPT_MISMATCH:              u64 = 22;
    const ETRANSFER_REF_NOT_FOUND:                     u64 = 23;
    const EBURN_REF_RECEIPT_MISMATCH:                  u64 = 24;
    const EBURN_REF_NOT_FOUND:                         u64 = 25;
    const EMIGRATION_FRAMEWORK_NOT_ENABLED:            u64 = 26;
    const ECOIN_CONVERSION_MAP_NOT_FOUND:              u64 = 27;
    const EAPT_PAIRING_IS_NOT_ENABLED:                 u64 = 28;

    /***************************************************************************
     *
     * CONSTANTS
     *
     **************************************************************************/

    const MAX_COIN_NAME_LENGTH:    u64 =                    32;
    const MAX_COIN_SYMBOL_LENGTH:  u64 =                    10;
    const MAX_U64:                u128 = 118446744073709551615;

    /***************************************************************************
     *
     * STRUCTS
     *
     **************************************************************************/

    /*
     * Main structure representing a coin / token in an account's custody.
     */
    struct
    Coin<phantom CoinTYpe> has store
    {
        value: u64
    }

    /*
     * A holder of a specific coin type and associated event handles. These are
     * kept in a single resource to ensure locality of data.
     */
    struct
    CoinStore<phantom CoinType> has key
    {
        coin:            Coin<CoinType>,
        frozen:          bool,
        deposit_events:  EventHandle<DepositEvent>,
        withdraw_events: EventHandle<WithdrawEvent>
    }

    /*
     * Information about a specific coin type. Stored on the creator of the
     * coin's account.
     *
     * symbol: Symbol of the coin, usually a shorter version of the name.
     *     For example, Singapore Dollar is SGD.
     * decimals: Number of decimals used to get its user representation.
     *     For example, if `decimals` equals `2`, a balance of `505` coins
     *     should be displayed to a user as `5.05` (`505 / 10 ** 2`).
     * supply: Amounbt of this coin type in existence.
     */
    struct
    CoinInfo<phantom CoinType> has key
    {
        name:     String,
        symbol:   String,
        decimals: u8,
        supply:   Option<OptionalAggregator>
    }

    /*
     * Event emitted when some amount of a coin is deposited into an account.
     */
    struct
    DepositEvent has drop, store
    {
        amount: u64
    }

    /*
     * Event emitted when some amount of a coin is withdrawn from an account.
     */
    struct
    WithdrawEvent has drop, store
    {
        amount: u64
    }

    /*
     * Capability required to burn a coins.
     */
    struct
    BurnCapability<phantom CoinType> has copy, store
    {
    }

    /*
     * Capability required to freeze a coin store.
     */
    struct
    FreezeCapability<phantom CoinType> has copy, store
    {
    }

    /*
     * Capability required to mint coins.
     */
    struct
    MintCapability<phantom CoinType> has copy, store
    {
    }

    /*
     * The hot potato receipt for flash borrowing BurnRef.
     *
    struct
    BurnRefReceipt
    {
        metadata: Object<Metadata>
    }

    /*
     * The hot potato receipt for flash borrowing MintRef.
     */
    struct
    MinRefReceipt
    {
        metadata: Object<Metadata>
    }

    /*
     * The hot potato receipt for flash borrowing TransferRef.
     */
    struct
    TransferRefReceipt
    {
        metadata: Object<Metadata>
    }

    /***************************************************************************
     *
     * EVENTS
     *
     **************************************************************************/

    /*
     * Module event emitted when some amount of a coin is deposited into an
     * account.
     */
    #[event]
    struct
    CoinDeposit has drop, store
    {
        coin_type: String,
        account:   address,
        amount:    u64
    }

    /*
     * Module event emitted when some amount of a coin is withdrawn from an
     * account.
     */
    #[event]
    struct
    CoinWithdraw has drop, store
    {
        coin_type: String,
        account:   address,
        amount:    u64
    }

    /*
     * Module event emitted when the event handle related to a coin store is
     * deleted.
     */
    #[event]
    struct
    CoinEventHandleDeletion has drop, store
    {
        event_handle_creation_address:                 address,
        deleted_deposit_event_handle_creation_number:  u64,
        deleted_withdraw_event_handle_creation_number: u64
    }

    /*
     * Module event emitted when a new pair of coin and fungible asset is
     * created.
     */
    #[event]
    struct
    PairCreation has drop, store
    {
        coin_type:                       TypeInfo,
        fungible_asset_metadata_address: address
    }

    /***************************************************************************
     *
     * PUBLIC ENTRY FUNCTIONS
     *
     **************************************************************************/



    /***************************************************************************
     *
     * VIEW FUNCTIONS
     *
     **************************************************************************/

    /*
     * Returns the balance of `owner` for provdied `CoinType` and its paried
     * FA if exists.
     */
    #[view]
    public fun
    balance<CoinType>(owner: address) : u64
    acquires CoinConversionMap, CoinStore
    {
        let paired_metadata = paired_metadata<CoinType>();

        coin_balance<CoinType>(owner)
            + if(option::is_some(&paired_metadata))
                {
                    primary_fungible_store::balance(owner,
                        option::extract(&mut paired_metadata)
                    )
                }
                else
                {
                    0
                }
    }

    /*
     * Returns the amount of coin in existence.
     *
     * I need to better understand the option_aggregator used in this function.
     * -Brent A. Ritterbeck; 20250107
     */
    #[view]
    pub fun
    coin_supply<CoinType>() : Option<u128>
    acquires CoinInfo
    {
        let maybe_supply =
            &borrow_global<CoinInfo<CoinType>>(coin_address<CoinType>()).supply;

        if(option::is_some(maybe_supply))
        {
            let supply = option::borrow(maybe_supply);
            let value  = optional_aggregator::read(supply);
            option::some(value)
        }
        else
        {
            option::none()
        }
    }

    /*
     * Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` coins should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     */
    #[view]
    pub fun
    decimals<CoinType>() : u8
    acquires CoinInfo
    {
        borrow_global<CoinInfo<CoinType>>(coin_address<CoinType>()).decimals
    }

    /*
     * Returns `true` if `account_addr` is registered to receive `CoinType`.
     */
    #[view]
    public fun
    is_account_registered<CoinType>(account_addr: address) : bool
    acquires CoinConversionMap
    {
        assert!(is_coin_initialized<CoinType>(),
            error::invalid_argument(ECOIN_INFO_NOT_PUBLISHED));

        if(exists<CoinStore<CoinType>>(account_addr))
        {
            true
        }
        else
        {
            let paired_metadata_opt = paired_metadata<CoinType>();
            (option::is_some(&paired_metadata_opt)
                && can_receive_paired_fungible_asset(account_addr,
                    option::destroy_some(paired_metadata_opt)))
        }
    }

    /*
     * Returns whether the balance of `owner` for provided `CoinType` and its
     * paired FA is >= `amount`.
     */
    #[view]
    public fun
    is_balance_at_least<CoinType>(owner: address, amount: u64) : bool
    acquires CoinConversionMap, CoinStore
    {
        let coin_balance = coin_balance<CoinType>(owner);
        if(coin_balance >= amount)
        {
            return true
        };

        let paired_metadata = paired_metadata<CoinType>();
        let left_amount     = amount - coin_balance;

        if(option::is_some(&paired_metadata))
        {
            primary_fungible_store::is_balance_at_least(owner,
                option::extract(&mut paired_metadata), left_amount)
        }
        else
        {
            false
        }
    }

    /*
     * Returns `true` if the `CoinType` is an initialized coin.
     */
    #[view]
    public fun
    is_coin_initialized<CoinType>() : bool
    {
        exists<CoinInfo<CoinType>>(coin_address<CoinType>())
    }

    /*
     * Returns `true` if account_addr has frozen the CoinStore or if it's not
     * registered at all
     */
    #[view]
    public fun
    is_coin_store_frozen<CoinType>(account_addr: address) : bool
    acquires CoinStore, CoinConversionMap
    {
        if(!is_account_registered<CoinType>(account_addr))
        {
            return true
        };

        let coin_store = borrow_global<CoinStore<CoinType>>(account_addr);
        coin_store.frozen
    }

    /*
     * Return the name of the coin.
     */
    #[view]
    public fun
    name<CoinType>() : string::String
    acquires CoinInfo
    {
        borrow_global<CoinInfo<CoinType>>(coin_address<CoinType>()).name
    }

    /*
     * Get the paired coin type of a fungible asset metadata object.
     */
    #[view]
    public fun
    paired_coin(metadata: Object<Metadata>): Option<TypeInfo>
    acquires PairedCoinType
    {
        let metadata_addr = object::object_address(&metadata);

        if(exists<PairedCoinType>(metadata_addr))
        {
            option::some(borrow_global<PairedCoinType>(metadata_addr).type)
        }
        else
        {
            option::none()
        }
    }

    #[view]
    public fun
    paired_metadata<CoinType>() : Option<Object<Metadata>>
    acquires CoinConversionMap
    {
        if(exists<CoinConversionMap>(@aptos_framework)
            && features::coin_to_fungible_asset_migration_feature_enabled())
        {
            let map = &borrow_global<CoinConversionMap>(@aptos_framework)
                .coin_to_fungible_asset_map;

            let type = type_info::type_of<CoinType>();

            if(table::contains(map, type)
            {
                return option::some(*table::borrow(map, type))
            }
        };

        option::none()
    }

    /*
     * Check wheter `BurnRef` still exists.
     */
    #[view]
    public fun
    paired_burn_ref_exists<CoinType>() : bool
    acquires CoinConversionMap, PairedFungibleAssetRefs
    {
        let metadata = assert_paired_metadata_exists<CoinType>();
        let metadata_addr = object_address(&metadata);

        assert!(exists<PairedFungibleAssetRefs>(metadata_addr,
            error::internal(EPAIRED_FUNGIBLE_ASSET_REFS_NOT_FOUND));

        option::is_some(&borrow_global<PairedFungibleAssetRefs>(metadata_addr)
            .burn_ref_opt)
    }

    /*
     * Check wheter `MintRef` still exists.
     */
    #[view]
    public fun
    paired_mint_ref_exists<CoinType>() : bool
    acquires CoinConversionMap, PairedFungibleAssetRefs
    {
        let metadata = assert_paired_metadata_exists<CoinType>();
        let metadata_addr = object_address(&metadata);

        assert!(exists<PairedFungibleAssetRefs>(metadata_addr,
            error::internal(EPAIRED_FUNGIBLE_ASSET_REFS_NOT_FOUND));

        option::is_some(&borrow_global<PairedFungibleAssetRefs>(metadata_addr)
            .mint_ref_opt)
    }

    /*
     * Check wheter `TransferRef` still exists.
     */
    #[view]
    public fun
    paired_transfer_ref_exists<CoinType>() : bool
    acquires CoinConversionMap, PairedFungibleAssetRefs
    {
        let metadata = assert_paired_metadata_exists<CoinType>();
        let metadata_addr = object_address(&metadata);

        assert!(exists<PairedFungibleAssetRefs>(metadata_addr,
            error::internal(EPAIRED_FUNGIBLE_ASSET_REFS_NOT_FOUND));

        option::is_some(&borrow_global<PairedFungibleAssetRefs>(metadata_addr)
            .transfer_ref_opt)
    }

    /*
     * Returns the amount of coin in existence.
     *
     * There are two main paths through this function.
     * (1) Assume there is no metadata. Since there is no metadata,
     *     the function immediately returns the coin_supply.
     * (2) Assume there is metadata. Since there is metadata, there exists
     *     a fungible asset supply. Extract the fungible asset supply. If
     *     there was coin supply, we now adjust the coin supply by adding
     *     the fungible asset supply to the coin supply. We then return
     *     the sum of the two supply amounts.
     * -Brent A. Ritterbeck; 20250107
     *
     * I need to improve the description above.
     * -Brent A. Ritterbeck; 20250107
     */
    #[view]
    pub fun
    supply<CoinType>() : Option<u128>
    acquires CoinInfo, CoinConversionMap
    {
        let coin_supply = coin_supply<CoinType>();
        let metadata    = paired_metadata<CoinType>();

        if(option::is_some(&metadata))
        {
            let fungible_asset_supply =
                fungible_asset::supply(option::extract(&mut metadata));

            if(option::is_some(&coin_supply))
            {
                let supply = option::borrow_mut(&mut coin_supply);
                *supply = *supply +
                    option::destroy_some(fungible_asset_supply);
            };
        };

        coin_supply
    }

    /*
     * Return the symbol of the coin, usually a shorter version of the name.
     */
    #[view]
    public fun
    symbol<CoinType>() : string::String
    acquires CoinInfo
    {
        borrow_global<CoinInfo<CoinType>>(coin_address<CoinType>()).symbol
    }
}
