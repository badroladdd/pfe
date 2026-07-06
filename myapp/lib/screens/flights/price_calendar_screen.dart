import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/utils/currency.dart';
import 'package:myapp/widgets/airline_logo.dart';

const _kBlue = Color(0xFF3B82F6);
const double _kLabelW = 84.0;
const double _kHeaderH = 60.0;
const double _kCellH = 86.0;
const int _kCols = 3;
const int _kRows = 4;

class _Cell {
  final double price;
  final String carrierCode;
  _Cell(this.price, this.carrierCode);
}

class PriceCalendarScreen extends StatefulWidget {
  final String origin;
  final String destination;
  final DateTime departureDate;
  final DateTime returnDate;
  final int adults;
  final int children;
  final int infants;
  final String travelClass;
  final Map<String, dynamic> initialCells;
  final void Function(DateTime dep, DateTime ret) onSelect;

  const PriceCalendarScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.departureDate,
    required this.returnDate,
    required this.adults,
    this.children = 0,
    this.infants = 0,
    this.travelClass = 'ECONOMY',
    this.initialCells = const {},
    required this.onSelect,
  });

  @override
  State<PriceCalendarScreen> createState() => _PriceCalendarScreenState();
}

class _PriceCalendarScreenState extends State<PriceCalendarScreen> {
  final _api = ApiClient();

  late DateTime _depStart;
  late DateTime _retStart;
  late DateTime _selDep;
  late DateTime _selRet;

  // "YYYY-MM-DD|YYYY-MM-DD" → _Cell (null = no flight available)
  final Map<String, _Cell?> _cache = {};
  bool _loading = false;

  String? _airlineFilter;

  @override
  void initState() {
    super.initState();
    _selDep = widget.departureDate;
    _selRet = widget.returnDate;
    _depStart = widget.departureDate.subtract(Duration(days: _kCols ~/ 2));
    _retStart = widget.returnDate.subtract(const Duration(days: 1));
    // Pre-populate cache from data already fetched in the results screen
    for (final entry in widget.initialCells.entries) {
      final raw = entry.value;
      if (raw == null) {
        _cache[entry.key] = null;
      } else {
        final price = (raw['price'] as num?)?.toDouble();
        final code  = raw['carrier_code']?.toString() ?? '';
        _cache[entry.key] = price != null && price > 0 ? _Cell(price, code) : null;
      }
    }
    _loadCalendar();
  }

  List<DateTime> get _deps =>
      List.generate(_kCols, (i) => _depStart.add(Duration(days: i)));

  List<DateTime> get _rets =>
      List.generate(_kRows, (i) => _retStart.add(Duration(days: i)));

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _key(DateTime dep, DateTime ret) => '${_fmt(dep)}|${_fmt(ret)}';

  Future<void> _loadCalendar() async {
    final deps = _deps;
    final rets = _rets;

    // Check if all visible cells are already cached
    final allCached = deps.every((dep) => rets.every((ret) {
      if (!dep.isBefore(ret)) { return true; }
      return _cache.containsKey(_key(dep, ret));
    }));
    if (allCached) { return; }

    setState(() => _loading = true);
    try {
      final depEnd = deps.last;
      final retEnd = rets.last;

      final cells = await _api.getFlightCalendar(
        origin:      widget.origin,
        destination: widget.destination,
        depStart:    _fmt(deps.first),
        depEnd:      _fmt(depEnd),
        retStart:    _fmt(rets.first),
        retEnd:      _fmt(retEnd),
        adults:      widget.adults,
        children:    widget.children,
        infants:     widget.infants,
        travelClass: widget.travelClass,
      );

      if (!mounted) { return; }

      final newCache = <String, _Cell?>{};
      for (final dep in deps) {
        for (final ret in rets) {
          if (!dep.isBefore(ret)) { continue; }
          final k = _key(dep, ret);
          final raw = cells[k];
          if (raw == null) {
            newCache[k] = null;
          } else {
            final price = (raw['price'] as num?)?.toDouble();
            final code  = raw['carrier_code']?.toString() ?? '';
            newCache[k] = price != null && price > 0 ? _Cell(price, code) : null;
          }
        }
      }

      setState(() {
        _cache.addAll(newCache);
        _loading = false;
      });
    } catch (_) {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  List<double> get _visiblePrices {
    final out = <double>[];
    for (final dep in _deps) {
      for (final ret in _rets) {
        if (!dep.isBefore(ret)) { continue; }
        final c = _cache[_key(dep, ret)];
        if (c == null) { continue; }
        if (_airlineFilter != null && c.carrierCode != _airlineFilter) { continue; }
        out.add(c.price);
      }
    }
    return out;
  }

  Set<String> get _airlines {
    final s = <String>{};
    for (final c in _cache.values) {
      if (c != null && c.carrierCode.isNotEmpty) { s.add(c.carrierCode); }
    }
    return s;
  }

  void _nav({required bool outbound, required int delta}) {
    setState(() {
      if (outbound) { _depStart = _depStart.add(Duration(days: delta)); }
      else { _retStart = _retStart.add(Duration(days: delta)); }
    });
    _loadCalendar();
  }

  static const _ml = ['jan','fév','mar','avr','mai','jun','jul','aoû','sep','oct','nov','déc'];
  static const _dl = ['lun.','mar.','mer.','jeu.','ven.','sam.','dim.'];

  String _dn(DateTime d) => _dl[d.weekday - 1];
  String _dd(DateTime d) => '${d.day} ${_ml[d.month - 1]}';

  Color _bg(double price, double min, double max, bool sel) {
    if (sel) { return _kBlue; }
    if (max <= min) { return const Color(0xFFC8E6C9); }
    final t = (price - min) / (max - min);
    if (t <= 0.001) { return const Color(0xFFC8E6C9); }
    if (t >= 0.999) { return const Color(0xFFFFCDD2); }
    return Colors.white;
  }

  Color _tc(double price, double min, double max, bool sel) {
    if (sel) { return Colors.white; }
    if (max <= min) { return Colors.green.shade800; }
    final t = (price - min) / (max - min);
    if (t <= 0.001) { return Colors.green.shade800; }
    if (t >= 0.999) { return Colors.red.shade800; }
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    final prices = _visiblePrices;
    final minP = prices.isEmpty ? 0.0 : prices.reduce((a, b) => a < b ? a : b);
    final maxP = prices.isEmpty ? 0.0 : prices.reduce((a, b) => a > b ? a : b);
    final airlines = _airlines;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('${widget.origin} → ${widget.destination}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: _loading
                ? null
                : () {
                    widget.onSelect(_selDep, _selRet);
                    Navigator.pop(context);
                  },
            child: const Text('Confirmer',
                style: TextStyle(color: _kBlue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (airlines.isNotEmpty) _buildFilter(airlines),
          _buildLegend(),
          const Divider(height: 1),
          Expanded(
            child: _loading && _cache.isEmpty
                ? _buildLoadingOverlay()
                : Stack(
                    children: [
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            LayoutBuilder(
                              builder: (ctx, constraints) {
                                final cellW =
                                    (constraints.maxWidth - _kLabelW) / _kCols;
                                return _buildGrid(minP, maxP, cellW);
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              child: Text(
                                'Par rapport aux autres prix affichés',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Subtle refresh indicator during navigation re-fetch
                      if (_loading)
                        Positioned(
                          top: 8, left: 0, right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 12, height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Chargement...',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _kBlue),
          const SizedBox(height: 16),
          Text('Recherche des prix en cours...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 6),
          Text('${_kCols * _kRows} combinaisons de dates',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFilter(Set<String> airlines) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Compagnie',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(null, 'Toutes'),
                ...airlines.map((code) => _chip(code, code)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String? code, String label) {
    final sel = _airlineFilter == code;
    return GestureDetector(
      onTap: () => setState(() => _airlineFilter = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _kBlue.withValues(alpha: 0.1) : Colors.grey.shade100,
          border: Border.all(
              color: sel ? _kBlue : Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (code != null) ...[
              AirlineLogo(code: code, size: 18),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: sel ? _kBlue : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _ldot(const Color(0xFFC8E6C9), 'Le moins cher'),
          const SizedBox(width: 12),
          _ldot(const Color(0xFFFFCDD2), 'Le plus cher'),
          const SizedBox(width: 12),
          _ldot(_kBlue, 'Votre sélection'),
        ],
      ),
    );
  }

  Widget _ldot(Color bg, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9, height: 9,
        decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 0.5)),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ],
  );

  Widget _buildGrid(double minP, double maxP, double cellW) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
        columnWidths: {
          0: const FixedColumnWidth(_kLabelW),
          for (int i = 1; i <= _kCols; i++) i: FixedColumnWidth(cellW),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade100),
            children: [
              SizedBox(height: _kHeaderH, child: _cornerWidget()),
              ..._deps.map((dep) =>
                  SizedBox(height: _kHeaderH, child: _depHeader(dep))),
            ],
          ),
          ..._rets.asMap().entries.map((e) => TableRow(
            children: [
              SizedBox(height: _kCellH, child: _retLabel(e.key, e.value)),
              ..._deps.map((dep) =>
                  SizedBox(height: _kCellH, child: _cell(dep, e.value, minP, maxP))),
            ],
          )),
        ],
      ),
    );
  }

  Widget _cornerWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Aller',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _navBtn(Icons.chevron_left,  () => _nav(outbound: true, delta: -_kCols)),
            _navBtn(Icons.chevron_right, () => _nav(outbound: true, delta: _kCols)),
          ],
        ),
      ],
    );
  }

  Widget _depHeader(DateTime d) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_dn(d), style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(_dd(d), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _retLabel(int rowIdx, DateTime ret) {
    final isFirst = rowIdx == 0;
    final isLast  = rowIdx == _kRows - 1;
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFirst)
                Text('Retour',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
              Text(_dn(ret), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(_dd(ret), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (isFirst)
          Positioned(top: 4, right: 4,
              child: _navBtn(Icons.expand_less,
                  () => _nav(outbound: false, delta: -_kRows))),
        if (isLast)
          Positioned(bottom: 4, right: 4,
              child: _navBtn(Icons.expand_more,
                  () => _nav(outbound: false, delta: _kRows))),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(icon, size: 16, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _cell(DateTime dep, DateTime ret, double minP, double maxP) {
    final k      = _key(dep, ret);
    final isSel  = _fmt(dep) == _fmt(_selDep) && _fmt(ret) == _fmt(_selRet);
    final valid  = dep.isBefore(ret);

    if (!valid) {
      return Container(
        color: Colors.grey.shade50,
        child: Center(child: Text('—',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 14))),
      );
    }

    final data     = _cache[k];
    final fetched  = _cache.containsKey(k);
    final filtered = _airlineFilter != null && data != null &&
        data.carrierCode != _airlineFilter;

    Color bg = Colors.white;
    if (!filtered && data != null) { bg = _bg(data.price, minP, maxP, isSel); }
    if (isSel && data == null)     { bg = _kBlue.withValues(alpha: 0.12); }

    return GestureDetector(
      onTap: (data != null && !filtered)
          ? () => setState(() { _selDep = dep; _selRet = ret; })
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: bg,
        child: !fetched
            ? const Center(child: SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5)))
            : filtered
                ? Center(child: Text('—',
                    style: TextStyle(color: Colors.grey.shade300)))
                : data == null
                    ? Center(child: Text('—',
                        style: TextStyle(color: Colors.grey.shade400)))
                    : _cellContent(data, minP, maxP, isSel),
      ),
    );
  }

  Widget _cellContent(_Cell data, double minP, double maxP, bool sel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (data.carrierCode.isNotEmpty) ...[
            AirlineLogo(code: data.carrierCode, size: 36),
            const SizedBox(height: 4),
          ],
          Text(
            formatDzd(data.price),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _tc(data.price, minP, maxP, sel)),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
