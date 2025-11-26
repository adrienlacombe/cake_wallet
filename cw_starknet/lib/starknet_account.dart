import 'package:starknet/starknet.dart';
import 'package:cw_starknet/starknet_constants.dart';

/// Encapsulates Argent account abstraction logic for Starknet
///
/// Handles:
/// - Deterministic account address calculation
/// - Account deployment status checking
/// - Deployment transaction creation
/// - Account instance creation for signing
///
/// References:
/// - https://github.com/argentlabs/argent-contracts-starknet
/// - https://docs.starknet.io/architecture-and-concepts/accounts/deploying-new-accounts/
class StarknetAccount {
  final Felt privateKey;
  final Felt publicKey;
  final JsonRpcProvider provider;
  final bool isMainnet;

  Felt? _accountAddress;
  bool? _isDeployed;

  StarknetAccount({
    required this.privateKey,
    required this.publicKey,
    required this.provider,
    this.isMainnet = true,
  });

  /// Calculate the Argent account address deterministically
  ///
  /// The address is calculated before deployment using:
  /// - Argent account class hash (network-specific)
  /// - Constructor calldata: [owner_public_key, guardian]
  /// - Salt for deterministic deployment
  ///
  /// This allows users to receive funds before deploying the account.
  ///
  /// [salt] - Salt for address calculation (default: 0)
  ///
  /// Returns the calculated account address as a Felt
  Felt calculateAccountAddress({int salt = 0}) {
    if (_accountAddress != null) return _accountAddress!;

    // Get the appropriate class hash for the network
    final classHash = isMainnet
        ? StarknetConstants.ARGENT_ACCOUNT_CLASS_HASH_MAINNET
        : StarknetConstants.ARGENT_ACCOUNT_CLASS_HASH_TESTNET;

    // Constructor calldata for Argent account
    // Format: [owner, guardian]
    // - owner: The public key that controls the account (signer)
    // - guardian: Additional security feature (0 for standard accounts without guardians)
    final constructorCalldata = [
      publicKey, // owner (signer public key)
      StarknetConstants.NO_GUARDIAN, // guardian (0 = no guardian)
    ];

    // Calculate contract address using Starknet's deterministic formula
    // This uses the Starknet contract address calculation:
    // address = pedersen(
    //   "STARKNET_CONTRACT_ADDRESS",
    //   deployer_address,  // 0 for counterfactual deployment
    //   salt,
    //   class_hash,
    //   pedersen_hash(constructor_calldata)
    // )
    try {
      // Calculate the contract address using the starknet package's computeAddress function
      // Note: This is a simplified calculation - in production, use the proper
      // calculateContractAddressFromHash function from the starknet package
      _accountAddress = computeAddress(
        classHash: classHash,
        constructorCalldata: constructorCalldata,
        salt: Felt.fromInt(salt),
      );

      return _accountAddress!;
    } catch (e) {
      throw Exception('Failed to calculate account address: $e');
    }
  }

  /// Check if the account is already deployed on-chain
  ///
  /// Queries the blockchain to determine if the account contract exists
  /// at the calculated address.
  ///
  /// Returns true if deployed, false otherwise
  Future<bool> isDeployed() async {
    if (_isDeployed != null) return _isDeployed!;

    try {
      final address = calculateAccountAddress();

      // Check if the account has code deployed by getting its class hash
      final result = await provider.getClassHashAt(
        contractAddress: address,
        blockId: BlockId.blockTag("latest"),
      );

      _isDeployed = result.when(
        result: (classHash) {
          // If class hash is not zero, the account is deployed
          return classHash != Felt.fromInt(0);
        },
        error: (error) {
          // If we get an error, assume not deployed
          // Common error: "Contract not found"
          return false;
        },
      );

      return _isDeployed!;
    } catch (e) {
      // On any exception, assume not deployed
      print('Error checking deployment status: $e');
      _isDeployed = false;
      return false;
    }
  }

  /// Create a DEPLOY_ACCOUNT transaction
  ///
  /// This transaction deploys the Argent account contract to the blockchain.
  /// It must be sent before the first invoke transaction.
  ///
  /// [maxFee] - Maximum fee willing to pay for deployment
  ///
  /// Returns a DeployAccountTransactionRequest ready to be signed and sent
  Future<DeployAccountTransactionRequest> createDeployTransaction({
    required BigInt maxFee,
  }) async {
    final address = calculateAccountAddress();
    final classHash = isMainnet
        ? StarknetConstants.ARGENT_ACCOUNT_CLASS_HASH_MAINNET
        : StarknetConstants.ARGENT_ACCOUNT_CLASS_HASH_TESTNET;

    final constructorCalldata = [
      publicKey,
      StarknetConstants.NO_GUARDIAN,
    ];

    // Get nonce (should be 0 for undeployed account)
    final nonce = await _getNonce(address);

    return DeployAccountTransactionRequest(
      classHash: classHash,
      contractAddressSalt: Felt.fromInt(0),
      constructorCalldata: constructorCalldata,
      nonce: nonce,
      maxFee: Felt(maxFee),
    );
  }

  /// Create an Account instance for signing and sending transactions
  ///
  /// This creates a fully configured Account object that can:
  /// - Sign transactions
  /// - Estimate fees
  /// - Send transactions
  /// - Deploy the account contract
  ///
  /// Returns an Account instance ready to use
  Account createAccountInstance() {
    final signer = Signer(privateKey: privateKey);
    final address = calculateAccountAddress();

    // Determine chain ID based on network
    final chainId = isMainnet
        ? Felt.fromHexString("0x534e5f4d41494e") // SN_MAIN
        : Felt.fromHexString("0x534e5f5345504f4c4941"); // SN_SEPOLIA

    return Account(
      provider: provider,
      signer: signer,
      accountAddress: address,
      chainId: chainId,
    );
  }

  /// Get the current nonce for the account
  ///
  /// The nonce is used to ensure transaction ordering and prevent replay attacks.
  /// For undeployed accounts, this will be 0.
  ///
  /// [address] - The account address to query
  ///
  /// Returns the current nonce as a Felt
  Future<Felt> _getNonce(Felt address) async {
    try {
      final result = await provider.getNonce(
        contractAddress: address,
        blockId: BlockId.blockTag("latest"),
      );

      return result.when(
        result: (nonce) => nonce,
        error: (error) {
          // If account is not deployed, nonce is 0
          return Felt.fromInt(0);
        },
      );
    } catch (e) {
      // On any error, return 0 (common for undeployed accounts)
      return Felt.fromInt(0);
    }
  }

  /// Estimate the fee for deploying this account
  ///
  /// Returns the estimated fee in wei
  Future<BigInt> estimateDeploymentFee() async {
    try {
      final account = createAccountInstance();

      // Use the getEstimateMaxFeeForDeployAccountTx method from Account
      final feeEstimate = await account.getEstimateMaxFeeForDeployAccountTx(
        classHash: isMainnet
            ? StarknetConstants.ARGENT_ACCOUNT_CLASS_HASH_MAINNET
            : StarknetConstants.ARGENT_ACCOUNT_CLASS_HASH_TESTNET,
        constructorCalldata: [
          publicKey,
          StarknetConstants.NO_GUARDIAN,
        ],
        salt: Felt.fromInt(0),
      );

      return feeEstimate.toBigInt();
    } catch (e) {
      throw Exception('Failed to estimate deployment fee: $e');
    }
  }

  /// Deploy the account to the blockchain
  ///
  /// [maxFee] - Maximum fee willing to pay for deployment
  ///
  /// Returns the transaction hash of the deployment
  Future<String> deploy({required BigInt maxFee}) async {
    try {
      final account = createAccountInstance();

      // Use the static deployAccount method from Account class
      final result = await Account.deployAccount(
        classHash: isMainnet
            ? StarknetConstants.ARGENT_ACCOUNT_CLASS_HASH_MAINNET
            : StarknetConstants.ARGENT_ACCOUNT_CLASS_HASH_TESTNET,
        constructorCalldata: [
          publicKey,
          StarknetConstants.NO_GUARDIAN,
        ],
        salt: Felt.fromInt(0),
        max_fee: Felt(maxFee),
        provider: provider,
        signer: account.signer,
      );

      return result.when(
        result: (tx) => tx.transactionHash.toHexString(),
        error: (error) => throw Exception('Deployment failed: ${error.message}'),
      );
    } catch (e) {
      throw Exception('Failed to deploy account: $e');
    }
  }

  /// Reset cached deployment status
  ///
  /// Call this after deploying the account to force a re-check
  void resetDeploymentStatus() {
    _isDeployed = null;
  }

  /// Get the account address as a hex string
  ///
  /// Returns the address in 0x... format
  String getAddressHex() {
    return calculateAccountAddress().toHexString();
  }

  @override
  String toString() {
    return 'StarknetAccount(address: ${getAddressHex()}, '
        'network: ${isMainnet ? 'mainnet' : 'testnet'}, '
        'deployed: ${_isDeployed ?? 'unknown'})';
  }
}
