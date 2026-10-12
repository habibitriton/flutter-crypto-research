import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/coin_api.dart';
import '../domain/coin.dart';

// ───────────────────────── API & mode ─────────────────────────

final coinApiProvider = Provider<CoinApi>((ref) => CoinApi());

/// Demo-only app: always true. Kept so other screens that reference it compile.
final mockModeProvider = StateProvider<bool>((ref) => true);

// ───────────────────────── Coins (demo data only) ─────────────────────────

final coinsProvider = FutureProvider<List<Coin>>((ref) {
  return ref.watch(coinApiProvider).getCoins(useMock: true);
});

// ───────────────────────── Search & sort ─────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');

enum CoinSort { rank, price, gainers, losers, marketCap, volume }

final coinSortProvider = StateProvider<CoinSort>((ref) => CoinSort.rank);

/// Coins after applying search + sort. Safe to use in lists.
final visibleCoinsProvider = Provider<AsyncValue<List<Coin>>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final sort = ref.watch(coinSortProvider);

  return ref.watch(coinsProvider).whenData((coins) {
    final list = query.isEmpty
        ? List<Coin>.of(coins)
        : coins
            .where((c) =>
                c.name.toLowerCase().contains(query) ||
                c.symbol.toLowerCase().contains(query))
            .toList();

    int byRank(Coin a, Coin b) {
      final ra = a.rank > 0 ? a.rank : 1 << 30;
      final rb = b.rank > 0 ? b.rank : 1 << 30;
      return ra.compareTo(rb);
    }

    switch (sort) {
      case CoinSort.rank:
        list.sort(byRank);
      case CoinSort.price:
        list.sort((a, b) => b.priceUsd.compareTo(a.priceUsd));
      case CoinSort.gainers:
        list.sort((a, b) => b.change24h.compareTo(a.change24h));
      case CoinSort.losers:
        list.sort((a, b) => a.change24h.compareTo(b.change24h));
      case CoinSort.marketCap:
        list.sort((a, b) => b.marketCapUsd.compareTo(a.marketCapUsd));
      case CoinSort.volume:
        list.sort((a, b) => b.volume24hUsd.compareTo(a.volume24hUsd));
    }
    return list;
  });
});

// ───────────────────────── Watchlist ─────────────────────────

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, Set<String>>(
  (ref) => WatchlistNotifier()..load(),
);

/// Saved coins resolved against the latest coin list.
final watchlistCoinsProvider = Provider<AsyncValue<List<Coin>>>((ref) {
  final ids = ref.watch(watchlistProvider);
  return ref
      .watch(coinsProvider)
      .whenData((coins) => coins.where((c) => ids.contains(c.id)).toList());
});

class WatchlistNotifier extends StateNotifier<Set<String>> {
  WatchlistNotifier() : super(<String>{});

  static const _key = 'cryptoscope_watchlist_ids';
  bool _loaded = false;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_key)?.toSet() ?? <String>{};
      // Merge so a toggle made before load finished isn't lost.
      state = {...saved, ...state};
    } catch (_) {
      // Keep in-memory state if storage is unavailable.
    } finally {
      _loaded = true;
    }
  }

  bool contains(String coinId) => state.contains(coinId);

  Future<void> toggle(String coinId) async {
    final next = Set<String>.from(state);
    if (!next.add(coinId)) next.remove(coinId);
    state = next;
    await _persist();
  }

  Future<void> clear() async {
    state = <String>{};
    await _persist();
  }

  Future<void> _persist() async {
    if (!_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, state.toList());
    } catch (_) {
      // Ignore write failures; UI state stays correct for this session.
    }
  }
}

// ───────────────────────── Chart (demo history) ─────────────────────────

/// Demo price history. No network: a deterministic 7-day series for each coin
/// that ends at the coin's current price, with the last day matching its
/// 24h change. Illustrative only.
final coinChartProvider =
    FutureProvider.autoDispose.family<List<double>, String>((ref, coinId) async {
  final coins = await ref.watch(coinsProvider.future);
  final coin = coins.firstWhere(
    (c) => c.id == coinId,
    orElse: () => throw StateError('Coin $coinId not found'),
  );
  return _demoHistory(coin);
});

List<double> _demoHistory(Coin coin, {int days = 7}) {
  final end = coin.priceUsd;
  if (!end.isFinite || end <= 0) return const <double>[];

  final factor = 1 + coin.change24h / 100;
  final prev = (factor.isFinite && factor > 0) ? end / factor : end;

  final rnd = Random(coin.id.hashCode);
  final series = List<double>.filled(days, end);
  series[days - 1] = end;
  series[days - 2] = prev;
  for (var i = days - 3; i >= 0; i--) {
    final step = 1 + (rnd.nextDouble() - .5) * .10; // about ±5% per day
    series[i] = series[i + 1] / step;
  }
  return series;
}