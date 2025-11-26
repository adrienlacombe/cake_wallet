import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:crypto/crypto.dart';
import 'package:starknet/starknet.dart';
import 'package:cw_starknet/starknet_constants.dart';

/// Implements Starknet-specific BIP44 key derivation with grinding algorithm
///
/// References:
/// - https://community.starknet.io/t/account-keys-and-addresses-derivation-standard/1230
/// - https://github.com/argentlabs/argent-starknet-recover/blob/main/keyDerivation.ts
/// - https://eips.ethereum.org/EIPS/eip-2645
class StarknetKeyDerivation {
  /// Derives a Starknet private key from a mnemonic phrase
  ///
  /// This follows the Starknet BIP44 standard with key grinding:
  /// 1. Convert mnemonic to seed (BIP39)
  /// 2. Derive HD wallet path using BIP32/BIP44: m/44'/9004'/0'/0/{index}
  /// 3. Apply Starknet key grinding algorithm for uniform distribution
  /// 4. Return key modulo Stark curve order
  ///
  /// [mnemonic] - The BIP39 mnemonic phrase
  /// [index] - The account index (default: 0)
  ///
  /// Returns a Felt representing the private key suitable for Starknet
  static Felt derivePrivateKeyFromMnemonic(String mnemonic, {int index = 0}) {
    // Validate mnemonic
    if (!bip39.validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }

    // Step 1: Convert mnemonic to seed (BIP39)
    final seed = bip39.mnemonicToSeed(mnemonic);

    // Step 2: Derive HD wallet path (BIP32/BIP44)
    // Path: m/44'/9004'/0'/0/{index}
    final root = bip32.BIP32.fromSeed(seed);
    final derivationPath = "${StarknetConstants.BIP44_PATH}/$index";

    final child = root.derivePath(derivationPath);

    if (child.privateKey == null) {
      throw Exception('Failed to derive private key from path: $derivationPath');
    }

    // Step 3: Apply Starknet key grinding algorithm
    final groundPrivateKey = _grindKey(child.privateKey!);

    // Step 4: Convert to Felt
    return Felt(groundPrivateKey);
  }

  /// Derives a private key from a hex string
  /// Used for wallet restoration from private key
  ///
  /// [privateKeyHex] - The private key as a hexadecimal string (with or without 0x prefix)
  ///
  /// Returns a Felt representing the private key
  static Felt derivePrivateKeyFromHex(String privateKeyHex) {
    try {
      return Felt.fromHexString(privateKeyHex);
    } catch (e) {
      throw ArgumentError('Invalid private key format: $e');
    }
  }

  /// Derives the public key from a private key
  ///
  /// [privateKey] - The private key as a Felt
  ///
  /// Returns the corresponding public key as a Felt
  static Felt derivePublicKey(Felt privateKey) {
    try {
      final signer = Signer(privateKey: privateKey);
      return signer.publicKey;
    } catch (e) {
      throw Exception('Failed to derive public key: $e');
    }
  }

  /// Starknet key grinding algorithm
  ///
  /// Ensures uniform distribution over the Stark curve order by:
  /// 1. Calculating max_allowed = N - (N % n) where:
  ///    - N = 2^256 (max value for 256-bit number)
  ///    - n = Stark curve order
  /// 2. Hashing the key with incrementing index until result < max_allowed
  /// 3. Returning result % n
  ///
  /// This prevents bias in key distribution that would occur from naive modulo operation.
  ///
  /// [privateKeyBytes] - The derived BIP32 private key as bytes
  ///
  /// Returns the ground private key as a BigInt
  static BigInt _grindKey(Uint8List privateKeyBytes) {
    // Calculate the maximum allowed value to prevent bias
    // max_allowed = 2^256 - (2^256 % curve_order)
    final BigInt maxAllowed = StarknetConstants.MAX_VALUE_256_BIT -
        (StarknetConstants.MAX_VALUE_256_BIT % StarknetConstants.STARK_CURVE_ORDER);

    int index = 0;
    while (true) {
      // Hash the key with the current index
      final hashed = _hashKeyWithIndex(privateKeyBytes, index);

      // Check if the hashed value is below max_allowed
      if (hashed < maxAllowed) {
        // Return the key modulo the curve order
        return hashed % StarknetConstants.STARK_CURVE_ORDER;
      }

      // Increment index and try again
      index++;

      // Safety check to prevent infinite loop
      // In practice, this should succeed within a few iterations
      if (index > 10000) {
        throw Exception(
          'Key grinding failed after 10000 iterations. '
          'This indicates a problem with the grinding algorithm or input.'
        );
      }
    }
  }

  /// Hashes the private key with an index
  ///
  /// Used in the grinding algorithm to generate different candidates.
  /// The index is appended as 4 bytes in big-endian format, then SHA256 is applied.
  ///
  /// [key] - The private key bytes
  /// [index] - The grinding iteration index
  ///
  /// Returns the hash as a BigInt
  static BigInt _hashKeyWithIndex(Uint8List key, int index) {
    // Convert index to 4 bytes (big-endian)
    final indexBytes = Uint8List(4);
    indexBytes[0] = (index >> 24) & 0xFF;
    indexBytes[1] = (index >> 16) & 0xFF;
    indexBytes[2] = (index >> 8) & 0xFF;
    indexBytes[3] = index & 0xFF;

    // Concatenate key and index bytes
    final combined = Uint8List.fromList([...key, ...indexBytes]);

    // Apply SHA256 hash
    final hash = sha256.convert(combined);

    // Convert hash to BigInt
    return BigInt.parse(hash.toString(), radix: 16);
  }

  /// Validates that a private key is within the Stark curve order
  ///
  /// [privateKey] - The private key to validate
  ///
  /// Returns true if the key is valid, false otherwise
  static bool isValidPrivateKey(Felt privateKey) {
    final keyValue = privateKey.toBigInt();
    return keyValue > BigInt.zero && keyValue < StarknetConstants.STARK_CURVE_ORDER;
  }

  /// Validates that a public key is valid for Starknet
  ///
  /// [publicKey] - The public key to validate
  ///
  /// Returns true if the key is valid, false otherwise
  static bool isValidPublicKey(Felt publicKey) {
    final keyValue = publicKey.toBigInt();
    // Public key should be non-zero and within the field prime
    return keyValue > BigInt.zero && keyValue < StarknetConstants.STARK_CURVE_ORDER;
  }
}
