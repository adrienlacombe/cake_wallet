import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/amount_converter.dart';

/// Represents a pending Starknet transaction
///
/// Supports both regular invoke transactions and account deployment transactions.
/// For auto-deployment, tracks both the deployment and invoke transaction.
class StarknetPendingTransaction extends PendingTransaction {
  StarknetPendingTransaction({
    required this.amount,
    required this.fee,
    required this.recipientAddress,
    required this.transactionHash,
    this.deploymentTxHash,
    this.isDeployment = false,
  });

  /// Amount being transferred (in wei)
  final BigInt amount;

  /// Total fee paid (deployment fee + invoke fee if auto-deployed)
  final BigInt fee;

  /// Recipient address for the transfer
  final String recipientAddress;

  /// Transaction hash of the invoke transaction
  final String transactionHash;

  /// Transaction hash of the deployment (if account was deployed)
  final String? deploymentTxHash;

  /// Whether this is a deployment-only transaction
  final bool isDeployment;

  @override
  String get id => transactionHash;

  @override
  String get amountFormatted {
    if (isDeployment) {
      return 'Account Deployment';
    }
    return AmountConverter.amountIntToString(
      CryptoCurrency.strk,
      amount.toInt(),
    );
  }

  @override
  String get feeFormatted => AmountConverter.amountIntToString(
        CryptoCurrency.strk,
        fee.toInt(),
      );

  /// Get deployment status message
  String get deploymentStatus {
    if (deploymentTxHash != null) {
      return 'Account deployed: $deploymentTxHash';
    } else if (isDeployment) {
      return 'Deploying account...';
    }
    return 'Account already deployed';
  }

  /// Whether this transaction included account deployment
  bool get hadDeployment => deploymentTxHash != null;

  @override
  Future<void> commit() async {
    // Transaction is already broadcast when created
    // Starknet transactions are submitted during createTransaction()
    // This is a no-op since we don't have a separate commit step
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('StarknetPendingTransaction(');
    buffer.writeln('  id: $id,');
    buffer.writeln('  amount: $amountFormatted,');
    buffer.writeln('  fee: $feeFormatted,');
    buffer.writeln('  to: $recipientAddress,');
    if (deploymentTxHash != null) {
      buffer.writeln('  deployment: $deploymentTxHash,');
    }
    buffer.write(')');
    return buffer.toString();
  }
}

