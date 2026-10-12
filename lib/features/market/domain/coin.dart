class Coin {
  const Coin({
    required this.id,
    required this.name,
    required this.symbol,
    required this.rank,
    required this.priceUsd,
    required this.marketCapUsd,
    required this.volume24hUsd,
    required this.change24h,
    required this.circulatingSupply,
    required this.totalSupply,
    required this.maxSupply,
    this.isMock = false,
  });

  final String id;
  final String name;
  final String symbol;
  final int rank;
  final double priceUsd;
  final double marketCapUsd;
  final double volume24hUsd;
  final double change24h;
  final double circulatingSupply;
  final double totalSupply;
  final double maxSupply;
  final bool isMock;

  factory Coin.fromJson(Map<String, dynamic> json) {
    final quotes = json['quotes'] as Map<String, dynamic>? ?? {};
    final usd = quotes['USD'] as Map<String, dynamic>? ?? {};
    double number(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

    return Coin(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      symbol: (json['symbol']?.toString() ?? '').toUpperCase(),
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      priceUsd: number(usd['price']),
      marketCapUsd: number(usd['market_cap']),
      volume24hUsd: number(usd['volume_24h']),
      change24h: number(usd['percent_change_24h']),
      circulatingSupply: number(json['circulating_supply']),
      totalSupply: number(json['total_supply']),
      maxSupply: number(json['max_supply']),
    );
  }

  factory Coin.fromMock(Map<String, dynamic> json) => Coin(
        id: json['id'] as String,
        name: json['name'] as String,
        symbol: (json['symbol'] as String).toUpperCase(),
        rank: json['rank'] as int,
        priceUsd: (json['price'] as num).toDouble(),
        marketCapUsd: (json['marketCap'] as num).toDouble(),
        volume24hUsd: (json['volume'] as num).toDouble(),
        change24h: (json['change'] as num).toDouble(),
        circulatingSupply: (json['circulating'] as num).toDouble(),
        totalSupply: (json['totalSupply'] as num).toDouble(),
        maxSupply: (json['maxSupply'] as num).toDouble(),
        isMock: true,
      );
}
