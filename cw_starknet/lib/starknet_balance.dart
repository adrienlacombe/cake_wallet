import 'dart:convert';
import 'package:cw_core/balance.dart';
import 'package:cw_core/format_amount.dart';

class StarknetBalance extends Balance {
  StarknetBalance(this.balance) : super(balance.toInt(), balance.toInt());

  final BigInt balance;

  @override
  String get formattedAdditionalBalance => _balanceFormatted();

  @override
  String get formattedAvailableBalance => _balanceFormatted();

  String _balanceFormatted() {
    return formatAmount(balance.toString());
  }

  static StarknetBalance? fromJSON(String? jsonSource) {
    if (jsonSource == null) {
      return null;
    }

    final decoded = json.decode(jsonSource) as Map;

    try {
      return StarknetBalance(BigInt.parse(decoded['balance']));
    } catch (e) {
      return StarknetBalance(BigInt.zero);
    }
  }

  String toJSON() => json.encode({'balance': balance.toString()});
}
