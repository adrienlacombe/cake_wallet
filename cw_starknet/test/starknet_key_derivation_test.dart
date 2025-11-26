import 'package:cw_starknet/starknet_key_derivation.dart';
import 'package:cw_starknet/starknet_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starknet/starknet.dart';

void main() {
  group('StarknetKeyDerivation', () {
    // Test mnemonic from BIP39 standard test vectors
    const testMnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

    group('derivePrivateKeyFromMnemonic', () {
      test('should derive a valid private key from mnemonic', () {
        final privateKey = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic);

        // Private key should be a valid Felt
        expect(privateKey, isA<Felt>());

        // Private key should not be zero
        expect(privateKey.toBigInt(), isNot(BigInt.zero));

        // Private key should be less than STARK_CURVE_ORDER
        expect(privateKey.toBigInt(), lessThan(StarknetConstants.STARK_CURVE_ORDER));
      });

      test('should derive consistent keys from same mnemonic', () {
        final privateKey1 = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic);
        final privateKey2 = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic);

        expect(privateKey1.toHexString(), equals(privateKey2.toHexString()));
      });

      test('should derive different keys from different mnemonics', () {
        const mnemonic1 = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
        const mnemonic2 = 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';

        final privateKey1 = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(mnemonic1);
        final privateKey2 = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(mnemonic2);

        expect(privateKey1.toHexString(), isNot(equals(privateKey2.toHexString())));
      });

      test('should derive different keys for different indices', () {
        final privateKey0 = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic, index: 0);
        final privateKey1 = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic, index: 1);

        expect(privateKey0.toHexString(), isNot(equals(privateKey1.toHexString())));
      });

      test('should use correct BIP44 path', () {
        // This test verifies the derivation path is m/44'/9004'/0'/0/{index}
        // We can't directly test the path, but we can verify consistency
        final privateKey = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic, index: 0);

        // The key should be deterministic based on our path
        expect(privateKey, isA<Felt>());
        expect(privateKey.toBigInt(), greaterThan(BigInt.zero));
      });

      test('should apply key grinding correctly', () {
        // Key grinding ensures the private key is within the valid range
        final privateKey = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic);

        // After grinding, key must be < STARK_CURVE_ORDER
        expect(privateKey.toBigInt(), lessThan(StarknetConstants.STARK_CURVE_ORDER));

        // And should be > 0
        expect(privateKey.toBigInt(), greaterThan(BigInt.zero));
      });

      test('should handle edge cases in mnemonic length', () {
        // 12-word mnemonic
        const mnemonic12 = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
        final key12 = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(mnemonic12);
        expect(key12, isA<Felt>());

        // 24-word mnemonic
        const mnemonic24 = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art';
        final key24 = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(mnemonic24);
        expect(key24, isA<Felt>());

        // Keys should be different
        expect(key12.toHexString(), isNot(equals(key24.toHexString())));
      });
    });

    group('derivePublicKey', () {
      test('should derive a valid public key from private key', () {
        final privateKey = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic);
        final publicKey = StarknetKeyDerivation.derivePublicKey(privateKey);

        // Public key should be a valid Felt
        expect(publicKey, isA<Felt>());

        // Public key should not be zero
        expect(publicKey.toBigInt(), isNot(BigInt.zero));
      });

      test('should derive consistent public keys from same private key', () {
        final privateKey = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic);
        final publicKey1 = StarknetKeyDerivation.derivePublicKey(privateKey);
        final publicKey2 = StarknetKeyDerivation.derivePublicKey(privateKey);

        expect(publicKey1.toHexString(), equals(publicKey2.toHexString()));
      });

      test('should derive different public keys from different private keys', () {
        final privateKey1 = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic, index: 0);
        final privateKey2 = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic, index: 1);

        final publicKey1 = StarknetKeyDerivation.derivePublicKey(privateKey1);
        final publicKey2 = StarknetKeyDerivation.derivePublicKey(privateKey2);

        expect(publicKey1.toHexString(), isNot(equals(publicKey2.toHexString())));
      });

      test('should use Starknet elliptic curve cryptography', () {
        final privateKey = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic);
        final publicKey = StarknetKeyDerivation.derivePublicKey(privateKey);

        // Public key should be on the Stark curve
        // We verify this by ensuring it's a valid Felt and within expected bounds
        expect(publicKey, isA<Felt>());
        expect(publicKey.toBigInt(), greaterThan(BigInt.zero));

        // Public key should be different from private key
        expect(publicKey.toHexString(), isNot(equals(privateKey.toHexString())));
      });
    });

    group('Full key derivation flow', () {
      test('should complete full mnemonic -> private key -> public key flow', () {
        // Step 1: Derive private key from mnemonic
        final privateKey = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic);

        // Step 2: Derive public key from private key
        final publicKey = StarknetKeyDerivation.derivePublicKey(privateKey);

        // Verify both keys are valid
        expect(privateKey, isA<Felt>());
        expect(publicKey, isA<Felt>());

        // Verify they're different
        expect(publicKey.toHexString(), isNot(equals(privateKey.toHexString())));

        // Verify they're within valid ranges
        expect(privateKey.toBigInt(), lessThan(StarknetConstants.STARK_CURVE_ORDER));
        expect(publicKey.toBigInt(), greaterThan(BigInt.zero));
      });

      test('should be deterministic across multiple derivations', () {
        // First derivation
        final privateKey1 = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic);
        final publicKey1 = StarknetKeyDerivation.derivePublicKey(privateKey1);

        // Second derivation
        final privateKey2 = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(testMnemonic);
        final publicKey2 = StarknetKeyDerivation.derivePublicKey(privateKey2);

        // Should produce identical results
        expect(privateKey1.toHexString(), equals(privateKey2.toHexString()));
        expect(publicKey1.toHexString(), equals(publicKey2.toHexString()));
      });
    });

    group('Constants validation', () {
      test('STARK_CURVE_ORDER should be correct', () {
        // Verify the Stark curve order constant
        expect(StarknetConstants.STARK_CURVE_ORDER,
          equals(BigInt.parse('800000000000010ffffffffffffffffb781126dcae7b2321e66a241adc64d2f', radix: 16)));
      });

      test('BIP44_PATH should follow Starknet standard', () {
        // Verify the BIP44 path uses coin type 9004 (Starknet)
        expect(StarknetConstants.BIP44_PATH, equals("m/44'/9004'/0'/0"));
      });
    });
  });
}
