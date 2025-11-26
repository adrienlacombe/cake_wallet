import 'package:starknet/starknet.dart';
import 'package:cw_starknet/starknet_constants.dart';
import 'package:cw_starknet/starknet_exceptions.dart';

import 'package:cw_starknet/starknet_explorer_api.dart';

/// Client for interacting with Starknet blockchain via JSON-RPC
///
/// Provides methods for:
/// - Balance queries
/// - Transaction management
/// - Account deployment checks
/// - Fee estimation
class StarknetClient {
  StarknetClient(String nodeUri, {StarknetExplorerApi? explorerApi}) : _nodeUri = nodeUri {
    provider = JsonRpcProvider(nodeUri: Uri.parse(nodeUri));
    _explorerApi = explorerApi ?? StarknetExplorerApi();
  }

  String _nodeUri;
  late JsonRpcProvider provider;
  late final StarknetExplorerApi _explorerApi;

  /// Update the RPC node URI
  void updateNodeUri(String newNodeUri) {
    _nodeUri = newNodeUri;
    provider = JsonRpcProvider(nodeUri: Uri.parse(newNodeUri));
  }

  /// Get the current block height
  Future<int> getBlockHeight() async {
    try {
      final block = await provider.blockNumber();
      return block.when(
        result: (result) => result,
        error: (error) => throw StarknetNetworkException(
          'Failed to get block height',
          details: error.message,
        ),
      );
    } catch (e) {
      if (e is StarknetException) rethrow;
      throw StarknetNetworkException(
        'Failed to communicate with Starknet node',
        details: e.toString(),
      );
    }
  }

  /// Get balance for an address
  ///
  /// [address] - The account address
  /// [tokenAddress] - Optional ERC20 token contract address (defaults to ETH)
  Future<BigInt> getBalance(String address, {String? tokenAddress}) async {
    try {
      final accountAddress = Felt.fromHexString(address);
      final contractAddress = tokenAddress != null
          ? Felt.fromHexString(tokenAddress)
          : Felt.fromHexString(StarknetConstants.ETH_CONTRACT_ADDRESS);

      final result = await provider.call(
        request: FunctionCall(
          contractAddress: contractAddress,
          entryPointSelector: getSelectorByName(StarknetConstants.BALANCE_OF_SELECTOR),
          calldata: [accountAddress],
        ),
        blockId: BlockId.latest,
      );

      return result.when(
        result: (result) {
          if (result.isEmpty) return BigInt.zero;
          // Balance is returned as u256 (low, high)
          return result[0].toBigInt();
        },
        error: (error) {
          print('Error fetching balance: ${error.message}');
          return BigInt.zero;
        },
      );
    } catch (e) {
      print('Exception in getBalance: $e');
      return BigInt.zero;
    }
  }

  /// Check if an account is deployed on-chain
  ///
  /// [address] - The account address to check
  Future<bool> checkAccountDeployed(String address) async {
    try {
      final accountAddress = Felt.fromHexString(address);

      final result = await provider.getClassHashAt(
        contractAddress: accountAddress,
        blockId: BlockId.latest,
      );

      return result.when(
        result: (classHash) => classHash != Felt.fromInt(0),
        error: (_) => false,
      );
    } catch (e) {
      print('Error checking account deployment: $e');
      return false;
    }
  }

  /// Get the nonce for an account
  ///
  /// [address] - The account address
  Future<BigInt> getNonce(String address) async {
    try {
      final accountAddress = Felt.fromHexString(address);

      final result = await provider.getNonce(
        contractAddress: accountAddress,
        blockId: BlockId.latest,
      );

      return result.when(
        result: (nonce) => nonce.toBigInt(),
        error: (_) => BigInt.zero,
      );
    } catch (e) {
      print('Error getting nonce: $e');
      return BigInt.zero;
    }
  }

  /// Get transaction receipt
  ///
  /// [txHash] - The transaction hash
  Future<Map<String, dynamic>?> getTransactionReceipt(String txHash) async {
    try {
      final result = await provider.getTransactionReceipt(
        transactionHash: Felt.fromHexString(txHash),
      );

      return result.when(
        result: (receipt) => {
          'status': receipt.finalityStatus.toString(),
          'execution_status': receipt.executionStatus.toString(),
          'block_hash': receipt.blockHash?.toHexString(),
          'block_number': receipt.blockNumber?.toString(),
          'actual_fee': receipt.actualFee?.toString(),
          'transaction_hash': receipt.transactionHash.toHexString(),
        },
        error: (error) {
          print('Error getting transaction receipt: ${error.message}');
          return null;
        },
      );
    } catch (e) {
      print('Exception in getTransactionReceipt: $e');
      return null;
    }
  }

  /// Get transaction status
  ///
  /// [txHash] - The transaction hash
  /// Returns status string or null if not found
  Future<String?> getTransactionStatus(String txHash) async {
    final receipt = await getTransactionReceipt(txHash);
    if (receipt == null) return null;

    final finality = receipt['status'] as String?;
    final execution = receipt['execution_status'] as String?;

    // Check execution status first
    if (execution == 'EXECUTION_STATUS_REVERTED' || execution == 'REVERTED') {
      return 'REJECTED';
    }

    // Return finality status
    return finality;
  }

  /// Wait for transaction to be accepted
  ///
  /// [txHash] - The transaction hash
  /// [maxWaitSeconds] - Maximum time to wait
  /// Returns true if accepted, false if rejected or timeout
  Future<bool> waitForTransaction(
    String txHash, {
    int maxWaitSeconds = 300,
    int pollIntervalSeconds = 5,
  }) async {
    final startTime = DateTime.now();

    while (true) {
      final elapsed = DateTime.now().difference(startTime).inSeconds;
      if (elapsed > maxWaitSeconds) {
        print('Transaction wait timeout after $maxWaitSeconds seconds');
        return false;
      }

      final status = await getTransactionStatus(txHash);

      if (status != null) {
        if (status.contains('ACCEPTED_ON_L2') || status.contains('ACCEPTED_ON_L1')) {
          return true;
        } else if (status.contains('REJECTED')) {
          print('Transaction was rejected: $txHash');
          return false;
        }
      }

      await Future.delayed(Duration(seconds: pollIntervalSeconds));
    }
  }

  /// Estimate fee for an invoke transaction
  ///
  /// Note: This is a simplified version. Full implementation would use
  /// the account's estimateFee method after creating an Account instance.
  Future<BigInt> estimateFee(
    String accountAddress,
    List<Call> calls,
  ) async {
    try {
      // Convert calls to InvokeFunctionCall format
      final invokeCalls = calls.map((call) => InvokeFunctionCall(
        contractAddress: call.to,
        entryPointSelector: call.selector,
        calldata: call.calldata,
      )).toList();

      final result = await provider.estimateFee(
        request: invokeCalls,
        blockId: BlockId.latest,
      );

      return result.when(
        result: (estimates) {
          if (estimates.isEmpty) return BigInt.zero;
          return estimates.first.overallFee.toBigInt();
        },
        error: (error) {
          print('Fee estimation error: ${error.message}');
          return BigInt.zero;
        },
      );
    } catch (e) {
      print('Exception in estimateFee: $e');
      return BigInt.zero;
    }
  }

  /// Get transactions for an address
  ///
  /// Uses Voyager API to fetch transaction history
  Future<List<Map<String, dynamic>>> getTransactionsByAddress(
    String address, {
    int limit = 50,
  }) async {
    return _explorerApi.getTransactions(address, pageSize: limit);
  }

  /// Get transfers for an address
  Future<List<Map<String, dynamic>>> getTransfers(
    String address, {
    int limit = 50,
  }) async {
    return _explorerApi.getTransfers(address, pageSize: limit);
  }

  /// Get the chain ID
  Future<String> getChainId() async {
    try {
      final result = await provider.chainId();
      return result.when(
        result: (chainId) => chainId,
        error: (error) => throw Exception('Failed to get chain ID: ${error.message}'),
      );
    } catch (e) {
      print('Exception in getChainId: $e');
      rethrow;
    }
  }

  /// Check node health
  Future<bool> checkNodeHealth() async {
    try {
      await getBlockHeight();
      return true;
    } catch (e) {
      print('Node health check failed: $e');
      return false;
    }
  }
}
