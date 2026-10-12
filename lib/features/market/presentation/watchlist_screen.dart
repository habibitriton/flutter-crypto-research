import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/formatters.dart';
import '../domain/coin.dart';
import 'market_providers.dart';
import 'coin_details_screen.dart';

const _kUp = Color(0xFF45D6A0);
const _kDown = Color(0xFFFF7181);
const _kAccent = Color(0xFFAA98FF);
const _kGold = Color(0xFFFFC857);

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(coinsProvider);
    try {
      await ref.read(coinsProvider.future);
    } catch (_) {}
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear watchlist?'),
        content: const Text('All saved coins will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) ref.read(watchlistProvider.notifier).clear();
  }

  void _remove(BuildContext context, WidgetRef ref, Coin coin) {
    final notifier = ref.read(watchlistProvider.notifier);
    notifier.toggle(coin.id);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('${coin.name} removed'),
        action: SnackBarAction(label: 'Undo', onPressed: () => notifier.toggle(coin.id)),
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coinsAsync = ref.watch(watchlistCoinsProvider);
    final hasSaved = ref.watch(watchlistProvider).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My watchlist', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: () => _refresh(ref), icon: const Icon(Icons.refresh_rounded)),
          if (hasSaved)
            IconButton(
              tooltip: 'Clear all',
              onPressed: () => _confirmClear(context, ref),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: coinsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (error, _) => _ErrorPanel(
          onRetry: () => _refresh(ref),
          onMock: () => ref.read(mockModeProvider.notifier).state = true,
        ),
        data: (saved) {
          if (saved.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: saved.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) return _Summary(coins: saved);
                final coin = saved[index - 1];
                return Dismissible(
                  key: ValueKey(coin.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _remove(context, ref, coin),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 22),
                    decoration: BoxDecoration(
                      color: _kDown.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: _kDown),
                  ),
                  child: _WatchTile(
                    coin: coin,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CoinDetailsScreen(coin: coin)),
                    ),
                    onRemove: () => _remove(context, ref, coin),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Summary ─────────────────────────

class _Summary extends StatelessWidget {
  const _Summary({required this.coins});
  final List<Coin> coins;

  @override
  Widget build(BuildContext context) {
    final avg = coins.fold<double>(0, (s, c) => s + c.change24h) / coins.length;
    final best = coins.reduce((a, b) => a.change24h >= b.change24h ? a : b);
    final up = avg >= 0;
    final tone = up ? _kUp : _kDown;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone.withValues(alpha: .2), _kAccent.withValues(alpha: .06)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Row(children: [
        Expanded(child: _SummaryStat('Saved coins', '${coins.length}')),
        Expanded(
          child: _SummaryStat(
            'Avg 24h',
            '${up ? '+' : ''}${avg.toStringAsFixed(2)}%',
            color: tone,
          ),
        ),
        Expanded(
          child: _SummaryStat(
            'Best today',
            best.symbol,
            color: best.change24h >= 0 ? _kUp : _kDown,
          ),
        ),
      ]),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        ),
      ]);
}

// ───────────────────────── Tile ─────────────────────────

class _WatchTile extends StatelessWidget {
  const _WatchTile({required this.coin, required this.onTap, required this.onRemove});
  final Coin coin;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final up = coin.change24h >= 0;
    final tone = up ? _kUp : _kDown;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: .06)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kAccent.withValues(alpha: .35), const Color(0xFF2A2540)],
                ),
              ),
              child: Text(
                coin.symbol.length > 4 ? coin.symbol.substring(0, 4) : coin.symbol,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(coin.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 5),
                Text(
                  '${coin.symbol}  •  ${coin.rank > 0 ? '#${coin.rank}' : 'Unranked'}',
                  style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 12),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatPrice(coin.priceUsd), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 16, color: tone),
                  Text('${coin.change24h.abs().toStringAsFixed(2)}%',
                      style: TextStyle(color: tone, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            IconButton(
              tooltip: 'Remove from watchlist',
              onPressed: onRemove,
              icon: const Icon(Icons.star_rounded, color: _kGold),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── States ─────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kGold.withValues(alpha: .1),
              ),
              child: const Icon(Icons.star_border_rounded, size: 48, color: _kGold),
            ),
            const SizedBox(height: 18),
            const Text('Your watchlist is empty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Open Market and tap the star beside a coin to save it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
          ]),
        ),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry, required this.onMock});
  final VoidCallback onRetry;
  final VoidCallback onMock;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            const Text('Unable to load coin data.', textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
              OutlinedButton(onPressed: onMock, child: const Text('Load demo data')),
            ]),
          ]),
        ),
      );
}