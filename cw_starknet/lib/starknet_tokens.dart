import 'package:cw_core/crypto_currency.dart';

class StarknetToken extends CryptoCurrency {
  StarknetToken({
    required String name,
    required String symbol,
    required this.contractAddress,
    required int decimals,
    String? iconPath,
  }) : super(
          name: symbol.toLowerCase(),
          title: symbol,
          fullName: name,
          decimals: decimals,
          tag: 'STRK',
          iconPath: iconPath,
        );

  final String contractAddress;
}

class StarknetTokens {
  static final eth = StarknetToken(
    name: 'Ethereum',
    symbol: 'ETH',
    contractAddress: '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7',
    decimals: 18,
    iconPath: 'assets/images/crypto/ethereum.webp',
  );

  static final strk = StarknetToken(
    name: 'Starknet',
    symbol: 'STRK',
    contractAddress: '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d',
    decimals: 18,
    iconPath: 'assets/images/crypto/starknet.png',
  );

  static final usdc = StarknetToken(
    name: 'USD Coin',
    symbol: 'USDC',
    contractAddress: '0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8',
    decimals: 6,
    iconPath: 'assets/images/crypto/usdc.webp',
  );
  
  static final usdt = StarknetToken(
    name: 'Tether USD',
    symbol: 'USDT',
    contractAddress: '0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8',
    decimals: 6,
    iconPath: 'assets/images/crypto/tether.webp',
  );

  static final dai = StarknetToken(
    name: 'DAI',
    symbol: 'DAI',
    contractAddress: '0x00da114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6093',
    decimals: 18,
    iconPath: 'assets/images/crypto/dai.webp',
  );

  static final wbtc = StarknetToken(
    name: 'Wrapped BTC',
    symbol: 'WBTC',
    contractAddress: '0x03fe2b97c1fd336e75df0850d767b46f53087366e9c07af3e1a998b378e61a7a',
    decimals: 8,
    iconPath: 'assets/images/crypto/wbtc.webp',
  );

  static final List<StarknetToken> all = [
    eth,
    strk,
    usdc,
    usdt,
    dai,
    wbtc,
  ];
}
