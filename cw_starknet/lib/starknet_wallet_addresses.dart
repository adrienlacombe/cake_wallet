import 'package:cw_core/wallet_addresses.dart';
import 'package:cw_core/wallet_info.dart';

/// Manages addresses for a Starknet wallet
///
/// Starknet uses a single account contract address model,
/// similar to Ethereum. The address is calculated deterministically
/// from the private key and is set during wallet initialization.
class StarknetWalletAddresses extends WalletAddresses {
  StarknetWalletAddresses(
    WalletInfo walletInfo, {
    String? accountAddress,
  })  : _accountAddress = accountAddress,
        super(walletInfo);

  final String? _accountAddress;

  @override
  Future<void> init() async {
    // Use the provided account address or fall back to walletInfo.address
    address = _accountAddress ?? walletInfo.address;

    // Validate that we have an address
    if (address.isEmpty || address == '0x0') {
      throw Exception(
        'Wallet address not set. This should have been calculated during wallet initialization.',
      );
    }

    // Update walletInfo with the address if provided
    if (_accountAddress != null && walletInfo.address != _accountAddress) {
      walletInfo.address = _accountAddress!;
      await walletInfo.save();
    }
  }

  @override
  Future<void> updateAddressesInBox() async {
    // No-op for Starknet as we only have one address
    // The address is immutable and set during wallet creation
  }

  /// Validate a Starknet address format
  ///
  /// Starknet addresses are 32-byte felt values represented as hex strings
  static bool isValidAddress(String address) {
    // Remove 0x prefix if present
    final cleanAddress = address.startsWith('0x') ? address.substring(2) : address;

    // Must be hex string
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleanAddress)) {
      return false;
    }

    // Must be <= 64 characters (32 bytes)
    if (cleanAddress.length > 64) {
      return false;
    }

    return true;
  }
}
