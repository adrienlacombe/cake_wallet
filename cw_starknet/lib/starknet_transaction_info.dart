import 'package:cw_core/format_amount.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_info.dart';

class StarknetTransactionInfo extends TransactionInfo {
  StarknetTransactionInfo({
    required this.id,
    required this.blockTime,
    required this.to,
    required this.from,
    required this.direction,
    required BigInt amount,
    this.tokenSymbol = "STRK",
    required this.isPending,
    required this.txFee,
  }) : rawAmount = amount;

  final String id;
  final String? to;
  final String? from;
  final BigInt rawAmount;
  final bool isPending;
  final String tokenSymbol;
  final DateTime blockTime;
  final BigInt txFee;
  final TransactionDirection direction;

  String? _fiatAmount;

  @override
  int get amount => rawAmount.isValidInt ? rawAmount.toInt() : 0;

  @override
  DateTime get date => blockTime;

  @override
  String amountFormatted() {
    return '${formatAmount(rawAmount.toString())} $tokenSymbol';
  }

  @override
  String fiatAmount() => _fiatAmount ?? '';

  @override
  void changeFiatAmount(String amount) => _fiatAmount = formatAmount(amount);

  @override
  String feeFormatted() => '${formatAmount(txFee.toString())} STRK';

  factory StarknetTransactionInfo.fromJson(Map<String, dynamic> data) {
    return StarknetTransactionInfo(
      id: data['id'] as String,
      amount: BigInt.parse(data['amount'].toString()),
      direction: parseTransactionDirectionFromInt(data['direction'] as int),
      blockTime: DateTime.fromMillisecondsSinceEpoch(data['blockTime'] as int),
      isPending: data['isPending'] as bool,
      tokenSymbol: data['tokenSymbol'] as String,
      to: data['to'],
      from: data['from'],
      txFee: BigInt.parse(data['txFee'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': rawAmount.toString(),
        'direction': direction.index,
        'blockTime': blockTime.millisecondsSinceEpoch,
        'isPending': isPending,
        'tokenSymbol': tokenSymbol,
        'to': to,
        'from': from,
        'txFee': txFee.toString(),
      };
}
