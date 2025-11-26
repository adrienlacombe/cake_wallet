import 'dart:io';

import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_starknet/starknet_wallet.dart';
import 'package:cw_starknet/starknet_wallet_creation_credentials.dart';
import 'package:cw_starknet/starknet_key_derivation.dart';
import 'package:cw_starknet/starknet_account.dart';
import 'package:cw_starknet/starknet_constants.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:starknet/starknet.dart';

class StarknetWalletService extends WalletService<StarknetNewWalletCredentials,
    StarknetRestoreWalletFromSeedCredentials, StarknetRestoreWalletFromPrivateKey, StarknetNewWalletCredentials> {
  StarknetWalletService(this.isDirect);

  final bool isDirect;

  @override
  Future<StarknetWallet> create(StarknetNewWalletCredentials credentials, {bool? isTestnet}) async {
    // Generate mnemonic if not provided
    final mnemonic = credentials.mnemonic ?? bip39.generateMnemonic();

    // Derive private key and address BEFORE wallet creation
    final privateKeyFelt = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(mnemonic);
    final publicKey = StarknetKeyDerivation.derivePublicKey(privateKeyFelt);

    // Create account instance to calculate address
    final account = StarknetAccount(
      privateKey: privateKeyFelt,
      publicKey: publicKey,
      provider: JsonRpcProvider(
        nodeUri: Uri.parse(
          isTestnet == true
              ? StarknetConstants.DEFAULT_TESTNET_RPC
              : StarknetConstants.DEFAULT_MAINNET_RPC,
        ),
      ),
      isMainnet: isTestnet != true,
    );

    final address = account.calculateAccountAddress().toHexString();

    // Set address in walletInfo BEFORE wallet creation
    credentials.walletInfo!.address = address;
    await credentials.walletInfo!.save();

    // Create wallet with mnemonic
    final wallet = StarknetWallet(
      walletInfo: credentials.walletInfo!,
      password: credentials.password!,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      mnemonic: mnemonic,
    );

    await wallet.init();
    await wallet.save();
    return wallet;
  }

  @override
  WalletType getType() => WalletType.starknet;

  @override
  Future<bool> isWalletExit(String name) async =>
      File(await pathForWallet(name: name, type: getType())).existsSync();

  @override
  Future<StarknetWallet> openWallet(String name, String password) async {
    final walletInfo = await WalletInfo.get(name, getType());
    if (walletInfo == null) {
      throw Exception('Wallet not found');
    }

    final wallet = await StarknetWalletBase.open(
      name: name,
      password: password,
      walletInfo: walletInfo,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
    );

    await wallet.init();
    await wallet.save();
    return wallet;
  }

  @override
  Future<void> remove(String wallet) async {
    File(await pathForWalletDir(name: wallet, type: getType())).delete(recursive: true);
    final walletInfo = await WalletInfo.get(wallet, getType());
    if (walletInfo == null) {
      throw Exception('Wallet not found');
    }
    await WalletInfo.delete(walletInfo);
  }

  @override
  Future<StarknetWallet> restoreFromKeys(StarknetRestoreWalletFromPrivateKey credentials,
      {bool? isTestnet}) async {
    // Derive public key and address from private key
    final privateKeyFelt = Felt.fromHexString(credentials.privateKey);
    final publicKey = StarknetKeyDerivation.derivePublicKey(privateKeyFelt);

    // Create account instance to calculate address
    final account = StarknetAccount(
      privateKey: privateKeyFelt,
      publicKey: publicKey,
      provider: JsonRpcProvider(
        nodeUri: Uri.parse(
          isTestnet == true
              ? StarknetConstants.DEFAULT_TESTNET_RPC
              : StarknetConstants.DEFAULT_MAINNET_RPC,
        ),
      ),
      isMainnet: isTestnet != true,
    );

    final address = account.calculateAccountAddress().toHexString();

    // Set address in walletInfo BEFORE wallet creation
    credentials.walletInfo!.address = address;
    await credentials.walletInfo!.save();

    final wallet = StarknetWallet(
      password: credentials.password!,
      walletInfo: credentials.walletInfo!,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      privateKey: credentials.privateKey,
    );

    await wallet.init();
    await wallet.save();

    return wallet;
  }

  @override
  Future<StarknetWallet> restoreFromSeed(StarknetRestoreWalletFromSeedCredentials credentials,
      {bool? isTestnet}) async {
    // Derive private key and address from mnemonic
    final privateKeyFelt = StarknetKeyDerivation.derivePrivateKeyFromMnemonic(credentials.mnemonic);
    final publicKey = StarknetKeyDerivation.derivePublicKey(privateKeyFelt);

    // Create account instance to calculate address
    final account = StarknetAccount(
      privateKey: privateKeyFelt,
      publicKey: publicKey,
      provider: JsonRpcProvider(
        nodeUri: Uri.parse(
          isTestnet == true
              ? StarknetConstants.DEFAULT_TESTNET_RPC
              : StarknetConstants.DEFAULT_MAINNET_RPC,
        ),
      ),
      isMainnet: isTestnet != true,
    );

    final address = account.calculateAccountAddress().toHexString();

    // Set address in walletInfo BEFORE wallet creation
    credentials.walletInfo!.address = address;
    await credentials.walletInfo!.save();

    final wallet = StarknetWallet(
      password: credentials.password!,
      walletInfo: credentials.walletInfo!,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      mnemonic: credentials.mnemonic,
    );

    await wallet.init();
    await wallet.save();

    return wallet;
  }

  @override
  Future<void> rename(String currentName, String password, String newName) async {
    // Implement rename
  }

  @override
  Future<WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo>> restoreFromHardwareWallet(StarknetNewWalletCredentials credentials) {
    throw UnimplementedError();
  }
}
