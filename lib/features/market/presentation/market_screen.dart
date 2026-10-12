import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/formatters.dart';
import '../domain/coin.dart';
import 'market_providers.dart';
import 'coin_details_screen.dart';

const _kUp = Color(0xFF45D6A0);
const _kDown = Color(0xFFFF7181);
const _kAccent = Color(0xFFAA98FF);
const _kGold = Color(0xFFFFC857);
const _kCard = Color(0xFF1A1A22);

enum _Category { all, gainers, losers, watchlist }

String _sortLabel(CoinSort s) => switch (s) {
      CoinSort.rank => 'Rank',
      CoinSort.price => 'Price: high to low',
      CoinSort.marketCap => 'Market cap: high to low',
      CoinSort.volume => 'Volume: high to low',
      CoinSort.gainers => '24h change: high to low',
      CoinSort.losers => '24h change: low to high',
    };

IconData _sortIcon(CoinSort s) => switch (s) {
      CoinSort.rank => Icons.format_list_numbered_rounded,
      CoinSort.price => Icons.sell_outlined,
      CoinSort.marketCap => Icons.pie_chart_outline_rounded,
      CoinSort.volume => Icons.bar_chart_rounded,
      CoinSort.gainers => Icons.trending_up_rounded,
      CoinSort.losers => Icons.trending_down_rounded,
    };

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});
  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  late final TextEditingController _search;
  final _scroll = ScrollController();
  _Category _category = _Category.all;
  bool _grid = false;
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(searchQueryProvider));
    _scroll.addListener(() {
      final show = _scroll.hasClients && _scroll.offset > 700;
      if (show != _showTop) setState(() => _showTop = show);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(coinsProvider);
    try {
      await ref.read(coinsProvider.future);
    } catch (_) {}
  }

  void _setQuery(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
    setState(() {});
  }

  void _open(Coin coin) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => CoinDetailsScreen(coin: coin)));

  void _toggleSave(Coin coin) {
    HapticFeedback.selectionClick();
    ref.read(watchlistProvider.notifier).toggle(coin.id);
  }

  void _openSortSheet(CoinSort current) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Sort by', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
          for (final s in CoinSort.values)
            ListTile(
              leading: Icon(_sortIcon(s), color: s == current ? _kAccent : Colors.white54),
              title: Text(_sortLabel(s),
                  style: TextStyle(fontWeight: s == current ? FontWeight.w800 : FontWeight.w500)),
              trailing: s == current ? const Icon(Icons.check_circle_rounded, color: _kAccent) : null,
              onTap: () {
                ref.read(coinSortProvider.notifier).state = s;
                Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allCoins = ref.watch(coinsProvider);
    final visible = ref.watch(visibleCoinsProvider);
    final watchlist = ref.watch(watchlistProvider);
    final sort = ref.watch(coinSortProvider);
    final query = ref.watch(searchQueryProvider);

    final filtered = visible.whenData((list) => switch (_category) {
          _Category.all => list,
          _Category.gainers => list.where((c) => c.change24h > 0).toList(),
          _Category.losers => list.where((c) => c.change24h < 0).toList(),
          _Category.watchlist => list.where((c) => watchlist.contains(c.id)).toList(),
        });

    final trending = <Coin>[];
    if (_category == _Category.all && query.trim().isEmpty) {
      final coins = allCoins.valueOrNull;
      if (coins != null && coins.length >= 3) {
        final sorted = [...coins]..sort((a, b) => b.change24h.abs().compareTo(a.change24h.abs()));
        trending.addAll(sorted.take(6));
      }
    }

    return Scaffold(
      floatingActionButton: AnimatedScale(
        scale: _showTop ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: FloatingActionButton.small(
          tooltip: 'Back to top',
          onPressed: () => _scroll.animateTo(0, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic),
          child: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverAppBar(
                pinned: true,
                titleSpacing: 16,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                title: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_kAccent, _kAccent.withValues(alpha: .5)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.currency_bitcoin, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('CryptoScope', style: TextStyle(fontWeight: FontWeight.w800)),
                ]),
                actions: [
                  IconButton(
                    tooltip: _grid ? 'List view' : 'Grid view',
                    onPressed: () => setState(() => _grid = !_grid),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(_grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded, key: ValueKey(_grid)),
                    ),
                  ),
                  IconButton(tooltip: 'Refresh data', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
                  const _DemoPill(),
                  const SizedBox(width: 12),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Crypto market',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                    const SizedBox(height: 4),
                    Text('Prices, performance and market research',
                        style: TextStyle(color: Colors.white.withValues(alpha: .6))),
                    const SizedBox(height: 16),
                    allCoins.maybeWhen(
                      data: (coins) => coins.isEmpty ? const SizedBox.shrink() : _Overview(coins: coins),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ]),
                ),
              ),
              if (trending.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Row(children: [
                        Icon(Icons.local_fire_department_rounded, color: _kGold, size: 20),
                        SizedBox(width: 6),
                        Text('Trending now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    SizedBox(
                      height: 146,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: trending.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _TrendingCard(coin: trending[i], onTap: () => _open(trending[i])),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ]),
                ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedHeader(
                  extent: 124,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: _Controls(
                    search: _search,
                    onQuery: _setQuery,
                    category: _category,
                    onCategory: (c) => setState(() => _category = c),
                    watchlistCount: watchlist.length,
                    sort: sort,
                    onSort: () => _openSortSheet(sort),
                  ),
                ),
              ),
              ...filtered.when<List<Widget>>(
                loading: () => [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => i.isOdd ? const SizedBox(height: 8) : const _SkeletonTile(),
                        childCount: 13,
                      ),
                    ),
                  ),
                ],
                error: (error, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorPanel(
                      message: _errorText(error),
                      onRetry: _refresh,
                    ),
                  ),
                ],
                data: (coins) {
                  if (coins.isEmpty) {
                    return [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(watchlist: _category == _Category.watchlist && watchlist.isEmpty),
                      ),
                    ];
                  }
                  final shown = coins.take(100).toList();
                  final header = SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
                      child: Text(
                        '${shown.length} ${shown.length == 1 ? 'coin' : 'coins'}'
                        '${_grid ? '' : '  •  swipe right to save'}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  );
                  if (_grid) {
                    return [
                      header,
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            mainAxisExtent: 158,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) {
                              final coin = shown[i];
                              return _FadeIn(
                                index: i,
                                child: _GridCard(
                                  coin: coin,
                                  saved: watchlist.contains(coin.id),
                                  onSave: () => _toggleSave(coin),
                                  onTap: () => _open(coin),
                                ),
                              );
                            },
                            childCount: shown.length,
                          ),
                        ),
                      ),
                    ];
                  }
                  return [
                    header,
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            if (i.isOdd) return const SizedBox(height: 8);
                            final coin = shown[i ~/ 2];
                            final saved = watchlist.contains(coin.id);
                            return _FadeIn(
                              index: i ~/ 2,
                              child: Dismissible(
                                key: ValueKey('tile_${coin.id}'),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (_) async {
                                  _toggleSave(coin);
                                  return false;
                                },
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 22),
                                  decoration: BoxDecoration(
                                    color: _kGold.withValues(alpha: .18),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(saved ? Icons.star_border_rounded : Icons.star_rounded, color: _kGold),
                                    const SizedBox(width: 8),
                                    Text(saved ? 'Remove' : 'Save',
                                        style: const TextStyle(color: _kGold, fontWeight: FontWeight.w700)),
                                  ]),
                                ),
                                child: _CoinTile(
                                  coin: coin,
                                  saved: saved,
                                  onSave: () => _toggleSave(coin),
                                  onTap: () => _open(coin),
                                ),
                              ),
                            );
                          },
                          childCount: shown.length * 2 - 1,
                        ),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _errorText(Object error) {
    return 'Could not load demo data. Please retry.';
  }
}

// ───────────────────────── Pinned controls ─────────────────────────

class _PinnedHeader extends SliverPersistentHeaderDelegate {
  _PinnedHeader({required this.extent, required this.color, required this.child});
  final double extent;
  final Color color;
  final Widget child;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
        color: color,
        child: child,
      );

  @override
  bool shouldRebuild(covariant _PinnedHeader old) => true;
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.search,
    required this.onQuery,
    required this.category,
    required this.onCategory,
    required this.watchlistCount,
    required this.sort,
    required this.onSort,
  });

  final TextEditingController search;
  final ValueChanged<String> onQuery;
  final _Category category;
  final ValueChanged<_Category> onCategory;
  final int watchlistCount;
  final CoinSort sort;
  final VoidCallback onSort;

  Widget _chip(String label, _Category value, {IconData? icon}) {
    final selected = category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 17, color: selected ? null : Colors.white54),
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          onCategory(value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: SizedBox(
          height: 52,
          child: TextField(
            controller: search,
            onChanged: onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search name or symbol',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        search.clear();
                        onQuery('');
                      },
                    ),
            ),
          ),
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _chip('All', _Category.all),
            _chip('Gainers', _Category.gainers, icon: Icons.trending_up_rounded),
            _chip('Losers', _Category.losers, icon: Icons.trending_down_rounded),
            _chip('Watchlist${watchlistCount == 0 ? '' : ' ($watchlistCount)'}', _Category.watchlist,
                icon: Icons.star_rounded),
            ActionChip(
              avatar: Icon(_sortIcon(sort), size: 17),
              label: Text(sort == CoinSort.rank ? 'Sort: Rank' : _sortLabel(sort).split(':').first),
              onPressed: onSort,
            ),
          ],
        ),
      ),
    ]);
  }
}

// ───────────────────────── Overview ─────────────────────────

class _Overview extends StatelessWidget {
  const _Overview({required this.coins});
  final List<Coin> coins;

  @override
  Widget build(BuildContext context) {
    final up = coins.where((c) => c.change24h > 0).length;
    final down = coins.where((c) => c.change24h < 0).length;
    final total = (up + down) == 0 ? 1 : (up + down);
    final cap = coins.fold<double>(0, (s, c) => s + c.marketCapUsd);
    final vol = coins.fold<double>(0, (s, c) => s + c.volume24hUsd);
    final avg = coins.fold<double>(0, (s, c) => s + c.change24h) / coins.length;
    final tone = avg >= 0 ? _kUp : _kDown;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAccent.withValues(alpha: .28), tone.withValues(alpha: .08), _kCard],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Total market cap', style: TextStyle(color: Colors.white.withValues(alpha: .65), fontSize: 13)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: tone.withValues(alpha: .16), borderRadius: BorderRadius.circular(9)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(avg >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 15, color: tone),
              const SizedBox(width: 4),
              Text('${avg >= 0 ? '+' : ''}${avg.toStringAsFixed(2)}%',
                  style: TextStyle(color: tone, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(formatCompactCurrency(cap),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1)),
        ),
        const SizedBox(height: 4),
        Text('24h volume ${formatCompactCurrency(vol)}',
            style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 6,
            child: Row(children: [
              Expanded(flex: (up * 1000 ~/ total).clamp(1, 1000), child: Container(color: _kUp)),
              const SizedBox(width: 2),
              Expanded(flex: (down * 1000 ~/ total).clamp(1, 1000), child: Container(color: _kDown)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('$up rising', style: const TextStyle(color: _kUp, fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('$down falling', style: const TextStyle(color: _kDown, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

// ───────────────────────── Shared pieces ─────────────────────────

Widget _badge(Coin coin, {double size = 46}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAccent.withValues(alpha: .35), const Color(0xFF2A2540)],
        ),
      ),
      child: Text(
        coin.symbol.length > 4 ? coin.symbol.substring(0, 4) : coin.symbol,
        style: TextStyle(fontSize: size * .24, fontWeight: FontWeight.w800),
      ),
    );

class _ChangePill extends StatelessWidget {
  const _ChangePill(this.change);
  final double change;

  @override
  Widget build(BuildContext context) {
    final up = change >= 0;
    final tone = up ? _kUp : _kDown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: tone.withValues(alpha: .14), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 16, color: tone),
        Text('${change.abs().toStringAsFixed(2)}%',
            style: TextStyle(color: tone, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _StarButton extends StatelessWidget {
  const _StarButton({required this.saved, required this.onTap});
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: saved ? 'Remove from watchlist' : 'Add to watchlist',
        onPressed: onTap,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Icon(
            saved ? Icons.star_rounded : Icons.star_border_rounded,
            key: ValueKey(saved),
            color: saved ? _kGold : Colors.white38,
          ),
        ),
      );
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (index > 9) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + index * 45),
      curve: Curves.easeOutCubic,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: c),
      ),
      child: child,
    );
  }
}

// ───────────────────────── Trending ─────────────────────────

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.coin, required this.onTap});
  final Coin coin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final up = coin.change24h >= 0;
    final tone = up ? _kUp : _kDown;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 156,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tone.withValues(alpha: .20), _kCard],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _badge(coin, size: 34),
              const Spacer(),
              Icon(up ? Icons.north_east_rounded : Icons.south_east_rounded, size: 18, color: tone),
            ]),
            const Spacer(),
            Text(coin.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatPrice(coin.priceUsd),
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            const SizedBox(height: 6),
            Text('${up ? '+' : '-'}${coin.change24h.abs().toStringAsFixed(2)}%',
                style: TextStyle(color: tone, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Tiles ─────────────────────────

class _CoinTile extends StatelessWidget {
  const _CoinTile({required this.coin, required this.saved, required this.onSave, required this.onTap});
  final Coin coin;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
        onLongPress: onSave,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(children: [
            _badge(coin),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(coin.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 5),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(coin.rank > 0 ? '#${coin.rank}' : 'N/A',
                        style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('${coin.symbol} • Vol ${formatCompactCurrency(coin.volume24hUsd)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 12)),
                  ),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatPrice(coin.priceUsd), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 5),
              _ChangePill(coin.change24h),
            ]),
            _StarButton(saved: saved, onTap: onSave),
          ]),
        ),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({required this.coin, required this.saved, required this.onSave, required this.onTap});
  final Coin coin;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: .06)),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onSave,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _badge(coin, size: 38),
              const Spacer(),
              _StarButton(saved: saved, onTap: onSave),
            ]),
            const Spacer(),
            Text(coin.name,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${coin.symbol} • ${coin.rank > 0 ? '#${coin.rank}' : 'N/A'}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatPrice(coin.priceUsd),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 6),
              Padding(padding: const EdgeInsets.only(right: 10), child: _ChangePill(coin.change24h)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Loading skeleton ─────────────────────────

class _SkeletonTile extends StatefulWidget {
  const _SkeletonTile();

  @override
  State<_SkeletonTile> createState() => _SkeletonTileState();
}

class _SkeletonTileState extends State<_SkeletonTile> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(6),
        ),
      );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Opacity(opacity: .45 + _c.value * .55, child: child),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: .05)),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                _bar(120, 12),
                const SizedBox(height: 8),
                _bar(80, 10),
              ]),
            ),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              _bar(70, 12),
              const SizedBox(height: 8),
              _bar(48, 10),
            ]),
            const SizedBox(width: 12),
          ]),
        ),
      );
}

// ───────────────────────── States ─────────────────────────

class _DemoPill extends StatelessWidget {
  const _DemoPill();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.science_outlined, size: 14, color: Colors.amber),
          SizedBox(width: 5),
          Text('DEMO', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.watchlist});
  final bool watchlist;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(watchlist ? Icons.star_border_rounded : Icons.search_off_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            watchlist ? 'No saved coins yet.\nTap the star on any coin to add it.' : 'No matching coins found.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: .65), height: 1.4),
          ),
        ]),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white38),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ]),
      );
}