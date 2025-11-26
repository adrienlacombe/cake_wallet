import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';

class StarknetNewWalletCredentials extends WalletCredentials {
  StarknetNewWalletCredentials({
    required String name,
    String? password,
    this.mnemonic,
    this.passphrase,
    this.walletInfo,
  }) : super(name: name, password: password);

  final String? mnemonic;
  final String? passphrase;
  final WalletInfo? walletInfo;
}

class StarknetRestoreWalletFromSeedCredentials extends WalletCredentials {
  StarknetRestoreWalletFromSeedCredentials({
    required String name,
    required String password,
    required this.mnemonic,
    this.passphrase,
    this.walletInfo,
  }) : super(name: name, password: password);

  final String mnemonic;
  final String? passphrase;
  final WalletInfo? walletInfo;
}

class StarknetRestoreWalletFromPrivateKey extends WalletCredentials {
  StarknetRestoreWalletFromPrivateKey({
    required String name,
    required String password,
    required this.privateKey,
    this.walletInfo,
  }) : super(name: name, password: password);

  final String privateKey;
  final WalletInfo? walletInfo;
}
