import 'package:dio/dio.dart';
import '../domain/coin.dart';
import 'mock_coins.dart';

class CoinApi {
  CoinApi()
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://api.coinpaprika.com/v1',
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Accept': 'application/json'},
        ));

  final Dio _dio;

  Future<List<Coin>> getCoins({bool useMock = false}) async {
    if (useMock) return buildMockCoins();
    final response = await _dio.get('/tickers', queryParameters: {'quotes': 'USD'});
    if (response.data is! List) {
      throw const FormatException('Unexpected response from CoinPaprika.');
    }
    final coins = (response.data as List)
        .whereType<Map<String, dynamic>>()
        .map(Coin.fromJson)
        .where((coin) => coin.id.isNotEmpty && coin.name.isNotEmpty)
        .toList();
    if (coins.isEmpty) throw const FormatException('The API returned no coins.');
    return coins;
  }

  Future<List<double>> getHistoricalPrices(String coinId) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';

    final response = await _dio.get(
      '/coins/$coinId/ohlcv/historical',
      queryParameters: {'start': date(start), 'end': date(now)},
    );
    if (response.data is! List) {
      throw const FormatException('Unexpected chart response.');
    }
    return (response.data as List)
        .whereType<Map<String, dynamic>>()
        .map((row) => (row['close'] as num?)?.toDouble() ?? 0)
        .where((price) => price > 0)
        .toList();
  }
}
