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
     * VIEW FUNCTIONS
     *
     **************************************************************************/

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
}
