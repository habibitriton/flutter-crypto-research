import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/formatters.dart';
import '../../market/domain/coin.dart';
import '../../market/presentation/market_providers.dart';

const _kUp = Color(0xFF45D6A0);
const _kDown = Color(0xFFFF7181);
const _kAccent = Color(0xFFAA98FF);
const _kCard = Color(0xFF1A1A22);

const _palette = <Color>[
  Color(0xFFAA98FF),
  Color(0xFF45D6A0),
  Color(0xFFFFC857),
  Color(0xFF5BC0FF),
  Color(0xFFFF8FB1),
  Color(0xFF5A5A6B),
];

class MarketStatisticsScreen extends ConsumerWidget {
  const MarketStatisticsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(coinsProvider);
    try {
      await ref.read(coinsProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coinsAsync = ref.watch(coinsProvider);
    final mock = ref.watch(mockModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market statistics', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: () => _refresh(ref), icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      body: coinsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (error, _) => _ErrorPanel(
          onRetry: () => _refresh(ref),
          onMock: () => ref.read(mockModeProvider.notifier).state = true,
        ),
        data: (coins) {
          if (coins.isEmpty) {
            return const Center(child: Text('No market data available.', style: TextStyle(color: Colors.white60)));
          }
          final stats = _Stats.from(coins);
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                if (mock) ...[
                  const _MockBanner(),
                  const SizedBox(height: 12),
                ],
                _Reveal(0, child: _HeroCard(stats: stats)),
                const SizedBox(height: 14),
                _Reveal(1, child: _MetricGrid(stats: stats)),
                const SizedBox(height: 14),
                _Reveal(2, child: _MoodCard(stats: stats)),
                const SizedBox(height: 14),
                _Reveal(3, child: _DominanceCard(stats: stats)),
                const SizedBox(height: 14),
                _Reveal(4, child: _MoversCard(stats: stats)),
                const SizedBox(height: 14),
                _Reveal(5, child: _TopCoinsCard(stats: stats)),
                const SizedBox(height: 16),
                Text(
                  'Statistics are calculated from the coin records returned by the selected API request, not the entire global market.',
                  style: TextStyle(color: Colors.white.withValues(alpha: .45), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Data ─────────────────────────

class _Stats {
  _Stats({
    required this.coins,
    required this.marketCap,
    required this.volume,
    required this.up,
    required this.down,
    required this.flat,
    required this.avgChange,
    required this.byCap,
    required this.gainers,
    required this.losers,
    required this.mood,
  });

  final List<Coin> coins;
  final double marketCap;
  final double volume;
  final int up;
  final int down;
  final int flat;
  final double avgChange;
  final List<Coin> byCap;
  final List<Coin> gainers;
  final List<Coin> losers;
  final double mood; // 0..100

  double get volumeRatio => marketCap <= 0 ? 0 : volume / marketCap * 100;
  Coin get leader => byCap.first;
  double get leaderShare => marketCap <= 0 ? 0 : leader.marketCapUsd / marketCap * 100;

  factory _Stats.from(List<Coin> coins) {
    final cap = coins.fold<double>(0, (s, c) => s + c.marketCapUsd);
    final vol = coins.fold<double>(0, (s, c) => s + c.volume24hUsd);
    final up = coins.where((c) => c.change24h > 0).length;
    final down = coins.where((c) => c.change24h < 0).length;
    final flat = coins.length - up - down;
    final avg = coins.fold<double>(0, (s, c) => s + c.change24h) / coins.length;

    final byCap = [...coins]..sort((a, b) => b.marketCapUsd.compareTo(a.marketCapUsd));
    final byChange = [...coins]..sort((a, b) => b.change24h.compareTo(a.change24h));

    final breadth = (up + down) == 0 ? .5 : up / (up + down);
    final momentum = ((50 + avg * 5).clamp(0, 100)).toDouble();
    final mood = (breadth * 100 * .6 + momentum * .4).clamp(0, 100).toDouble();

    return _Stats(
      coins: coins,
      marketCap: cap,
      volume: vol,
      up: up,
      down: down,
      flat: flat,
      avgChange: avg,
      byCap: byCap,
      gainers: byChange.where((c) => c.change24h > 0).take(5).toList(),
      losers: byChange.reversed.where((c) => c.change24h < 0).take(5).toList(),
      mood: mood,
    );
  }
}

// ───────────────────────── Shared bits ─────────────────────────

class _Reveal extends StatelessWidget {
  const _Reveal(this.index, {required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 450 + index * 90),
        curve: Curves.easeOutCubic,
        builder: (context, t, c) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 24), child: c),
        ),
        child: child,
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: child,
      );
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.title, {this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ]);
}

Widget _symbolBadge(Coin coin, {double size = 40}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAccent.withValues(alpha: .35), const Color(0xFF2A2540)],
        ),
      ),
      child: Text(
        coin.symbol.length > 4 ? coin.symbol.substring(0, 4) : coin.symbol,
        style: TextStyle(fontSize: size * .25, fontWeight: FontWeight.w800),
      ),
    );

// ───────────────────────── Hero ─────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final up = stats.avgChange >= 0;
    final tone = up ? _kUp : _kDown;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAccent.withValues(alpha: .32), tone.withValues(alpha: .10), _kCard],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.public_rounded, size: 16, color: Colors.white60),
          const SizedBox(width: 6),
          Text('Tracked market cap', style: TextStyle(color: Colors.white.withValues(alpha: .65), fontSize: 13)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: tone.withValues(alpha: .16), borderRadius: BorderRadius.circular(9)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 15, color: tone),
              const SizedBox(width: 4),
              Text('${up ? '+' : ''}${stats.avgChange.toStringAsFixed(2)}% avg',
                  style: TextStyle(color: tone, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(formatCompactCurrency(stats.marketCap),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1)),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _HeroStat('24h volume', formatCompactCurrency(stats.volume))),
          Container(width: 1, height: 34, color: Colors.white12),
          const SizedBox(width: 16),
          Expanded(child: _HeroStat('Vol / Cap', '${stats.volumeRatio.toStringAsFixed(2)}%')),
          Container(width: 1, height: 34, color: Colors.white12),
          const SizedBox(width: 16),
          Expanded(child: _HeroStat('Coins', '${stats.coins.length}')),
        ]),
      ]),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ]);
}

// ───────────────────────── Metric grid ─────────────────────────

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.stats});
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final items = <_Metric>[
      _Metric(Icons.trending_up_rounded, 'Gainers', '${stats.up}', 'coins rising', _kUp),
      _Metric(Icons.trending_down_rounded, 'Losers', '${stats.down}', 'coins falling', _kDown),
      _Metric(Icons.workspace_premium_outlined, '${stats.leader.symbol} dominance',
          '${stats.leaderShare.toStringAsFixed(1)}%', 'of tracked cap', _kAccent),
      _Metric(Icons.swap_vert_rounded, 'Avg 24h move', '${stats.avgChange >= 0 ? '+' : ''}${stats.avgChange.toStringAsFixed(2)}%',
          'across all coins', stats.avgChange >= 0 ? _kUp : _kDown),
    ];
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final w = (c.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: items.map((m) => SizedBox(width: w, child: _MetricCard(m))).toList(),
      );
    });
  }
}

class _Metric {
  const _Metric(this.icon, this.title, this.value, this.caption, this.color);
  final IconData icon;
  final String title;
  final String value;
  final String caption;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.m);
  final _Metric m;

  @override
  Widget build(BuildContext context) => _Panel(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: m.color.withValues(alpha: .14), borderRadius: BorderRadius.circular(11)),
            child: Icon(m.icon, size: 18, color: m.color),
          ),
          const SizedBox(height: 12),
          Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(m.value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: m.color)),
          ),
          const SizedBox(height: 2),
          Text(m.caption, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      );
}

// ───────────────────────── Mood & breadth ─────────────────────────

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.stats});
  final _Stats stats;

  (String, Color) get _label {
    final m = stats.mood;
    if (m < 25) return ('Very bearish', _kDown);
    if (m < 45) return ('Bearish', const Color(0xFFFF9A6B));
    if (m < 55) return ('Neutral', const Color(0xFFFFC857));
    if (m < 75) return ('Bullish', const Color(0xFF9BE37A));
    return ('Very bullish', _kUp);
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _label;
    final total = stats.coins.length;
    int flex(int n) => (n * 1000 ~/ total).clamp(0, 1000);

    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: _PanelTitle('Market mood', subtitle: 'Based on breadth and average momentum')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(10)),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
        ]),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, c) {
          const markerW = 18.0;
          final left = ((stats.mood / 100) * (c.maxWidth - markerW)).clamp(0, c.maxWidth - markerW).toDouble();
          return SizedBox(
            height: 26,
            child: Stack(alignment: Alignment.centerLeft, children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(colors: [_kDown, Color(0xFFFFC857), _kUp]),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                left: left,
                child: Container(
                  width: markerW,
                  height: markerW,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: color, width: 4),
                  ),
                ),
              ),
            ]),
          );
        }),
        const SizedBox(height: 6),
        Row(children: [
          const Text('Bearish', style: TextStyle(color: Colors.white38, fontSize: 11)),
          const Spacer(),
          Text('${stats.mood.toStringAsFixed(0)} / 100',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const Spacer(),
          const Text('Bullish', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
        const SizedBox(height: 20),
        const Text('Market breadth', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Row(children: [
              if (stats.up > 0) Expanded(flex: flex(stats.up), child: Container(color: _kUp)),
              if (stats.flat > 0) Expanded(flex: flex(stats.flat), child: Container(color: Colors.white24)),
              if (stats.down > 0) Expanded(flex: flex(stats.down), child: Container(color: _kDown)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _Legend(_kUp, '${stats.up} rising'),
          const SizedBox(width: 14),
          _Legend(Colors.white38, '${stats.flat} flat'),
          const SizedBox(width: 14),
          _Legend(_kDown, '${stats.down} falling'),
        ]),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.text);
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]);
}

// ───────────────────────── Dominance donut ─────────────────────────

class _DominanceCard extends StatefulWidget {
  const _DominanceCard({required this.stats});
  final _Stats stats;

  @override
  State<_DominanceCard> createState() => _DominanceCardState();
}

class _DominanceCardState extends State<_DominanceCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    final top = s.byCap.take(5).toList();
    final topSum = top.fold<double>(0, (a, c) => a + c.marketCapUsd);
    final others = (s.marketCap - topSum).clamp(0, double.infinity).toDouble();

    final labels = [...top.map((c) => c.symbol), if (others > 0) 'Others'];
    final values = [...top.map((c) => c.marketCapUsd), if (others > 0) others];
    final total = s.marketCap <= 0 ? 1.0 : s.marketCap;

    final focus = _touched >= 0 && _touched < values.length ? _touched : 0;

    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _PanelTitle('Market cap dominance', subtitle: 'Tap a slice for details'),
        const SizedBox(height: 16),
        SizedBox(
          height: 210,
          child: Stack(alignment: Alignment.center, children: [
            PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 68,
                startDegreeOffset: -90,
                borderData: FlBorderData(show: false),
                pieTouchData: PieTouchData(
                  touchCallback: (event, resp) {
                    final i = resp?.touchedSection?.touchedSectionIndex ?? -1;
                    if (event is FlTapUpEvent || event is FlPanEndEvent) return;
                    if (i != _touched) setState(() => _touched = i);
                  },
                ),
                sections: [
                  for (var i = 0; i < values.length; i++)
                    PieChartSectionData(
                      value: values[i] <= 0 ? .0001 : values[i],
                      color: _palette[i % _palette.length],
                      radius: i == focus && _touched >= 0 ? 36 : 28,
                      showTitle: false,
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 250),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(labels[focus], style: const TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 2),
              Text('${(values[focus] / total * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(formatCompactCurrency(values[focus]),
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 14, runSpacing: 8, children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => setState(() => _touched = i),
              child: _Legend(_palette[i % _palette.length], '${labels[i]}  ${(values[i] / total * 100).toStringAsFixed(1)}%'),
            ),
        ]),
      ]),
    );
  }
}

// ───────────────────────── Movers ─────────────────────────

class _MoversCard extends StatefulWidget {
  const _MoversCard({required this.stats});
  final _Stats stats;

  @override
  State<_MoversCard> createState() => _MoversCardState();
}

class _MoversCardState extends State<_MoversCard> {
  bool _gainers = true;

  @override
  Widget build(BuildContext context) {
    final list = _gainers ? widget.stats.gainers : widget.stats.losers;
    final tone = _gainers ? _kUp : _kDown;
    final maxAbs = list.isEmpty ? 1.0 : list.map((c) => c.change24h.abs()).reduce((a, b) => a > b ? a : b);

    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _PanelTitle('Top movers', subtitle: 'Biggest 24h price changes'),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.trending_up_rounded, size: 18), label: Text('Gainers')),
              ButtonSegment(value: false, icon: Icon(Icons.trending_down_rounded, size: 18), label: Text('Losers')),
            ],
            selected: {_gainers},
            onSelectionChanged: (v) => setState(() => _gainers = v.first),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: list.isEmpty
              ? Padding(
                  key: ValueKey('empty$_gainers'),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(_gainers ? 'No gainers right now.' : 'No losers right now.',
                        style: const TextStyle(color: Colors.white54)),
                  ),
                )
              : Column(
                  key: ValueKey(_gainers),
                  children: [
                    for (final c in list)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(children: [
                          _symbolBadge(c, size: 38),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(
                                  child: Text(c.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                Text('${c.change24h > 0 ? '+' : ''}${c.change24h.toStringAsFixed(2)}%',
                                    style: TextStyle(color: tone, fontWeight: FontWeight.w800)),
                              ]),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: maxAbs == 0 ? 0 : c.change24h.abs() / maxAbs),
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, v, __) => LinearProgressIndicator(
                                    value: v,
                                    minHeight: 5,
                                    backgroundColor: Colors.white.withValues(alpha: .07),
                                    valueColor: AlwaysStoppedAnimation(tone),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                  ],
                ),
        ),
      ]),
    );
  }
}

// ───────────────────────── Largest coins ─────────────────────────

class _TopCoinsCard extends StatelessWidget {
  const _TopCoinsCard({required this.stats});
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final top = stats.byCap.take(5).toList();
    final total = stats.marketCap <= 0 ? 1.0 : stats.marketCap;

    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _PanelTitle('Largest coins by market cap'),
        const SizedBox(height: 12),
        for (var i = 0; i < top.length; i++) ...[
          if (i > 0) Divider(height: 1, color: Colors.white.withValues(alpha: .06)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              SizedBox(
                width: 22,
                child: Text('${i + 1}',
                    style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w800)),
              ),
              _symbolBadge(top[i], size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(top[i].name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${(top[i].marketCapUsd / total * 100).toStringAsFixed(1)}% of tracked cap',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(formatCompactCurrency(top[i].marketCapUsd),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '${top[i].change24h >= 0 ? '+' : ''}${top[i].change24h.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: top[i].change24h >= 0 ? _kUp : _kDown,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ───────────────────────── States ─────────────────────────

class _MockBanner extends StatelessWidget {
  const _MockBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(children: [
          Icon(Icons.science_outlined, size: 16, color: Colors.amber),
          SizedBox(width: 8),
          Expanded(child: Text('Showing demo data', style: TextStyle(color: Colors.amber, fontSize: 12.5))),
        ]),
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
            const Text('Market statistics are unavailable.', textAlign: TextAlign.center),
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