import 'package:cw_starknet/starknet_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StarknetTokens', () {
    test('should have correct number of tokens', () {
      expect(StarknetTokens.all.length, 6);
    });

    test('should contain essential tokens', () {
      final symbols = StarknetTokens.all.map((t) => t.title).toList();
      expect(symbols, containsAll(['ETH', 'STRK', 'USDC', 'USDT', 'DAI', 'WBTC']));
    });

    test('should have valid contract addresses', () {
      for (final token in StarknetTokens.all) {
        expect(token.contractAddress, startsWith('0x'));
        expect(token.contractAddress.length, greaterThan(60)); // Starknet addresses are long
      }
    });

    test('should have correct decimals', () {
      expect(StarknetTokens.eth.decimals, 18);
      expect(StarknetTokens.strk.decimals, 18);
      expect(StarknetTokens.usdc.decimals, 6);
      expect(StarknetTokens.usdt.decimals, 6);
      expect(StarknetTokens.dai.decimals, 18);
      expect(StarknetTokens.wbtc.decimals, 8);
    });
  });
}
