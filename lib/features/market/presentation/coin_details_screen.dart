import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/formatters.dart';
import '../domain/coin.dart';
import 'market_providers.dart';

const _kUp = Color(0xFF45D6A0);
const _kDown = Color(0xFFFF7181);
const _kAccent = Color(0xFFAA98FF);
const _kGold = Color(0xFFFFC857);
const _kCard = Color(0xFF1A1A22);

/// Price 24h ago, derived from the current price and 24h % change.
double? _price24hAgo(Coin c) {
  final d = 1 + c.change24h / 100;
  if (!c.priceUsd.isFinite || c.priceUsd <= 0 || !d.isFinite || d <= 0) return null;
  return c.priceUsd / d;
}

class CoinDetailsScreen extends ConsumerWidget {
  const CoinDetailsScreen({super.key, required this.coin});
  final Coin coin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = ref.watch(coinChartProvider(coin.id));
    final saved = ref.watch(watchlistProvider).contains(coin.id);
    final positive = coin.change24h >= 0;
    final tone = positive ? _kUp : _kDown;

    void toggle() {
      HapticFeedback.mediumImpact();
      ref.read(watchlistProvider.notifier).toggle(coin.id);
    }

    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: saved
                ? OutlinedButton.icon(
                    key: const ValueKey('saved'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: _kGold,
                      side: BorderSide(color: _kGold.withValues(alpha: .5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: toggle,
                    icon: const Icon(Icons.star_rounded),
                    label: const Text('In your watchlist · tap to remove'),
                  )
                : FilledButton.icon(
                    key: const ValueKey('unsaved'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: toggle,
                    icon: const Icon(Icons.star_border_rounded),
                    label: const Text('Add to watchlist'),
                  ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [tone.withValues(alpha: .14), Colors.transparent],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(coinChartProvider(coin.id));
            try {
              await ref.read(coinChartProvider(coin.id).future);
            } catch (_) {}
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: Text(coin.symbol.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5)),
                actions: [
                  IconButton(
                    tooltip: 'Copy price',
                    onPressed: () => _copyPrice(context),
                    icon: const Icon(Icons.copy_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: saved ? 'Remove from watchlist' : 'Add to watchlist',
                    onPressed: toggle,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: Icon(
                        saved ? Icons.star_rounded : Icons.star_border_rounded,
                        key: ValueKey(saved),
                        size: 28,
                        color: saved ? _kGold : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _Header(coin: coin, positive: positive, tone: tone, onCopy: () => _copyPrice(context)),
                    const SizedBox(height: 22),
                    _ChartCard(
                      coin: coin,
                      chart: chart,
                      onRetry: () => ref.invalidate(coinChartProvider(coin.id)),
                    ),
                    const SizedBox(height: 26),
                    const _SectionTitle('Market statistics'),
                    const SizedBox(height: 12),
                    _StatsGrid(coin: coin, tone: tone),
                    const SizedBox(height: 12),
                    _SupplyCard(coin: coin),
                    if (coin.isMock) ...[
                      const SizedBox(height: 14),
                      const _Notice(
                        icon: Icons.science_outlined,
                        color: Colors.amber,
                        text: 'Demo values are illustrative mock data, not live prices.',
                      ),
                    ],
                    const SizedBox(height: 14),
                    const _Notice(
                      icon: Icons.info_outline_rounded,
                      color: Colors.white38,
                      text: 'Data is provided for research/demo purposes only, not financial advice.',
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyPrice(BuildContext context) {
    Clipboard.setData(ClipboardData(text: formatPrice(coin.priceUsd)));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text('${coin.symbol} price copied'),
      ));
  }
}

// ───────────────────────── Header ─────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.coin, required this.positive, required this.tone, required this.onCopy});
  final Coin coin;
  final bool positive;
  final Color tone;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final initial = coin.name.isNotEmpty ? coin.name[0].toUpperCase() : '?';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kAccent, _kAccent.withValues(alpha: .45)],
            ),
          ),
          child: Text(initial,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(coin.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(coin.symbol.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ]),
        ),
        if (coin.rank > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Rank #${coin.rank}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
          ),
      ]),
      const SizedBox(height: 22),
      GestureDetector(
        onLongPress: onCopy,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: coin.priceUsd),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatPrice(v),
                style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: -1)),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: tone.withValues(alpha: .15), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(positive ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 18, color: tone),
            const SizedBox(width: 6),
            Text('${positive ? '+' : ''}${coin.change24h.toStringAsFixed(2)}%',
                style: TextStyle(color: tone, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 10),
        const Text('past 24 hours', style: TextStyle(color: Colors.white54, fontSize: 13)),
      ]),
    ]);
  }
}

// ───────────────────────── Chart ─────────────────────────

String _pointLabel(int i, int n, bool fallback) {
  final last = n - 1;
  if (fallback) return i == last ? 'Now' : '24h ago';
  final daysAgo = last - i;
  return daysAgo == 0 ? 'Today' : '$daysAgo d ago';
}

class _ChartCard extends StatefulWidget {
  const _ChartCard({required this.coin, required this.chart, required this.onRetry});
  final Coin coin;
  final AsyncValue<List<double>> chart;
  final VoidCallback onRetry;

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  int? _touched;

  String _reason() {
    final chart = widget.chart;
    if (chart.hasError) {
      final v = chart.error.toString().toLowerCase();
      if (v.contains('429')) return 'API rate limit reached.';
      if (v.contains('socketexception') || v.contains('connection')) return 'No internet connection.';
      return 'History endpoint unavailable.';
    }
    return 'Not enough history returned.';
  }

  @override
  Widget build(BuildContext context) {
    final chart = widget.chart;
    final loading = chart is AsyncLoading<List<double>>;

    final history = chart.valueOrNull?.where((p) => p.isFinite).toList();
    final hasHistory = history != null && history.length >= 2;

    List<double>? prices;
    if (hasHistory) {
      prices = history;
    } else {
      final prev = _price24hAgo(widget.coin);
      if (prev != null) prices = [prev, widget.coin.priceUsd];
    }
    final fallback = !hasHistory;

    final idx = (_touched != null && prices != null && _touched! < prices.length) ? _touched : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Price history', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                loading
                    ? 'Loading history…'
                    : hasHistory
                        ? 'Daily closing prices · last ${prices!.length} days'
                        : '24h move · full history unavailable',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ]),
          ),
          if (prices != null && !loading)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              child: idx != null
                  ? Column(
                      key: ValueKey(idx),
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatPrice(prices[idx]),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(_pointLabel(idx, prices.length, fallback),
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    )
                  : _PeriodChange(key: const ValueKey('period'), prices: prices, label: fallback ? '24 hours' : '${prices.length - 1} days'),
            ),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          height: 230,
          child: loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
              : prices == null
                  ? _ChartMessage(
                      icon: Icons.cloud_off_rounded,
                      text: '${_reason()}\nPull down or tap retry.',
                      onRetry: widget.onRetry,
                    )
                  : _PriceChart(
                      prices: prices,
                      fallback: fallback,
                      onTouch: (i) {
                        if (i != _touched) setState(() => _touched = i);
                      },
                    ),
        ),
        if (!loading && prices != null)
          if (fallback)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${_reason()} Showing derived 24h move.',
                        style: const TextStyle(color: Colors.amber, fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: widget.onRetry,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Retry'),
                  ),
                ]),
              ),
            )
          else
            _HighLowRow(prices: prices),
      ]),
    );
  }
}

class _PeriodChange extends StatelessWidget {
  const _PeriodChange({super.key, required this.prices, required this.label});
  final List<double> prices;
  final String label;

  @override
  Widget build(BuildContext context) {
    final first = prices.first;
    final pct = first == 0 ? 0.0 : ((prices.last - first) / first) * 100;
    final up = pct >= 0;
    final color = up ? _kUp : _kDown;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('${up ? '+' : ''}${pct.toStringAsFixed(2)}%',
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ]);
  }
}

class _PriceChart extends StatelessWidget {
  const _PriceChart({required this.prices, required this.fallback, required this.onTouch});
  final List<double> prices;
  final bool fallback;
  final ValueChanged<int?> onTouch;

  @override
  Widget build(BuildContext context) {
    final low = prices.reduce((a, b) => a < b ? a : b);
    final high = prices.reduce((a, b) => a > b ? a : b);
    final padding = (high - low).abs() * .12;
    final up = prices.last >= prices.first;
    final color = up ? _kUp : _kDown;
    final minY = (low - padding).clamp(0, double.infinity).toDouble();
    var maxY = high + (padding == 0 ? (high.abs() * .02 + .000001) : padding);
    if (maxY <= minY) maxY = minY + 1;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: (prices.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: .06),
            strokeWidth: 1,
            dashArray: [4, 5],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (value != i.toDouble() || i < 0 || i >= prices.length) return const SizedBox.shrink();
                final last = prices.length - 1;
                final label = fallback
                    ? (i == last ? 'Now' : '24h ago')
                    : (i == last ? 'Today' : '-${last - i}d');
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchCallback: (event, resp) {
            final spots = resp?.lineBarSpots;
            if (!event.isInterestedForInteractions || spots == null || spots.isEmpty) {
              onTouch(null);
            } else {
              onTouch(spots.first.spotIndex);
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF26262F),
            tooltipRoundedRadius: 10,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      formatPrice(s.y),
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ))
                .toList(),
          ),
          getTouchedSpotIndicator: (bar, indexes) => indexes
              .map((_) => TouchedSpotIndicatorData(
                    FlLine(color: color.withValues(alpha: .4), strokeWidth: 1.5, dashArray: [3, 3]),
                    FlDotData(
                      show: true,
                      getDotPainter: (a, b, c, d) => FlDotCirclePainter(
                        radius: 5.5,
                        color: color,
                        strokeWidth: 3,
                        strokeColor: const Color(0xFF14141A),
                      ),
                    ),
                  ))
              .toList(),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: prices.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: prices.length > 2,
            curveSmoothness: .28,
            preventCurveOverShooting: true,
            barWidth: 3.5,
            isStrokeCapRound: true,
            gradient: LinearGradient(colors: [_kAccent, color]),
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, _) => spot.x == prices.length - 1 || prices.length == 2,
              getDotPainter: (a, b, c, d) => FlDotCirclePainter(
                radius: 5,
                color: color,
                strokeWidth: 3,
                strokeColor: const Color(0xFF14141A),
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
    );
  }
}

class _HighLowRow extends StatelessWidget {
  const _HighLowRow({required this.prices});
  final List<double> prices;

  @override
  Widget build(BuildContext context) {
    final low = prices.reduce((a, b) => a < b ? a : b);
    final high = prices.reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Expanded(child: _MiniStat(label: '${prices.length - 1}d low', value: formatPrice(low), color: _kDown)),
        const SizedBox(width: 10),
        Expanded(child: _MiniStat(label: '${prices.length - 1}d high', value: formatPrice(high), color: _kUp)),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ]),
    );
  }
}

class _ChartMessage extends StatelessWidget {
  const _ChartMessage({required this.icon, required this.text, required this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 34, color: Colors.white24),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.4)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
        ),
      ]),
    );
  }
}

// ───────────────────────── Stats ─────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800));
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.coin, required this.tone});
  final Coin coin;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final positive = coin.change24h >= 0;
    final prev = _price24hAgo(coin);
    final volCap = coin.marketCapUsd > 0 ? coin.volume24hUsd / coin.marketCapUsd * 100 : null;
    final fdv = (coin.maxSupply > 0 && coin.priceUsd > 0) ? coin.priceUsd * coin.maxSupply : null;

    final items = <_StatData>[
      _StatData(Icons.pie_chart_outline_rounded, 'Market cap', formatCompactCurrency(coin.marketCapUsd)),
      _StatData(Icons.bar_chart_rounded, '24h volume', formatCompactCurrency(coin.volume24hUsd)),
      _StatData(Icons.emoji_events_outlined, 'Market rank', coin.rank > 0 ? '#${coin.rank}' : 'N/A'),
      _StatData(
        positive ? Icons.north_east_rounded : Icons.south_east_rounded,
        '24h change',
        '${positive ? '+' : ''}${coin.change24h.toStringAsFixed(2)}%',
        valueColor: tone,
      ),
      if (prev != null) _StatData(Icons.history_rounded, 'Price 24h ago', formatPrice(prev)),
      if (volCap != null) _StatData(Icons.water_drop_outlined, 'Volume / market cap', '${volCap.toStringAsFixed(2)}%'),
      if (fdv != null) _StatData(Icons.diamond_outlined, 'Fully diluted value', formatCompactCurrency(fdv)),
    ];

    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final w = (c.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < items.length; i++)
            SizedBox(
              width: w,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 350 + i * 70),
                curve: Curves.easeOutCubic,
                builder: (_, t, child) =>
                    Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: child)),
                child: _StatTile(data: items[i]),
              ),
            ),
        ],
      );
    });
  }
}

class _StatData {
  const _StatData(this.icon, this.label, this.value, {this.valueColor});
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _kAccent.withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
          child: Icon(data.icon, size: 18, color: _kAccent),
        ),
        const SizedBox(height: 12),
        Text(data.label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(data.value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: data.valueColor)),
        ),
      ]),
    );
  }
}

// ───────────────────────── Supply ─────────────────────────

class _SupplyCard extends StatelessWidget {
  const _SupplyCard({required this.coin});
  final Coin coin;

  String _supply(double v) => v > 0 ? '${formatNumber(v)} ${coin.symbol}' : 'Not available';

  @override
  Widget build(BuildContext context) {
    final hasMax = coin.maxSupply > 0;
    final ratio = (hasMax && coin.circulatingSupply > 0)
        ? (coin.circulatingSupply / coin.maxSupply).clamp(0.0, 1.0)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Supply', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        if (ratio != null) ...[
          Row(children: [
            Text('${(ratio * 100).toStringAsFixed(1)}% circulating',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const Spacer(),
            const Text('of max supply', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: .08),
                valueColor: const AlwaysStoppedAnimation(_kAccent),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _SupplyRow('Circulating supply', _supply(coin.circulatingSupply)),
        const _Divider(),
        _SupplyRow('Total supply', _supply(coin.totalSupply)),
        const _Divider(),
        _SupplyRow('Maximum supply', hasMax ? _supply(coin.maxSupply) : 'Not specified'),
      ]),
    );
  }
}

class _SupplyRow extends StatelessWidget {
  const _SupplyRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: Colors.white60))),
      const SizedBox(width: 10),
      Flexible(
        child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Divider(height: 1, color: Colors.white.withValues(alpha: .07)),
      );
}

// ───────────────────────── Notices ─────────────────────────

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12, height: 1.4))),
    ]);
  }
}