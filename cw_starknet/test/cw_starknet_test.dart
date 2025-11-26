import 'package:cw_core/transaction_direction.dart';
import 'package:cw_starknet/starknet_balance.dart';
import 'package:cw_starknet/starknet_transaction_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StarknetBalance', () {
    test('should serialize and deserialize correctly', () {
      final balance = StarknetBalance(BigInt.from(1000000000000000000)); // 1 STRK
      final json = balance.toJSON();
      final deserialized = StarknetBalance.fromJSON(json);

      expect(deserialized!.balance, balance.balance);
    });

    test('should format balance correctly', () {
      final balance = StarknetBalance(BigInt.from(1000000000000000000));
      expect(balance.formattedAvailableBalance, isNotEmpty);
      expect(balance.formattedAdditionalBalance, isNotEmpty);
    });
  });

  group('StarknetTransactionInfo', () {
    test('should serialize and deserialize correctly', () {
      final now = DateTime.now();
      final tx = StarknetTransactionInfo(
        id: '0x123',
        blockTime: now,
        amount: BigInt.from(1000000000000000000),
        txFee: BigInt.from(100000000000000),
        direction: TransactionDirection.incoming,
        isPending: false,
        to: '0xabc',
        from: '0xdef',
        tokenSymbol: 'STRK',
      );

      final json = tx.toJson();
      final deserialized = StarknetTransactionInfo.fromJson(json);

      expect(deserialized.id, tx.id);
      expect(deserialized.amount, tx.amount);
      expect(deserialized.txFee, tx.txFee);
      expect(deserialized.direction, tx.direction);
      expect(deserialized.isPending, tx.isPending);
      expect(deserialized.to, tx.to);
      expect(deserialized.from, tx.from);
      expect(deserialized.tokenSymbol, tx.tokenSymbol);
    });

    test('should format amount correctly', () {
      final tx = StarknetTransactionInfo(
        id: '0x123',
        blockTime: DateTime.now(),
        amount: BigInt.from(1000000000000000000),
        txFee: BigInt.from(100000000000000),
        direction: TransactionDirection.incoming,
        isPending: false,
        to: '0xabc',
        from: '0xdef',
      );

      expect(tx.amountFormatted(), contains('STRK'));
      expect(tx.feeFormatted(), contains('STRK'));
    });
  });
}
