import 'package:starknet/starknet.dart';

/// Constants for Starknet wallet integration
class StarknetConstants {
  // Argent Account Class Hashes
  // Source: https://github.com/argentlabs/argent-contracts-starknet

  /// Argent Account class hash for Starknet mainnet
  /// This is the Cairo 1.0 implementation of Argent Account
  static final Felt ARGENT_ACCOUNT_CLASS_HASH_MAINNET = Felt.fromHexString(
    '0x01a736d6ed154502257f02b1ccdf4d9d1089f80811cd6acad48e6b6a9d1f2003'
  );

  /// Argent Account class hash for Starknet testnet (Sepolia)
  /// TODO: Update with correct testnet class hash when available
  static final Felt ARGENT_ACCOUNT_CLASS_HASH_TESTNET = Felt.fromHexString(
    '0x01a736d6ed154502257f02b1ccdf4d9d1089f80811cd6acad48e6b6a9d1f2003'
  );

  // Contract Addresses

  /// ETH token contract address on Starknet mainnet
  /// This is the native ETH wrapper contract
  static const String ETH_CONTRACT_ADDRESS =
    '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7';

  /// STRK token contract address on Starknet mainnet
  static const String STRK_CONTRACT_ADDRESS =
    '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d';

  // BIP44 Derivation

  /// Starknet coin type for BIP44 derivation
  /// Registered at: https://github.com/satoshilabs/slips/blob/master/slip-0044.md
  static const int COIN_TYPE = 9004;

  /// Standard BIP44 derivation path for Starknet (without index)
  /// Full path with index 0 would be: m/44'/9004'/0'/0/0
  static const String BIP44_PATH = "m/44'/9004'/0'/0";

  // Stark Curve Parameters

  /// Stark curve order
  /// This is the order of the STARK-friendly elliptic curve used by Starknet
  static final BigInt STARK_CURVE_ORDER = BigInt.parse(
    '800000000000010ffffffffffffffffb781126dcae7b2321e66a241adc64d2f',
    radix: 16,
  );

  /// Maximum value for key grinding (2^256)
  static final BigInt MAX_VALUE_256_BIT = BigInt.two.pow(256);

  // Guardian Configuration

  /// Default guardian value for standard accounts (no guardian)
  /// When creating an Argent account without guardian support, use this value
  static final Felt NO_GUARDIAN = Felt.fromInt(0);

  // RPC Endpoints

  /// Default mainnet RPC endpoint
  static const String DEFAULT_MAINNET_RPC =
    'https://starknet-mainnet.public.blastapi.io';

  /// Default testnet (Sepolia) RPC endpoint
  static const String DEFAULT_TESTNET_RPC =
    'https://starknet-sepolia.public.blastapi.io';

  // Fee Configuration

  /// Default max fee for deployment (0.1 ETH in wei)
  /// Used for initial fee estimation
  static final BigInt DEFAULT_DEPLOYMENT_MAX_FEE = BigInt.from(10).pow(17);

  /// Fee buffer percentage (20%)
  /// Multiplier to add buffer for fee fluctuation: actual_fee * 120 / 100
  static const int FEE_BUFFER_PERCENTAGE = 120;
  static const int FEE_BUFFER_DIVISOR = 100;

  // Transaction Configuration

  /// Maximum wait time for transaction confirmation (in seconds)
  static const int TRANSACTION_CONFIRMATION_TIMEOUT = 300; // 5 minutes

  /// Poll interval for checking transaction status (in seconds)
  static const int TRANSACTION_POLL_INTERVAL = 5;

  // Network Configuration

  /// Mainnet chain ID
  static const String MAINNET_CHAIN_ID = 'SN_MAIN';

  /// Testnet (Sepolia) chain ID
  static const String TESTNET_CHAIN_ID = 'SN_SEPOLIA';

  // Contract Selectors (commonly used)

  /// Transfer function selector (for ERC20 tokens)
  static const String TRANSFER_SELECTOR = 'transfer';

  /// BalanceOf function selector (for ERC20 tokens)
  static const String BALANCE_OF_SELECTOR = 'balanceOf';

  /// Approve function selector (for ERC20 tokens)
  static const String APPROVE_SELECTOR = 'approve';
}
