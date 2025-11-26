import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_starknet/starknet_balance.dart';
import 'package:cw_starknet/starknet_client.dart';
import 'package:cw_starknet/starknet_tokens.dart';
import 'package:cw_starknet/starknet_wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cw_core/encryption_file_utils.dart';

// Create a MockClient manually since we can't run build_runner easily
class MockStarknetClient extends Mock implements StarknetClient {
  @override
  Future<BigInt> getBalance(String address, {String? tokenAddress}) async {
    if (tokenAddress == null || tokenAddress == StarknetTokens.eth.contractAddress) {
      return BigInt.from(1000000000000000000); // 1 ETH
    }
    return BigInt.zero;
  }

  @override
  Future<List<Map<String, dynamic>>> getTransfers(String address, {int limit = 50}) async {
    return [
      {
        'tx_hash': '0x123',
        'timestamp': 1600000000,
        'transfer_from': '0xsender',
        'transfer_to': address,
        'transfer_value': '1000000000000000000',
        'token_symbol': 'ETH',
        'actual_fee': '100000000000000'
      }
    ];
  }
}

class MockEncryptionFileUtils extends Mock implements EncryptionFileUtils {
    @override
    Future<void> write({required String path, required String password, required String data}) async {}
}

void main() {
  group('StarknetWallet', () {
    late StarknetWallet wallet;
    late MockStarknetClient mockClient;
    late WalletInfo walletInfo;
    late MockEncryptionFileUtils mockFileUtils;

    setUp(() {
      mockClient = MockStarknetClient();
      mockFileUtils = MockEncryptionFileUtils();
      walletInfo = WalletInfo(
        id: 'test_wallet',
        name: 'Test Wallet',
        type: WalletType.starknet,
        isRecovery: false,
        networkId: 'mainnet',
      );
      walletInfo.address = '0xmyaddress';

      wallet = StarknetWallet(
        walletInfo: walletInfo,
        password: 'password',
        encryptionFileUtils: mockFileUtils,
        client: mockClient,
        accountAddress: '0xmyaddress',
        privateKey: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // Mock private key
      );
    });

    test('should initialize with correct tokens', () {
      expect(wallet.balance.keys, containsAll(StarknetTokens.all));
    });

    test('should update balance correctly', () async {
      await wallet.updateBalance();
      
      // ETH should be updated from mock
      expect(wallet.balance[StarknetTokens.eth]?.balance, BigInt.from(1000000000000000000));
      
      // Others should be zero (default mock response)
      expect(wallet.balance[StarknetTokens.usdc]?.balance, BigInt.zero);
    });

    test('should fetch and parse transactions correctly', () async {
      final transactions = await wallet.fetchTransactions();
      
      expect(transactions.length, 1);
      final tx = transactions.values.first;
      
      expect(tx.id, '0x123');
      expect(tx.amountFormatted(), contains('1.0 ETH'));
      expect(tx.tokenSymbol, 'ETH');
      expect(tx.direction, isNotNull);
    });
  });
}
