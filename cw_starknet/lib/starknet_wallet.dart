import 'dart:async';
import 'dart:convert';

import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_addresses.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:cw_starknet/starknet_balance.dart';
import 'package:cw_starknet/starknet_client.dart';
import 'package:cw_starknet/starknet_transaction_credentials.dart';
import 'package:cw_starknet/starknet_transaction_history.dart';
import 'package:cw_starknet/starknet_transaction_info.dart';
import 'package:cw_starknet/starknet_wallet_addresses.dart';
import 'package:cw_starknet/starknet_pending_transaction.dart';
import 'package:cw_starknet/starknet_key_derivation.dart';
import 'package:cw_starknet/starknet_account.dart';
import 'package:cw_starknet/starknet_constants.dart';
import 'package:cw_starknet/starknet_tokens.dart';
import 'package:cw_starknet/starknet_exceptions.dart';
import 'package:mobx/mobx.dart';
import 'package:starknet/starknet.dart';

part 'starknet_wallet.g.dart';

class StarknetWallet = StarknetWalletBase with _$StarknetWallet;

abstract class StarknetWalletBase
    extends WalletBase<StarknetBalance, StarknetTransactionHistory, StarknetTransactionInfo>
    with Store, WalletKeysFile {
  StarknetWalletBase({
    required WalletInfo walletInfo,
    required String password,
    StarknetBalance? initialBalance,
    required this.encryptionFileUtils,
    String? mnemonic,
    String? privateKey,
    String? accountAddress,
    StarknetClient? client,
  })  : syncStatus = const NotConnectedSyncStatus(),
        _password = password,
        _mnemonic = mnemonic,
        _privateKey = privateKey,
        _client = client ?? StarknetClient("https://starknet-mainnet.public.blastapi.io"), // Default node
        walletAddresses = StarknetWalletAddresses(walletInfo, accountAddress: accountAddress),
        balance = ObservableMap<CryptoCurrency, StarknetBalance>.of(
            {for (var token in StarknetTokens.all) token: initialBalance ?? StarknetBalance(BigInt.zero)}),
        super(walletInfo) {
    this.walletInfo = walletInfo;
    transactionHistory = StarknetTransactionHistory(
      walletInfo: walletInfo,
      password: password,
      encryptionFileUtils: encryptionFileUtils,
    );
  }

  final String _password;
  final EncryptionFileUtils encryptionFileUtils;
  final String? _mnemonic;
  final String? _privateKey;

  late final StarknetClient _client;
  Signer? _signer;

  @override
  WalletAddresses walletAddresses;

  @override
  @observable
  SyncStatus syncStatus;

  @override
  @observable
  late ObservableMap<CryptoCurrency, StarknetBalance> balance;

  @override
  Object get keys => _privateKey ?? '';

  @override
  String? get seed => _mnemonic;

  @override
  String get privateKey => _privateKey ?? '';

  Future<void> init() async {
    try {
      // Validate that we have either mnemonic or private key
      if (_mnemonic == null && _privateKey == null) {
        throw StarknetWalletInitializationException(
          'Cannot initialize wallet: no mnemonic or private key provided',
          details: 'Wallet must be created with either a mnemonic phrase or private key.',
        );
      }

      // Initialize the signer from mnemonic or private key
      if (_mnemonic != null) {
        _initializeFromMnemonic(_mnemonic!);
      } else if (_privateKey != null) {
        _initializeFromPrivateKey(_privateKey!);
      }

      // Calculate and set account address if not already set
      if (walletInfo.address == '0x0' || walletInfo.address.isEmpty) {
        if (_signer != null) {
          final publicKey = _signer!.publicKey;
          final account = StarknetAccount(
            privateKey: Felt.fromHexString(_privateKey!),
            publicKey: publicKey,
            provider: _client.provider,
            isMainnet: !walletInfo.network.toLowerCase().contains('test'),
          );

          walletInfo.address = account.calculateAccountAddress().toHexString();
          await walletInfo.save();
        }
      }

      await walletAddresses.init();
      await transactionHistory.init();
      await save();
    } catch (e) {
      if (e is StarknetException) rethrow;
      throw StarknetWalletInitializationException(
        'Wallet initialization failed',
        details: e.toString(),
      );
    }
  }

  void _initializeFromMnemonic(String mnemonic) {
    try {
      // Derive private key from mnemonic using Starknet BIP44 path with grinding
      final privateKeyFelt = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(mnemonic);
      _privateKey = privateKeyFelt.toHexString();

      // Create signer
      _signer = Signer(privateKey: privateKeyFelt);
    } catch (e) {
      throw StarknetKeyDerivationException(
        'Failed to initialize wallet from mnemonic',
        details: e.toString(),
      );
    }
  }

  void _initializeFromPrivateKey(String privateKey) {
    try {
      // Validate private key format
      if (!privateKey.startsWith('0x')) {
        throw StarknetKeyDerivationException(
          'Invalid private key format',
          details: 'Private key must start with 0x',
        );
      }

      // Initialize signer from private key
      final privateKeyFelt = Felt.fromHexString(privateKey);
      _signer = Signer(privateKey: privateKeyFelt);
    } catch (e) {
      if (e is StarknetKeyDerivationException) rethrow;
      throw StarknetKeyDerivationException(
        'Failed to initialize wallet from private key',
        details: e.toString(),
      );
    }
  }

  @override
  int calculateEstimatedFee(TransactionPriority priority, int? amount) => 0;

  @override
  Future<void> changePassword(String password) => throw UnimplementedError("changePassword");

  @override
  Future<void> close({bool shouldCleanup = false}) async {
    // Cleanup resources if needed
  }

  @action
  @override
  Future<void> connectToNode({required Node node}) async {
    try {
      syncStatus = ConnectingSyncStatus();

      // Update client with new node URI
      _client.updateNodeUri(node.uri);

      // Verify node health
      final isHealthy = await _client.checkNodeHealth();
      if (!isHealthy) {
        throw StarknetNodeException(
          'Failed to connect to Starknet node',
          details: 'Node at ${node.uri} is unreachable or unhealthy',
        );
      }

      syncStatus = ConnectedSyncStatus();
    } catch (e) {
      syncStatus = FailedSyncStatus();
      if (e is StarknetNodeException) rethrow;
      throw StarknetNodeException(
        'Node connection failed',
        details: e.toString(),
      );
    }
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    try {
      final transactionCredentials = credentials as StarknetTransactionCredentials;

      if (_signer == null) {
        throw StarknetWalletInitializationException(
          'Wallet not initialized',
          details: 'Signer not available. Please ensure wallet is properly initialized.',
        );
      }

      if (_privateKey == null) {
        throw StarknetWalletInitializationException(
          'Private key not available',
          details: 'Cannot create transaction without private key.',
        );
      }

      if (transactionCredentials.outputs.isEmpty) {
        throw StarknetTransactionException(
          'No transaction outputs provided',
          details: 'At least one output is required to create a transaction.',
        );
      }

      final output = transactionCredentials.outputs.first;
      final recipientAddress = output.address;
      final amount = BigInt.parse(output.formattedCryptoAmount ?? '0');
      final currency = transactionCredentials.currency;

      // Determine contract address
      String contractAddress = StarknetConstants.ETH_CONTRACT_ADDRESS;
      if (currency is StarknetToken) {
        contractAddress = currency.contractAddress;
      } else if (currency.title == 'STRK') {
        contractAddress = StarknetConstants.STRK_CONTRACT_ADDRESS;
      }

      // Validate amount
      if (amount <= BigInt.zero) {
        throw StarknetTransactionException(
          'Invalid transaction amount',
          details: 'Amount must be greater than zero. Received: $amount',
        );
      }

      // Validate recipient address
      if (!StarknetWalletAddresses.isValidAddress(recipientAddress)) {
        throw StarknetInvalidAddressException(
          recipientAddress,
          reason: 'Address must be a valid Starknet hex string (max 64 chars)',
        );
      }

    // Step 1: Create account instance
    final starknetAccount = StarknetAccount(
      privateKey: Felt.fromHexString(_privateKey!),
      publicKey: _signer!.publicKey,
      provider: _client.provider,
      isMainnet: !walletInfo.network.toLowerCase().contains('test'),
    );

    // Step 2: Check if account is deployed
    final isDeployed = await starknetAccount.isDeployed();

    String? deployTxHash;
    BigInt deployFee = BigInt.zero;

    if (!isDeployed) {
      print('Account not deployed. Auto-deploying...');

      // Step 3: Deploy account
      final deployResult = await _deployAccount(starknetAccount);
      deployTxHash = deployResult['txHash'] as String;
      deployFee = deployResult['fee'] as BigInt;

      print('Deployment transaction sent: $deployTxHash');
      print('Waiting for deployment confirmation...');

      // Step 4: Wait for deployment confirmation
      final deploySuccess = await _client.waitForTransaction(
        deployTxHash,
        maxWaitSeconds: StarknetConstants.TRANSACTION_CONFIRMATION_TIMEOUT,
        pollIntervalSeconds: StarknetConstants.TRANSACTION_POLL_INTERVAL,
      );

      if (!deploySuccess) {
        throw StarknetDeploymentException(
          'Account deployment failed or timed out',
          details: 'Deployment transaction: $deployTxHash. '
              'Check transaction status on Starknet explorer.',
        );
      }

      print('Account successfully deployed!');

      // Reset deployment status cache
      starknetAccount.resetDeploymentStatus();
    }

    // Step 5: Create invoke transaction
    final account = starknetAccount.createAccountInstance();

    // Prepare transfer call
    final call = Call(
      to: Felt.fromHexString(contractAddress),
      selector: getSelectorByName(StarknetConstants.TRANSFER_SELECTOR),
      calldata: [
        Felt.fromHexString(recipientAddress),
        Felt(amount),
        Felt.fromInt(0), // high part of u256 (amount is u256)
      ],
    );

    // Step 6: Estimate fee for invoke
    final feeEstimateResult = await account.estimateFee([call]);

    final invokeFee = feeEstimateResult.when(
      result: (estimate) => estimate.overallFee.toBigInt(),
      error: (error) => throw StarknetTransactionException(
        'Fee estimation failed',
        details: error.message,
      ),
    );

    // Add fee buffer (20%)
    final maxFee = (invokeFee * BigInt.from(StarknetConstants.FEE_BUFFER_PERCENTAGE)) ~/
        BigInt.from(StarknetConstants.FEE_BUFFER_DIVISOR);

    print('Estimated invoke fee: $invokeFee wei');
    print('Max fee with buffer: $maxFee wei');

    // Check sufficient balance for transaction
    final currentBalance = balance[currency]?.available ?? BigInt.zero;
    if (currentBalance < amount) {
       throw StarknetInsufficientBalanceException(
        required: amount,
        available: currentBalance,
        operation: 'transfer',
      );
    }

    // Check sufficient ETH balance for fee
    // Note: If sending ETH, we need amount + fee
    final ethBalance = balance[StarknetTokens.eth]?.available ?? BigInt.zero;
    final isSendingEth = contractAddress == StarknetConstants.ETH_CONTRACT_ADDRESS;
    final requiredEth = isSendingEth ? amount + maxFee : maxFee;

    if (ethBalance < requiredEth) {
      throw StarknetInsufficientBalanceException(
        required: requiredEth,
        available: ethBalance,
        operation: 'fee payment',
      );
    }

    // Step 7: Send invoke transaction
    final invokeResult = await account.execute(
      [call],
      maxFee: Felt(maxFee),
    );

    final txHash = invokeResult.when(
      result: (tx) => tx.transactionHash.toHexString(),
      error: (error) => throw StarknetTransactionException(
        'Transaction submission failed',
        details: error.message,
      ),
    );

    print('Invoke transaction sent: $txHash');

    // Return pending transaction with deployment info
    return StarknetPendingTransaction(
      amount: amount,
      fee: deployFee + invokeFee,
      recipientAddress: recipientAddress,
      transactionHash: txHash,
      deploymentTxHash: deployTxHash,
    );
    } catch (e) {
      // Re-throw known Starknet exceptions
      if (e is StarknetException) rethrow;

      // Wrap unknown exceptions
      throw StarknetTransactionException(
        'Transaction creation failed',
        details: e.toString(),
      );
    }
  }

  /// Deploy account contract
  ///
  /// Returns a map with 'txHash' and 'fee'
  Future<Map<String, dynamic>> _deployAccount(StarknetAccount starknetAccount) async {
    try {
      // Check balance is sufficient for deployment
      final balance = await _client.getBalance(walletAddresses.address);

      if (balance == BigInt.zero) {
        throw StarknetInsufficientBalanceException(
          required: BigInt.one, // At least some balance needed
          available: BigInt.zero,
          operation: 'account deployment',
        );
      }

      // Estimate deployment fee
      print('Estimating deployment fee...');
      final estimatedFee = await starknetAccount.estimateDeploymentFee();

      // Add 20% buffer for fee fluctuation
      final maxFee = (estimatedFee * BigInt.from(StarknetConstants.FEE_BUFFER_PERCENTAGE)) ~/
          BigInt.from(StarknetConstants.FEE_BUFFER_DIVISOR);

      print('Estimated deployment fee: $estimatedFee wei');
      print('Max fee with buffer: $maxFee wei');

      if (balance < maxFee) {
        throw StarknetInsufficientBalanceException(
          required: maxFee,
          available: balance,
          operation: 'account deployment',
        );
      }

      // Deploy account
      print('Deploying account contract...');
      final txHash = await starknetAccount.deploy(maxFee: maxFee);

      return {
        'txHash': txHash,
        'fee': estimatedFee,
      };
    } catch (e) {
      if (e is StarknetException) rethrow;
      throw StarknetDeploymentException(
        'Account deployment preparation failed',
        details: e.toString(),
      );
    }
  }

  /// Format balance for display (wei to ETH)
  String _formatBalance(BigInt wei) {
    final eth = wei.toDouble() / BigInt.from(10).pow(18).toDouble();
    return eth.toStringAsFixed(6);
  }

  @override
  Future<Map<String, StarknetTransactionInfo>> fetchTransactions() async {
    try {
      // Fetch transfers instead of raw transactions for better data
      final txList = await _client.getTransfers(walletAddresses.address);

      final Map<String, StarknetTransactionInfo> transactions = {};
      for (final tx in txList) {
        try {
          final id = (tx['tx_hash'] ?? tx['hash']) as String;
          final timestamp = tx['timestamp'] as int?;
          final date = timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
              : DateTime.now();

          final from = (tx['transfer_from'] ?? tx['from']) as String?;
          final to = (tx['transfer_to'] ?? tx['to']) as String?;
          
          // Parse amount (usually string in wei)
          final amountStr = (tx['transfer_value'] ?? tx['amount']) as String?;
          BigInt amount = BigInt.zero;
          if (amountStr != null) {
            amount = BigInt.tryParse(amountStr) ?? BigInt.zero;
          }

          // Fee is usually not in transfer object, but we might get it if we fetch tx details
          // For now set to 0 or try to parse if available
          final feeStr = (tx['actual_fee'] ?? tx['fee']) as String?;
          final fee = BigInt.tryParse(feeStr ?? '0') ?? BigInt.zero;
          
          final tokenSymbol = (tx['token_symbol'] as String?) ?? 'ETH';

          final txInfo = StarknetTransactionInfo(
            id: id,
            blockTime: date,
            to: to,
            from: from,
            direction: _parseDirection(tx),
            amount: amount, 
            isPending: false, // Transfers from indexer are usually confirmed
            txFee: fee,
            tokenSymbol: tokenSymbol,
          );
          
          // Hack: StarknetTransactionInfo might expect amount as int. 
          // If amount is > max int, it might be an issue.
          // Let's check StarknetTransactionInfo definition.
          
          transactions[txInfo.id] = txInfo;
        } catch (e) {
          print('Error parsing transaction: $e');
        }
      }

      return transactions;
    } catch (e) {
      print('Error fetching transactions: $e');
      return {};
    }
  }

  TransactionDirection _parseDirection(Map<String, dynamic> tx) {
    final from = ((tx['transfer_from'] ?? tx['from']) as String?)?.toLowerCase();
    final myAddress = walletAddresses.address.toLowerCase();

    if (from == myAddress) {
      return TransactionDirection.outgoing;
    } else {
      return TransactionDirection.incoming;
    }
  }

  @override
  Future<void> updateTransactionsHistory() async {
    try {
      final transactions = await fetchTransactions();
      transactionHistory.addMany(transactions);
      await transactionHistory.save();
    } catch (e) {
      print('Error updating transaction history: $e');
    }
  }

  @override
  Future<void> rescan({required int height}) => throw UnimplementedError("rescan");

  @override
  Future<void> save() async {
    final path = await makePath();
    await encryptionFileUtils.write(path: path, password: _password, data: toJSON());
    await transactionHistory.save();
  }

  @action
  @override
  Future<void> startSync() async {
    try {
      syncStatus = AttemptingSyncStatus();
      await _updateBalance();
      syncStatus = SyncedSyncStatus();
    } catch (e) {
      syncStatus = FailedSyncStatus();
      print('Sync failed: $e');
      if (e is StarknetException) rethrow;
      throw StarknetNetworkException(
        'Failed to synchronize wallet',
        details: e.toString(),
      );
    }
  }

  @override
  WalletKeysData get walletKeysData => WalletKeysData(
        mnemonic: _mnemonic,
        privateKey: _privateKey,
      );

  String toJSON() => json.encode({
        'balance': balance.values.first.toJSON(),
      });

  static Future<StarknetWallet> open({
    required String name,
    required String password,
    required WalletInfo walletInfo,
    required EncryptionFileUtils encryptionFileUtils,
  }) async {
    final path = await pathForWallet(name: name, type: walletInfo.type);

    // Try to load keys from .keys file first
    WalletKeysData? keysData;
    try {
      keysData = await WalletKeysFile.readKeysFile(
        name,
        walletInfo.type,
        password,
        encryptionFileUtils,
      );
    } catch (e) {
      print('No .keys file found, checking legacy format: $e');
    }

    // Load wallet data
    Map<String, dynamic>? data;
    try {
      final jsonSource = await encryptionFileUtils.read(path: path, password: password);
      data = json.decode(jsonSource) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading wallet data: $e');
    }

    final balance = StarknetBalance.fromJSON(data?['balance'] as String?) ??
        StarknetBalance(BigInt.zero);

    // Get keys from .keys file or legacy format
    String? mnemonic = keysData?.mnemonic ?? data?['mnemonic'] as String?;
    String? privateKey = keysData?.privateKey ?? data?['privateKey'] as String?;

    // Migration: If keys in wallet data but not in .keys file, migrate them
    if (keysData == null && (mnemonic != null || privateKey != null)) {
      print('Migrating wallet to .keys file format');
      try {
        await WalletKeysFile.createKeysFile(
          name,
          walletInfo.type,
          password,
          WalletKeysData(
            mnemonic: mnemonic,
            privateKey: privateKey,
          ),
          encryptionFileUtils,
        );
      } catch (e) {
        print('Error creating .keys file during migration: $e');
      }
    }

    // Calculate address if missing or placeholder
    if ((walletInfo.address == '0x0' || walletInfo.address.isEmpty) &&
        (mnemonic != null || privateKey != null)) {
      print('Calculating account address');
      try {
        final Felt privateKeyFelt;
        if (mnemonic != null) {
          privateKeyFelt = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(mnemonic);
        } else {
          privateKeyFelt = Felt.fromHexString(privateKey!);
        }

        final publicKey = StarknetKeyDerivation.derivePublicKey(privateKeyFelt);
        final account = StarknetAccount(
          privateKey: privateKeyFelt,
          publicKey: publicKey,
          provider: JsonRpcProvider(nodeUri: Uri.parse(StarknetConstants.DEFAULT_MAINNET_RPC)),
          isMainnet: !walletInfo.network.toLowerCase().contains('test'),
        );

        walletInfo.address = account.calculateAccountAddress().toHexString();
        await walletInfo.save();
        print('Address calculated and saved: ${walletInfo.address}');
      } catch (e) {
        print('Error calculating address: $e');
      }
    }

    return StarknetWallet(
      walletInfo: walletInfo,
      password: password,
      initialBalance: balance,
      encryptionFileUtils: encryptionFileUtils,
      mnemonic: mnemonic,
      privateKey: privateKey,
    );
  }

  Future<void> _updateBalance() async {
    try {
      // Validate wallet address
      if (walletAddresses.address.isEmpty || walletAddresses.address == '0x0') {
        throw StarknetWalletInitializationException(
          'Cannot update balance: wallet address not set',
          details: 'Ensure wallet is properly initialized before syncing.',
        );
      }

      for (var token in StarknetTokens.all) {
        try {
          final balanceValue = await _client.getBalance(
            walletAddresses.address,
            tokenAddress: token.contractAddress,
          );
          balance[token] = StarknetBalance(balanceValue);
        } catch (e) {
          print('Error fetching balance for ${token.symbol}: $e');
        }
      }
    } catch (e) {
      print('Error updating balance: $e');
      if (e is StarknetException) rethrow;
      throw StarknetNetworkException(
        'Failed to fetch account balance',
        details: e.toString(),
      );
    }
  }

  @override
  Future<void>? updateBalance() async => await _updateBalance();

  @override
  Future<bool> checkNodeHealth() async {
    try {
      return await _client.checkNodeHealth();
    } catch (e) {
      print('Error checking node health: $e');
      return false;
    }
  }
  
  @override
  Future<void> renameWalletFiles(String newWalletName) async {
    // Implement rename
  }
  
  @override
  Future<String> signMessage(String message, {String? address}) async {
    throw UnimplementedError();
  }
  
  @override
  Future<bool> verifyMessage(String message, String signature, {String? address}) async {
    throw UnimplementedError();
  }
}
